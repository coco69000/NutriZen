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
      
      // Retourne un JSON structuré ou une analyse détaillée selon le prompt
      return response.text;
    } catch (e) {
      print("Erreur vision Gemini: $e");
      return null;
    }
  }

  // Boucle de rétroaction TDEE simple
  double adjustTDEE(double initialTDEE, double expectedWeightLoss, double actualWeightLoss, int days) {
    if (days < 7) return initialTDEE; // Pas assez de données
    
    // Si l'utilisateur perd moins que prévu, c'est que son métabolisme
    // est plus lent ou qu'il sous-estime ses portions.
    double difference = expectedWeightLoss - actualWeightLoss;
    
    // Règle arbitraire : on ajuste de 5% par tranche de 0.5kg de différence sur 2 semaines.
    if (difference > 0.5) {
      return initialTDEE * 0.95; // On réduit de 5%
    } else if (difference < -0.5) {
      return initialTDEE * 1.05; // On augmente de 5% (perte plus rapide = métabolisme rapide)
    }
    
    return initialTDEE;
  }
}
