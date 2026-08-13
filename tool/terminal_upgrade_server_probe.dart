import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/core/network/protocol/tcp_protocol.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/protocol/zrd_stum_protocol.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

/// 对真实 ZRD STUM 服务执行一次无安装副作用的 TCP 通信探测。
///
/// 探测依次发送 T01 登录与 T03 URL 升级查询。如果服务端返回 S03，程序会复用
/// 生产校验器并按结果发送 T00 收讫应答，但不会下载或安装 AD 指向的升级包。
Future<void> main(List<String> arguments) async {
  late final _ProbeOptions options;
  try {
    options = _ProbeOptions.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln('参数错误：${error.message}');
    stderr.writeln(_ProbeOptions.usage);
    exitCode = 64;
    return;
  }

  final settings = TerminalUpgradeSettings(
    enabled: true,
    host: options.host,
    port: options.port,
    terminalId: options.terminalId,
    packageTag: options.packageTag,
  );
  final identity = TerminalUpgradeLoginIdentity(
    moduleId: options.moduleId,
    dataProtocolIp: options.dataProtocolIp,
    chipId: options.chipId,
  );
  final validationError = settings.validate() ?? identity.validate();
  if (validationError != null) {
    stderr.writeln('升级身份或服务器配置无效：${validationError.name}');
    exitCode = 64;
    return;
  }

  final stopwatch = Stopwatch()..start();

  void log(String message) {
    stdout.writeln(
      '${DateTime.now().toIso8601String()} '
      '[${stopwatch.elapsedMilliseconds}ms] $message',
    );
  }

  final client = TcpProtocolClient<_ProbeFrame>(
    frameDecoderFactory: () => _ProbeFrameDecoder(
      // 原始十六进制同样可能还原 URL 查询令牌，只记录长度用于判断半包/粘包。
      onBytes: (bytes) => log('RX_BYTES count=${bytes.length}'),
    ),
    connectTimeout: options.timeout,
    defaultRequestTimeout: options.timeout,
  );
  final unmatchedFrames = StreamController<_ProbeFrame>();
  final unmatchedSubscription = client.unmatchedMessages.listen(
    unmatchedFrames.add,
    onError: unmatchedFrames.addError,
  );
  try {
    log('CONNECT ${settings.host}:${settings.port}');
    await client.connect(settings.host, settings.port);
    log('CONNECTED');

    const loginSerialNumber = 1;
    final loginFrame = ZrdStumProtocolCodec.encodeLogin(
      settings,
      identity: identity,
      serialNumber: loginSerialNumber,
    );
    log(
      'TX T01 SN=$loginSerialNumber fields=ID,IM,DP,CD '
      '(identity redacted)',
    );
    final loginReply = await client.request(
      ascii.encode(loginFrame),
      matcher: (frame) {
        final message = frame.message;
        return message.direction == ZrdStumDirection.server &&
            message.commandCode == '00' &&
            (message.segments['00'] == 'NG0' ||
                (message.serialNumber == loginSerialNumber &&
                    message.segments.containsKey('01')));
      },
    );
    log(_describeInboundFrame(loginReply.message));

    final loginResult = loginReply.message.segments['01'];
    if (loginReply.message.segments['00'] == 'NG0' || loginResult != 'OK') {
      log('RESULT LOGIN_REJECTED result=${loginResult ?? 'NG0'}');
      exitCode = 2;
      return;
    }
    log('RESULT LOGIN_OK');

    const checkSerialNumber = 2;
    final checkFrame = ZrdStumProtocolCodec.encodeUpgradeRequest(
      currentVersion: options.currentVersion,
      versionDate: options.versionDate,
      packageTag: options.packageTag,
      serialNumber: checkSerialNumber,
    );
    final requestVersion = ZrdStumProtocolCodec.formatUpgradeRequestVersion(
      currentVersion: options.currentVersion,
      versionDate: options.versionDate,
    );
    log(
      'TX T03 SN=$checkSerialNumber DT=1 VE=$requestVersion '
      'PT=${options.packageTag.isEmpty ? 'absent' : 'present'}',
    );
    final checkReply = await client.request(
      ascii.encode(checkFrame),
      matcher: (frame) {
        final message = frame.message;
        if (message.direction != ZrdStumDirection.server) {
          return false;
        }
        if (message.commandCode == '03') {
          return true;
        }
        return message.commandCode == '00' &&
            (message.segments['00'] == 'NG0' ||
                (message.serialNumber == checkSerialNumber &&
                    message.segments.containsKey('03')));
      },
    );
    log(_describeInboundFrame(checkReply.message));

    if (checkReply.message.commandCode == '03') {
      final accepted = await _validateAndAcknowledgeOffer(
        client,
        checkReply.message,
        options,
        log,
      );
      if (accepted) {
        _logOfferResult(checkReply.message, log);
      }
      return;
    }

    final checkResult = checkReply.message.segments['03'];
    if (checkReply.message.segments['00'] == 'NG0' || checkResult != 'OK') {
      log('RESULT CHECK_REJECTED result=${checkResult ?? 'NG0'}');
      exitCode = 3;
      return;
    }
    log('RESULT CHECK_ACCEPTED');

    try {
      final offer = await unmatchedFrames.stream
          .firstWhere((frame) => frame.message.commandCode == '03')
          .timeout(options.offerWait);
      log(_describeInboundFrame(offer.message));
      final accepted = await _validateAndAcknowledgeOffer(
        client,
        offer.message,
        options,
        log,
      );
      if (accepted) {
        _logOfferResult(offer.message, log);
      }
    } on TimeoutException {
      log(
        'RESULT NO_S03_WITHIN_${options.offerWait.inSeconds}_SECONDS '
        '(T03 was accepted)',
      );
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln(
      '${DateTime.now().toIso8601String()} '
      '[${stopwatch.elapsedMilliseconds}ms] ERROR $error',
    );
    if (options.verbose) {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  } finally {
    await unmatchedSubscription.cancel();
    await client.dispose();
    await unmatchedFrames.close();
    stopwatch.stop();
  }
}

/// 使用与生产 Repository 相同的 S03 纯校验器，并按结果发送 T00 回执。
Future<bool> _validateAndAcknowledgeOffer(
  TcpProtocolClient<_ProbeFrame> client,
  ZrdStumMessage message,
  _ProbeOptions options,
  void Function(String message) log,
) async {
  final serialNumber = message.serialNumber;
  if (serialNumber == null) {
    throw const ZrdStumProtocolException(
      errorCode: '2',
      attributeKey: 'SN',
      message: 'S03 缺少 SN，无法发送收讫应答',
    );
  }
  var response = 'OK';
  try {
    ZrdStumProtocolCodec.parseUpgradeOffer(
      message,
      currentVersion: options.currentVersion,
      expectedPackageTag: options.packageTag,
    );
  } on ZrdStumProtocolException catch (error) {
    response = error.responseValue;
  }
  final reply = ZrdStumProtocolCodec.encodeTerminalReply(
    serverCommandCode: '03',
    result: response,
    serialNumber: serialNumber,
  );
  log('TX T00 reply=03:$response SN=$serialNumber');
  await client.send(ascii.encode(reply));
  if (response != 'OK') {
    log('RESULT OFFER_REJECTED response=$response');
    exitCode = 4;
    return false;
  }
  return true;
}

/// 输出不包含下载地址、摘要和身份字段值的升级检查结论。
void _logOfferResult(
  ZrdStumMessage message,
  void Function(String message) log,
) {
  final version = message.segments['VE'];
  if (version == '0') {
    log('RESULT UP_TO_DATE');
    return;
  }
  log(
    'RESULT UPGRADE_OFFER version=${version ?? 'missing'} '
    'hasUrl=${message.segments['AD']?.isNotEmpty == true} '
    'hasMd5=${message.segments['MD']?.isNotEmpty == true}',
  );
}

/// 只描述命令、SN 和字段存在性，避免把 AD 查询令牌或设备身份写入控制台。
String _describeInboundFrame(ZrdStumMessage message) {
  final keyword = 'S${message.commandCode}';
  final serial = message.serialNumber?.toString() ?? 'absent';
  if (message.commandCode == '00') {
    final reply = message.segments.entries.firstWhere(
      (entry) => entry.key != 'SN',
      orElse: () => const MapEntry<String, String>('??', 'missing'),
    );
    return 'RX $keyword reply=${reply.key}:${reply.value} SN=$serial';
  }
  if (message.commandCode == '03') {
    return 'RX S03 SN=$serial VE=${message.segments['VE'] ?? 'missing'} '
        'AD=${message.segments['AD']?.isNotEmpty == true ? 'present' : 'empty'} '
        'MD=${message.segments['MD']?.isNotEmpty == true ? 'present' : 'missing'} '
        'PT=${message.segments['PT']?.isNotEmpty == true ? 'present' : 'absent'}';
  }
  final keys = message.segments.keys.where((key) => key != 'SN').join(',');
  return 'RX $keyword SN=$serial fields=$keys';
}

/// 探测工具内部保留已解析消息，不保存或二次输出原始敏感帧。
final class _ProbeFrame {
  const _ProbeFrame(this.message);

  final ZrdStumMessage message;
}

/// 把 TCP 数据块转成 STUM 消息，并只把字节数交给诊断回调。
final class _ProbeFrameDecoder implements TcpFrameDecoder<_ProbeFrame> {
  _ProbeFrameDecoder({required this.onBytes});

  final void Function(List<int> bytes) onBytes;
  final ZrdStumFrameDecoder _decoder = ZrdStumFrameDecoder();

  @override
  List<_ProbeFrame> add(List<int> bytes) {
    onBytes(bytes);
    return <_ProbeFrame>[
      for (final frame in _decoder.add(bytes))
        _ProbeFrame(ZrdStumProtocolCodec.decode(frame)),
    ];
  }

  @override
  void reset() => _decoder.reset();
}

/// 真实服务端无副作用探测所需的命令行参数。
final class _ProbeOptions {
  const _ProbeOptions({
    required this.host,
    required this.port,
    required this.terminalId,
    required this.moduleId,
    required this.dataProtocolIp,
    required this.chipId,
    required this.currentVersion,
    required this.versionDate,
    required this.packageTag,
    required this.timeout,
    required this.offerWait,
    required this.verbose,
  });

  factory _ProbeOptions.parse(List<String> arguments) {
    final values = <String, String>{};
    var verbose = false;
    for (final argument in arguments) {
      if (argument == '--verbose') {
        verbose = true;
        continue;
      }
      final separator = argument.indexOf('=');
      if (!argument.startsWith('--') || separator <= 2) {
        throw FormatException('无法识别参数 $argument');
      }
      values[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }

    final terminalId = values['terminal-id']?.trim() ?? '';
    final moduleId = values['module-id']?.trim() ?? '';
    final dataProtocolIp = values['data-protocol-ip']?.trim() ?? '';
    final chipId = values['chip-id']?.trim() ?? '';
    if (terminalId.isEmpty ||
        moduleId.isEmpty ||
        dataProtocolIp.isEmpty ||
        chipId.isEmpty) {
      throw const FormatException(
        '必须提供 --terminal-id、--module-id、--data-protocol-ip 和 --chip-id',
      );
    }
    final port =
        int.tryParse(values['port'] ?? '') ?? AppConfig.terminalUpgradePort;
    final timeoutSeconds = int.tryParse(values['timeout-seconds'] ?? '') ?? 10;
    final offerWaitSeconds =
        int.tryParse(values['offer-wait-seconds'] ?? '') ?? 8;
    if (timeoutSeconds <= 0 || offerWaitSeconds <= 0) {
      throw const FormatException('超时时间必须大于 0 秒');
    }

    return _ProbeOptions(
      host: values['host']?.trim().isNotEmpty == true
          ? values['host']!.trim()
          : AppConfig.terminalUpgradeHost,
      port: port,
      terminalId: terminalId,
      moduleId: moduleId,
      dataProtocolIp: dataProtocolIp,
      chipId: chipId,
      currentVersion: values['version']?.trim().isNotEmpty == true
          ? values['version']!.trim()
          : '1.0.0',
      versionDate: values['version-date']?.trim().isNotEmpty == true
          ? values['version-date']!.trim()
          : '20260812',
      packageTag: values['package-tag']?.trim() ?? '',
      timeout: Duration(seconds: timeoutSeconds),
      offerWait: Duration(seconds: offerWaitSeconds),
      verbose: verbose,
    );
  }

  static const usage =
      '用法：dart run tool/terminal_upgrade_server_probe.dart '
      '--terminal-id=<11或15位数字> --module-id=<11或15位数字> '
      '--data-protocol-ip=<DP> --chip-id=<关于设备唯一ID> '
      '[--host=${AppConfig.terminalUpgradeHost}] '
      '[--port=${AppConfig.terminalUpgradePort}] [--version=1.0.0] '
      '[--version-date=20260812] '
      '[--package-tag=APP] [--timeout-seconds=10] '
      '[--offer-wait-seconds=8] [--verbose]';

  final String host;
  final int port;
  final String terminalId;
  final String moduleId;
  final String dataProtocolIp;
  final String chipId;
  final String currentVersion;
  final String versionDate;
  final String packageTag;
  final Duration timeout;
  final Duration offerWait;
  final bool verbose;
}
