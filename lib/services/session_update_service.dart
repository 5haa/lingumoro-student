import 'package:flutter/foundation.dart';

/// Service to notify listeners when sessions/classes are updated
class SessionUpdateService extends ChangeNotifier {
  static final SessionUpdateService _instance = SessionUpdateService._internal();
  
  factory SessionUpdateService() {
    return _instance;
  }
  
  SessionUpdateService._internal();
  
  /// Notify listeners that sessions have been updated
  void notifySessionsUpdated() {
    notifyListeners();
  }
}

