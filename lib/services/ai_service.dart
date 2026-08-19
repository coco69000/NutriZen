import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AIService {
  final FirebaseFunctions _functions;
  AIService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Appel Texte uniquement (Remplace DeepSeek)
  Future<Map<String, dynamic>?> fetchJSONResponse({
    required String prompt,
    String model = 'Qwen/Qwen2.5-7B-Instruct',
    double temperature = 0.5,
    String apiType = 'deepseek_api_calls',
  }) async {
    return _callFunction(
      prompt: prompt,
      model: model,
      imageBase64: null,
      temperature: temperature,
      apiType: apiType,
    );
  }

  /// Appel Image + Texte (Remplace Gemini / MealVision)
  Future<String?> fetchImageJSONResponse({
    required String prompt,
    required File imageFile,
    String model = 'Qwen/Qwen2.5-VL-7B-Instruct',
    double temperature = 0.5,
    String apiType = 'photo_analysis_ia',
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final result = await _callFunction(
        prompt: prompt,
        model: model,
        imageBase64: base64Image,
        temperature: temperature,
        apiType: apiType,
      );
      return result != null ? jsonEncode(result) : null;
    } on FirebaseFunctionsException {
      rethrow;
    } catch (e) {
      debugPrint('AIService Image Exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _callFunction({
    required String prompt,
    required String model,
    String? imageBase64,
    double temperature = 0.5,
    String apiType = 'deepseek_api_calls',
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('callAI');
      final HttpsCallableResult result = await callable.call({
        'prompt': prompt,
        'model': model,
        'temperature': temperature,
        'apiType': apiType,
        'clientDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        if (imageBase64 != null) 'imageBase64': imageBase64,
      });
      
      final resData = result.data;
      if (resData is Map && resData['success'] == true) {
        final jsonResult = resData['data'];
        String? content = jsonResult?['choices']?[0]?['message']?['content'];
        if (content != null) {
          content = content.trim();
          if (content.startsWith('```json')) {
            content = content.replaceAll('```json', '').replaceAll('```', '').trim();
          }
          content = content.replaceAll('\n', ' ').replaceAll('\r', '');
          final decoded = json.decode(content);
          final sanitized = _sanitizeData(decoded);
          if (sanitized is List) {
            if (sanitized.isNotEmpty && sanitized.first is Map && sanitized.first.containsKey('mealName')) {
              return {'meals': sanitized};
            }
            if (sanitized.isNotEmpty && sanitized.first is Map && sanitized.first.containsKey('day_index')) {
              return {'workout_plan': sanitized};
            }
            return {'data': sanitized};
          }
          return sanitized as Map<String, dynamic>?;
        }
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function Error [${e.code}]: ${e.message}');
      if (e.code == 'resource-exhausted' || e.code == 'permission-denied') {
        rethrow;
      }
      return null;
    } catch (e) {
      debugPrint('AIService Exception: $e');
      return null;
    }
  }

  dynamic _sanitizeData(dynamic input) {
    if (input is String) {
      return input
          .replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
    } else if (input is Map) {
      final Map<String, dynamic> cleanMap = {};
      input.forEach((key, value) {
        cleanMap[key.toString()] = _sanitizeData(value);
      });
      return cleanMap;
    } else if (input is List) {
      return input.map((item) => _sanitizeData(item)).toList();
    }
    return input;
  }

  // ==========================================
  // WRAPPERS POUR REMPLACER MealVisionService
  // ==========================================

  Future<String?> estimatePortionAndMacros(File imageFile, String? userDescription) async {
    final prompt = userDescription ?? "Estime la taille de la portion (en grammes) et donne moi une évaluation précise des macros (Calories, Protéines, Glucides, Lipides) pour ce repas. Sois direct au format JSON.";
    return fetchImageJSONResponse(prompt: prompt, imageFile: imageFile, apiType: 'photo_analysis_ia');
  }

  Future<String?> extractNutritionLabelOCR(File imageFile) async {
    const prompt = "Fais une reconnaissance de texte (OCR) sur cette étiquette nutritionnelle. Extrais UNIQUEMENT les valeurs pour 100g. Renvoie strictly un JSON : {'calories': int, 'proteins': double, 'carbs': double, 'fats': double}.";
    return fetchImageJSONResponse(prompt: prompt, imageFile: imageFile, apiType: 'scan_analysis_ia');
  }

  Future<String?> estimatePlateProportions(File imageFile) async {
    const prompt = "Analyse cette assiette complète. Identifie chaque aliment et estime leurs proportions. Renvoie un JSON avec les clés : 'ingredients_breakdown', 'proportions_text', 'total_calories', 'total_proteins', 'total_carbs', 'total_fats'.";
    return fetchImageJSONResponse(prompt: prompt, imageFile: imageFile, apiType: 'photo_analysis_ia');
  }

  Future<String?> estimatePortionWithReferenceObject(File imageFile, {String referenceType = "carte bancaire ou main"}) async {
    final prompt = """
Tu es un expert en vision par ordinateur appliqué à la nutrition.
Analyse cette photo qui contient une assiette et un objet de référence ($referenceType).
1. Repère l'objet témoin pour déduire l'échelle réelle.
2. Estime le volume en cm³ de chaque aliment visible.
3. Déduis le poids précis en grammes.
4. Calcule les calories, protéines, glucides et lipides totaux.
Renvoie UNIQUEMENT un JSON strict :
{
"estimated_weight_g": 350,
"food_name": "Description du plat",
"calories": 480,
"proteins": 35.0,
"carbs": 45.0,
"fats": 12.0,
"reference_detected": true
}
""";
    return fetchImageJSONResponse(prompt: prompt, imageFile: imageFile, apiType: 'photo_analysis_ia');
  }

  double adjustTDEE(double initialTDEE, double expectedWeightLoss, double actualWeightLoss, int days) {
    if (days < 7) return initialTDEE;
    double difference = expectedWeightLoss - actualWeightLoss;
    if (difference > 0.5) return initialTDEE * 0.95;
    if (difference < -0.5) return initialTDEE * 1.05;
    return initialTDEE;
  }
}
