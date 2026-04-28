enum MealType { breakfast, lunch, dinner, snack, unknown }

extension MealTypeExtension on MealType {
  String toCapitalizedString() {
    switch (this) {
      case MealType.breakfast:
        return 'Petit-déjeuner';
      case MealType.lunch:
        return 'Déjeuner';
      case MealType.dinner:
        return 'Dîner';
      case MealType.snack:
        return 'Collation';
      case MealType.unknown:
        return 'Inconnu';
    }
  }
}
