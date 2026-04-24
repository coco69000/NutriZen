import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HabitService {
  static const String _mealsKey = 'user_meal_habits';

  // Enregistre un repas pris à une heure donnée
  Future<void> recordMealTime(String mealName, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Structure: {"Café": [8, 8, 9], "Salade": [12, 13]} -> heures
    String? storedHabits = prefs.getString(_mealsKey);
    Map<String, List<int>> habits = {};
    
    if (storedHabits != null) {
      Map<String, dynamic> decoded = jsonDecode(storedHabits);
      decoded.forEach((key, value) {
        habits[key] = List<int>.from(value);
      });
    }

    if (!habits.containsKey(mealName)) {
      habits[mealName] = [];
    }
    habits[mealName]!.add(time.hour);

    await prefs.setString(_mealsKey, jsonEncode(habits));
  }

  // Suggère un repas en fonction de l'heure actuelle
  Future<String?> suggestMealBasedOnHabit(int currentHour) async {
    final prefs = await SharedPreferences.getInstance();
    String? storedHabits = prefs.getString(_mealsKey);
    if (storedHabits == null) return null;

    Map<String, dynamic> decoded = jsonDecode(storedHabits);
    String? bestMatch;
    int maxOccurrences = 0;

    decoded.forEach((mealName, hoursList) {
      List<int> hours = List<int>.from(hoursList);
      // Compte combien de fois ce repas a été pris autour de cette heure (+/- 1h)
      int count = hours.where((h) => (h - currentHour).abs() <= 1).length;
      
      if (count > maxOccurrences && count > 2) { // Au moins 3 occurrences pour une habitude
        maxOccurrences = count;
        bestMatch = mealName;
      }
    });

    return bestMatch;
  }
}
