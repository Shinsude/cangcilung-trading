class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool get ready => false;

  Future<void> init() async {}
}