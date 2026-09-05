import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../utils/helpers.dart';
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
  final String source;

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
    this.source = 'IA',
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
      source: source,
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
        'source': source,
      };

  factory MealPlanEntry.fromFirestore(Map<String, dynamic> json, String docId) =>
      MealPlanEntry(
        id: docId.isNotEmpty ? docId : (json['id'] ?? ''),
        date: (json['date'] as Timestamp).toDate(),
        mealType: MealType.values.firstWhere(
          (e) => e.name == json['mealType'],
          orElse: () => MealType.unknown,
        ),
        mealName: json['mealName'] ?? 'Repas sans nom',
        description: json['description'] ?? '',
        estimatedCalories: safeParseInt(json['estimatedCalories']),
        estimatedProteins: safeParseDouble(json['estimatedProteins']),
        estimatedCarbs: safeParseDouble(json['estimatedCarbs']),
        estimatedFats: safeParseDouble(json['estimatedFats']),
        imageUrl: json['imageUrl'],
        recipeInstructions: json['recipeInstructions'],
        prepTime: json['prepTime'] != null ? safeParseInt(json['prepTime']) : null,
        utensils: (json['utensils'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
        ingredients: (json['ingredients'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
        source: json['source'] ?? 'IA',
      );
}
