import 'dart:io';

/// 在 Windows 上以同目录备份原子替换目标文件。
///
/// 路径通过环境变量传给 PowerShell，避免 `-Command` 后续参数在 5.1 中被当作
/// 命令文本解析。调用方负责在确认提交成功后删除 [backup]。
Future<ProcessResult> replaceWindowsFile({
  required String source,
  required String destination,
  required String backup,
}) {
  return Process.run(
    'powershell.exe',
    <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'[System.IO.File]::Replace($env:SC_SOURCE, $env:SC_DESTINATION, $env:SC_BACKUP, $true)',
    ],
    runInShell: false,
    environment: <String, String>{
      ...Platform.environment,
      'SC_SOURCE': source,
      'SC_DESTINATION': destination,
      'SC_BACKUP': backup,
    },
  );
}
