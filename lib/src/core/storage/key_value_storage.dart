/// 键值存储抽象。
///
/// 适合保存 token、用户偏好、设备配置等简单数据。
/// 具体实现可以是 SharedPreferences、安全存储、文件或数据库。
abstract interface class KeyValueStorage {
  /// 根据 [key] 读取字符串。
  ///
  /// 如果对应数据不存在，返回 null。
  Future<String?> readString(String key);

  /// 写入字符串值。
  Future<void> writeString(String key, String value);

  /// 删除指定 [key] 对应的数据。
  Future<void> remove(String key);

  /// 读取当前存储中所有键。
  Future<Set<String>> keys();

  /// 一次性读取当前存储中所有对象。
  Future<Map<String, Object?>> readAll();
}
