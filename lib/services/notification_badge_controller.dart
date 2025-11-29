import 'dart:async';

/// Global controller for notification badge updates
/// This allows any part of the app to trigger badge refresh
class NotificationBadgeController {
  static final NotificationBadgeController _instance = NotificationBadgeController._internal();
  factory NotificationBadgeController() => _instance;
  NotificationBadgeController._internal();

  final StreamController<void> _badgeUpdateController = StreamController<void>.broadcast();

  /// Stream that broadcasts when badge should be updated
  Stream<void> get badgeUpdateStream => _badgeUpdateController.stream;

  /// Trigger a badge update
  void triggerUpdate() {
    if (!_badgeUpdateController.isClosed) {
      _badgeUpdateController.add(null);
    }
  }

  /// Dispose the controller
  void dispose() {
    _badgeUpdateController.close();
  }
}

