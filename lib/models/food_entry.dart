import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'meal_type.dart';

const uuid = Uuid();

class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final double proteins;
  final double carbs;
  final double fats;
  final DateTime timestamp;
  final MealType mealType;
  final bool isAiEstimated;
  final String? source;

  FoodEntry({
    String? id,
    required this.name,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.timestamp,
    this.mealType = MealType.unknown,
    this.isAiEstimated = false,
    this.source,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'calories': calories,
        'proteins': proteins,
        'carbs': carbs,
        'fats': fats,
        'timestamp': Timestamp.fromDate(timestamp),
        'mealType': mealType.name,
        'isAiEstimated': isAiEstimated,
        'source': source,
      };

  factory FoodEntry.fromFirestore(Map<String, dynamic> json, String docId) =>
      FoodEntry(
        id: json['id'] ?? docId,
        name: json['name'],
        calories: json['calories'],
        proteins: (json['proteins'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fats: (json['fats'] as num).toDouble(),
        timestamp: (json['timestamp'] as Timestamp).toDate(),
        mealType: MealType.values.firstWhere(
          (e) => e.name == json['mealType'],
          orElse: () => MealType.unknown,
        ),
        isAiEstimated: json['isAiEstimated'] ?? false,
        source: json['source'],
      );
}
