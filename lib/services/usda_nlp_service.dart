import 'dart:convert';
import 'package:http/http.dart' as http;

class UsdaNlpService {
  final String _usdaApiKey = 'X5NbNt9p8kyfqHirb4H9pgPyI1JaV4rJ10rvnlBn';

  // MOTEUR NLP POUR CONVERTIR LES MESURES EN GRAMMES
  double parseMeasureToGrams(String measureText) {
    String m = measureText.toLowerCase().trim();
    if (m.isEmpty) return 100.0;

    double amount = 1.0;
    final RegExp numRegex = RegExp(r'(\d+[\.,]?\d*|\d+\/\d+)');
    final match = numRegex.firstMatch(m);

    if (match != null) {
      String numStr = match.group(0)!;
      if (numStr.contains('/')) {
        var parts = numStr.split('/');
        if (parts.length == 2 && double.tryParse(parts[1]) != 0) {
          amount = double.parse(parts[0]) / double.parse(parts[1]);
        }
      } else {
        amount = double.parse(numStr.replaceAll(',', '.'));
      }
    }

    if (m.contains('cup')) return amount * 240.0;
    if (m.contains('tbsp') || m.contains('tablespoon') || m.contains('tbs'))
      return amount * 15.0;
    if (m.contains('tsp') || m.contains('teaspoon')) return amount * 5.0;
    if (m.contains('oz') || m.contains('ounce')) return amount * 28.35;
    if (m.contains('lb') || m.contains('pound')) return amount * 453.59;
    if (m.contains('ml') || m.contains('milliliter')) return amount;
    if (m.contains('kg') || m.contains('kilogram')) return amount * 1000.0;
    if (m.contains('g') || m.contains('gram')) return amount;
    if (m.contains('pinch') || m.contains('dash')) return amount * 1.0;
    if (m.contains('clove')) return amount * 5.0;

    return amount * 120.0;
  }

  // RECHERCHE DANS LA BASE USDA
  Future<Map<String, double>> getMacrosFromUSDA(
    String ingredientName,
    String measureText,
  ) async {
    double weightInGrams = parseMeasureToGrams(measureText);
    String cleanName =
        ingredientName
            .replaceAll(RegExp(r'[0-9]'), '')
            .trim(); // Nettoie les chiffres éventuels

    try {
      final url = Uri.parse(
        'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$_usdaApiKey&query=${Uri.encodeComponent(cleanName)}&pageSize=1',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['foods'] != null && (data['foods'] as List).isNotEmpty) {
          final food = data['foods'][0];
          final nutrients = food['foodNutrients'] as List;

          double kcal = 0, pro = 0, fat = 0, carbs = 0;

          for (var n in nutrients) {
            if (n['nutrientId'] == 1008) kcal = (n['value'] as num).toDouble();
            if (n['nutrientId'] == 1003) pro = (n['value'] as num).toDouble();
            if (n['nutrientId'] == 1004) fat = (n['value'] as num).toDouble();
            if (n['nutrientId'] == 1005) carbs = (n['value'] as num).toDouble();
          }

          return {
            'calories': (kcal / 100) * weightInGrams,
            'proteins': (pro / 100) * weightInGrams,
            'carbs': (carbs / 100) * weightInGrams,
            'fats': (fat / 100) * weightInGrams,
          };
        }
      }
    } catch (e) {
      print('Erreur USDA API: $e');
    }

    return {
      'calories': (50.0 / 100) * weightInGrams,
      'proteins': 0.0,
      'carbs': 0.0,
      'fats': 0.0,
    };
  }
}
