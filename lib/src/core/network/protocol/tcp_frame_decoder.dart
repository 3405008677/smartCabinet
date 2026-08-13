/// 把 TCP 字节流增量拆分为协议消息的解码器。
///
/// TCP 不保留应用层消息边界，实现必须自行缓存半帧、拆分粘包，并在 [reset]
/// 后丢弃上一条连接残留的字节。每条物理连接都会取得一个新的解码器实例。
abstract interface class TcpFrameDecoder<TMessage> {
  /// 追加一段网络字节，并返回本次已经完整解出的全部消息。
  ///
  /// 如果字节违反协议，实现可以抛出异常。客户端会把解码错误视为当前连接已
  /// 不再可信，关闭连接并取消其全部待处理请求。
  List<TMessage> add(List<int> bytes);

  /// 清除尚未组成完整消息的残留数据。
  void reset();
}

/// 为每条新 TCP 连接创建独立帧解码器的工厂。
typedef TcpFrameDecoderFactory<TMessage> = TcpFrameDecoder<TMessage> Function();
