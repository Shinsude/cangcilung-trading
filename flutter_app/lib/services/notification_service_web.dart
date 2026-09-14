class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<bool> enabledOnDevice() async => false;

  Future<void> showStrongSignal(String symbol, String action, String strength) async {}

  Future<void> showPriceAlert(String symbol, double target, double price) async {}

  Future<void> showMorningDigest(String date, String text) async {}
}