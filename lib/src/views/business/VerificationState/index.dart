/// 三项或四项身份验证的页面状态。
class VerificationState {
  /// 创建验证状态。
  const VerificationState({
    this.face = false,
    this.fingerprint = false,
    this.nfc = false,
    this.code = false,
  });

  /// 人脸是否已通过。
  final bool face;

  /// 指纹是否已通过。
  final bool fingerprint;

  /// NFC 是否已通过。
  final bool nfc;

  /// 取件码等额外验证是否已通过。
  final bool code;

  /// 已完成的三项身份认证数量。
  int get identityVerifiedCount {
    return [face, fingerprint, nfc].where((verified) => verified).length;
  }

  /// 已完成的四项取件认证数量。
  int get pickupVerifiedCount {
    return [face, fingerprint, nfc, code].where((verified) => verified).length;
  }

  /// 三项身份认证是否全部完成。
  bool get allIdentityVerified => identityVerifiedCount == 3;

  /// 四项取件认证是否全部完成。
  bool get allPickupVerified => pickupVerifiedCount == 4;

  /// 返回更新后的验证状态。
  VerificationState copyWith({
    bool? face,
    bool? fingerprint,
    bool? nfc,
    bool? code,
  }) {
    return VerificationState(
      face: face ?? this.face,
      fingerprint: fingerprint ?? this.fingerprint,
      nfc: nfc ?? this.nfc,
      code: code ?? this.code,
    );
  }
}
