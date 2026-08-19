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

  Future<void> incrementApiCall(String apiType) async {
    if (userId.isEmpty) return;
    try {
      final docRef = _db
          .collection('users')
          .doc(userId)
          .collection('usageTracking')
          .doc(_getTodayDocId());
      await docRef.set({
        apiType: FieldValue.increment(1),
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erreur mise à jour usageTracking: $e');
    }
  }

  Future<int> getPhotoAnalysisCount() => getApiCallCount('photo_analysis_ia');
  Future<void> incrementPhotoAnalysis() => incrementApiCall('photo_analysis_ia');

  Future<int> getScanAnalysisCount() => getApiCallCount('scan_analysis_ia');
  Future<void> incrementScanAnalysis() => incrementApiCall('scan_analysis_ia');

  Future<int> getAiApiCallCount() async {
    final count = await getApiCallCount('ai_api_calls');
    if (count == 0) {
      return getApiCallCount('deepseek_api_calls');
    }
    return count;
  }
  Future<void> incrementAiApiCall() => incrementApiCall('ai_api_calls');

  Future<int> getDeepSeekApiCallCount() => getAiApiCallCount();
  Future<void> incrementDeepSeekApiCall() => incrementAiApiCall();
}
