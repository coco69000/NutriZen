import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'food_entry.dart';
import 'meal_type.dart';

class MealPlanEntry {
  final String id;
  final DateTime date;
  final MealType mealType;
  final String mealName;
  final String description;
  final int estimatedCalories;
  final double estimatedProteins;
  final double estimatedCarbs;
  final double estimatedFats;
  final String? imageUrl;
  final String? recipeInstructions;
  final int? prepTime;
  final List<String>? utensils;
  final List<String>? ingredients;

  MealPlanEntry({
    String? id,
    required this.date,
    required this.mealType,
    required this.mealName,
    this.description = '',
    this.estimatedCalories = 0,
    this.estimatedProteins = 0.0,
    this.estimatedCarbs = 0.0,
    this.estimatedFats = 0.0,
    this.imageUrl,
    this.recipeInstructions,
    this.prepTime,
    this.utensils,
    this.ingredients,
  }) : id = id ?? const Uuid().v4();

  FoodEntry toFoodEntry() {
    return FoodEntry(
      name: mealName,
      calories: estimatedCalories,
      proteins: estimatedProteins,
      carbs: estimatedCarbs,
      fats: estimatedFats,
      timestamp: date,
      mealType: mealType,
      isAiEstimated: true,
      source: 'Plan IA',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'date': Timestamp.fromDate(date),
        'mealType': mealType.name,
        'mealName': mealName,
        'description': description,
        'estimatedCalories': estimatedCalories,
        'estimatedProteins': estimatedProteins,
        'estimatedCarbs': estimatedCarbs,
        'estimatedFats': estimatedFats,
        'imageUrl': imageUrl,
        'recipeInstructions': recipeInstructions,
        'prepTime': prepTime,
        'utensils': utensils,
        'ingredients': ingredients,
      };

  factory MealPlanEntry.fromFirestore(Map<String, dynamic> json, String docId) =>
      MealPlanEntry(
        id: json['id'] ?? docId,
        date: (json['date'] as Timestamp).toDate(),
        mealType: MealType.values.firstWhere(
          (e) => e.name == json['mealType'],
          orElse: () => MealType.unknown,
        ),
        mealName: json['mealName'],
        description: json['description'] ?? '',
        estimatedCalories: json['estimatedCalories'] ?? 0,
        estimatedProteins: (json['estimatedProteins'] as num?)?.toDouble() ?? 0.0,
        estimatedCarbs: (json['estimatedCarbs'] as num?)?.toDouble() ?? 0.0,
        estimatedFats: (json['estimatedFats'] as num?)?.toDouble() ?? 0.0,
        imageUrl: json['imageUrl'],
        recipeInstructions: json['recipeInstructions'],
        prepTime: json['prepTime'] as int?,
        utensils: (json['utensils'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
        ingredients: (json['ingredients'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      );
}
