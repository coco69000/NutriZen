import 'package:flutter/foundation.dart';

class ScheduledMeal {
  final String name;
  final List<Ingredient> ingredients;

  ScheduledMeal(this.name, this.ingredients);
}

class Ingredient {
  final String name;
  final double quantity; // En grammes
  final String unit;

  Ingredient(this.name, this.quantity, this.unit);

  // Helper pour fusionner les mêmes ingrédients
  Ingredient mergeWith(Ingredient other) {
    return Ingredient(
      name,
      quantity + other.quantity,
      unit,
    );
  }
}

class GroceryListService {
  
  // Génère une liste de courses optimisée et "Zéro déchet"
  /// [plannedMeals] : Les repas prévus de la semaine
  /// [fridgeInventory] : Ce qu'il reste déjà chez l'utilisateur
  List<Ingredient> generateZeroWasteList(
      List<ScheduledMeal> plannedMeals, 
      List<Ingredient> fridgeInventory) {
        
    // 1. Fusionner tous les ingrédients de tous les repas
    Map<String, Ingredient> aggregatedIngredients = {};

    for (var meal in plannedMeals) {
      for (var ing in meal.ingredients) {
        final key = ing.name.toLowerCase().trim();
        if (aggregatedIngredients.containsKey(key)) {
          aggregatedIngredients[key] = aggregatedIngredients[key]!.mergeWith(ing);
        } else {
          aggregatedIngredients[key] = Ingredient(key, ing.quantity, ing.unit);
        }
      }
    }

    // 2. Soustraire ce qui est déjà dans le frigo / placard
    for (var fridgeItem in fridgeInventory) {
      final key = fridgeItem.name.toLowerCase().trim();
      
      if (aggregatedIngredients.containsKey(key)) {
        double needed = aggregatedIngredients[key]!.quantity;
        double available = fridgeItem.quantity;
        
        if (available >= needed) {
          // On a suffisamment, on retire de la liste de courses
          aggregatedIngredients.remove(key);
        } else {
          // Il en manque un peu, on met à jour la quantité à acheter
          aggregatedIngredients[key] = Ingredient(key, needed - available, fridgeItem.unit);
        }
      }
    }

    // 3. (Optionnel pour l'IA) : Suggérer d'ajuster les repas pour vider le frigo.
    // L'ajout du RAG ou de Gemini ici pourrait proposer des recettes basées sur les restes.

    debugPrint("Génération de liste optimisée: ${aggregatedIngredients.length} articles restants à acheter.");
    return aggregatedIngredients.values.toList();
  }
}
