import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UsageTrackerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;
  int currentStreak = 0;

  int get deepSeekLimit => 5 + ((currentStreak ~/ 5) * 3);

  UsageTrackerService({required this.userId});

  String _getTodayDocId() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<int> getApiCallCount(String apiType) async {
    final todayDoc = await _db.collection('users').doc(userId).collection('usageTracking').doc(_getTodayDocId()).get();
    if (todayDoc.exists) {
      return (todayDoc.data()?[apiType] ?? 0) as int;
    }
    return 0;
  }

  Future<void> incrementApiCall(String apiType) async {
    final docRef = _db.collection('users').doc(userId).collection('usageTracking').doc(_getTodayDocId());
    await docRef.set({
      apiType: FieldValue.increment(1),
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> getPhotoAnalysisCount() => getApiCallCount('photo_analysis_ia');
  Future<void> incrementPhotoAnalysis() => incrementApiCall('photo_analysis_ia');

  Future<int> getScanAnalysisCount() => getApiCallCount('scan_analysis_ia');
  Future<void> incrementScanAnalysis() => incrementApiCall('scan_analysis_ia');

  Future<int> getDeepSeekApiCallCount() => getApiCallCount('deepseek_api_calls');
  Future<void> incrementDeepSeekApiCall() => incrementApiCall('deepseek_api_calls');
}
