import 'package:flutter/foundation.dart';

class EmergencyState extends ChangeNotifier {
  Map<String, dynamic>? _currentEmergency;
  bool _showEmergencyCard = false;
  String? _emergencyId;

  Map<String, dynamic>? get currentEmergency => _currentEmergency;
  bool get showEmergencyCard => _showEmergencyCard;
  String? get emergencyId => _emergencyId;

  void setEmergency(Map<String, dynamic> emergency, String emergencyId) {
    _currentEmergency = emergency;
    _emergencyId = emergencyId;
    _showEmergencyCard = true;
    notifyListeners();
    if (kDebugMode) {
      print('🚨 EmergencyState: Emergency set - $emergencyId');
    }
  }

  void hideCard() {
    _showEmergencyCard = false;
    notifyListeners();
    if (kDebugMode) {
      print('🚨 EmergencyState: Card hidden');
    }
  }

  void showCard() {
    _showEmergencyCard = true;
    notifyListeners();
  }

  void clearEmergency() {
    _currentEmergency = null;
    _emergencyId = null;
    _showEmergencyCard = false;
    notifyListeners();
    if (kDebugMode) {
      print('🚨 EmergencyState: Emergency cleared');
    }
  }
}