import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MealVisionService {
  final GenerativeModel _visionModel;

  MealVisionService({required String apiKey}) 
    : _visionModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

  Future<String?> estimatePortionAndMacros(File imageFile, String? userDescription) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final content = Content.multi([
        TextPart(userDescription ?? "Estime la taille de la portion (en grammes) et donne moi une évaluation précise des macros (Calories, Protéines, Glucides, Lipides) pour ce repas. Sois direct au format JSON."),
        DataPart('image/jpeg', bytes),
      ]);

      final response = await _visionModel.generateContent([content]);
      return response.text;
    } catch (e) {
      print("Erreur vision Gemini: $e");
      return null;
    }
  }

  Future<String?> estimatePlateProportions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final content = Content.multi([
        TextPart("Analyse cette assiette complète. Identifie chaque aliment (ex: riz, poulet, brocoli) et estime leurs proportions respectives par rapport à la taille totale de l'assiette (ex: 50% légumes, 25% protéines, 25% féculents). Déduis-en les grammes approximatifs et les macros totales. Renvoie un JSON avec les clés : 'ingredients_breakdown', 'proportions_text', 'total_calories', 'total_proteins', 'total_carbs', 'total_fats'."),
        DataPart('image/jpeg', bytes),
      ]);
      final response = await _visionModel.generateContent([content]);
      return response.text;
    } catch (e) {
      print("Erreur estimatePlateProportions: $e");
      return null;
    }
  }

  Future<String?> extractNutritionLabelOCR(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final content = Content.multi([
        TextPart("Fais une reconnaissance de texte (OCR) sur cette étiquette nutritionnelle. Extrais UNIQUEMENT les valeurs pour 100g. Renvoie strictement un JSON : {'calories': int, 'proteins': double, 'carbs': double, 'fats': double}."),
        DataPart('image/jpeg', bytes),
      ]);
      final response = await _visionModel.generateContent([content]);
      return response.text;
    } catch (e) {
      print("Erreur extractNutritionLabelOCR: $e");
      return null;
    }
  }

  double adjustTDEE(double initialTDEE, double expectedWeightLoss, double actualWeightLoss, int days) {
    if (days < 7) return initialTDEE; // Pas assez de données
    
    double difference = expectedWeightLoss - actualWeightLoss;
    
    if (difference > 0.5) {
      return initialTDEE * 0.95; // On réduit de 5%
    } else if (difference < -0.5) {
      return initialTDEE * 1.05; // On augmente de 5% (perte plus rapide = métabolisme rapide)
    }
    
    return initialTDEE;
  }
}
