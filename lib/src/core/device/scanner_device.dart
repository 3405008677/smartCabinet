/// 扫码设备能力抽象。
///
/// 后续可以用它接入二维码扫描器、条码枪等外部设备。
abstract interface class ScannerDevice {
  /// 扫码结果流。
  ///
  /// 每当设备扫描到一个码，就向这个 Stream 推送一条字符串结果。
  Stream<String> get scanResults;
}
