import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class UsageTrackerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;
  int currentStreak = 0;

  int get aiLimit => 5 + ((currentStreak ~/ 5) * 3);
  int get deepSeekLimit => aiLimit;

  UsageTrackerService({required this.userId});

  String _getTodayDocId() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<int> getApiCallCount(String apiType) async {
    if (userId.isEmpty) return 0;
    try {
      final todayDoc = await _db
          .collection('users')
          .doc(userId)
          .collection('usageTracking')
          .doc(_getTodayDocId())
          .get();
      if (todayDoc.exists) {
        return (todayDoc.data()?[apiType] ?? 0) as int;
      }
    } catch (e) {
      debugPrint('Erreur lecture usageTracking: $e');
    }
    return 0;
  }

  Future<int> getPhotoAnalysisCount() => getApiCallCount('photo_analysis_ia');
  Future<int> getScanAnalysisCount() => getApiCallCount('scan_analysis_ia');

  Future<int> getAiApiCallCount() async {
    final count = await getApiCallCount('ai_api_calls');
    if (count == 0) {
      return getApiCallCount('deepseek_api_calls');
    }
    return count;
  }

  Future<int> getDeepSeekApiCallCount() => getAiApiCallCount();
}
