import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LongTermMemoryService {
  static const String _adviceLogKey = 'user_advice_log';
  static const String _userPatternsKey = 'user_patterns';

  // Enregistre qu'un conseil précis a été donné pour ne pas spammer
  Future<void> recordAdvice(String adviceId) async {
    final prefs = await SharedPreferences.getInstance();
    
    Map<String, dynamic> logs = _getDecodedMap(prefs.getString(_adviceLogKey));
    logs[adviceId] = DateTime.now().toIso8601String();
    
    await prefs.setString(_adviceLogKey, jsonEncode(logs));
  }

  // Vérifie si le conseil a été donné récemment (ex: dans les dernières 24h)
  Future<bool> hasReceivedAdviceRecently(String adviceId, {int thresholdHours = 24}) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> logs = _getDecodedMap(prefs.getString(_adviceLogKey));
    
    if (logs.containsKey(adviceId)) {
      DateTime lastGiven = DateTime.parse(logs[adviceId]);
      if (DateTime.now().difference(lastGiven).inHours < thresholdHours) {
        return true;
      }
    }
    return false;
  }

  // Mémorise si l'utilisateur a rejeté ou accepté un conseil (ex: décaler le jeûne)
  Future<void> logAdviceReaction(String adviceId, bool wasHelpful) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> patterns = _getDecodedMap(prefs.getString(_userPatternsKey));
    
    patterns['reaction_$adviceId'] = wasHelpful;
    await prefs.setString(_userPatternsKey, jsonEncode(patterns));
  }

  Future<bool> hasUserAcceptedAdvice(String adviceId) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> patterns = _getDecodedMap(prefs.getString(_userPatternsKey));
    return patterns['reaction_$adviceId'] == true;
  }

  // Comportement: l'utilisateur dépasse souvent ses calories le vendredi ?
  Future<void> recordFridayCaloricSurplus() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> patterns = _getDecodedMap(prefs.getString(_userPatternsKey));
    
    int surplusCount = patterns['friday_surplus'] ?? 0;
    patterns['friday_surplus'] = surplusCount + 1;
    
    await prefs.setString(_userPatternsKey, jsonEncode(patterns));
  }

  Future<bool> doesOvereatOnFridays() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> patterns = _getDecodedMap(prefs.getString(_userPatternsKey));
    
    // S'il a dépassé au moins 2 fois le vendredi, c'est considéré comme un "pattern"
    return (patterns['friday_surplus'] ?? 0) >= 2;
  }

  Map<String, dynamic> _getDecodedMap(String? data) {
    if (data == null) return {};
    return jsonDecode(data);
  }
}
