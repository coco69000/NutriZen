import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class ActivityService {
  final Health _health = Health();

  Future<bool> requestPermissions() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.WORKOUT,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_ASLEEP,
    ];

    final permissions = types.map((e) => HealthDataAccess.READ).toList();

    await Permission.activityRecognition.request();
    await Permission.location.request();

    try {
      bool authorized = await _health.requestAuthorization(types, permissions: permissions);
      return authorized;
    } catch (e) {
      debugPrint("Erreur d'autorisation Health: $e");
      return false;
    }
  }

  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      debugPrint("Erreur récupération des pas: $e");
      return 0;
    }
  }

  Future<List<HealthDataPoint>> getWorkouts(DateTime start, DateTime end) async {
    try {
      List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.WORKOUT],
      );
      return _health.removeDuplicates(data);
    } catch (e) {
      debugPrint("Erreur récupération des workouts: $e");
      return [];
    }
  }

  Future<bool> writeWorkoutToHealth(String activityName, double calories, DateTime start, DateTime end) async {
    try {
      bool success = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.OTHER,
        start: start,
        end: end,
        totalEnergyBurned: calories.toInt(),
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
        title: activityName,
      );
      return success;
    } catch (e) {
      debugPrint("Erreur d'écriture Health/Google Fit: $e");
      return false;
    }
  }
}
