import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DeepSeekService {
  final String apiKey;
  // Nouvelle URL DeepInfra (compatible OpenAI)
  final String baseUrl = 'https://api.deepinfra.com/v1/openai/chat/completions';

  DeepSeekService({required this.apiKey});

  Future<Map<String, dynamic>?> fetchJSONResponse({
    required String prompt,
    // Nouveau modèle par défaut : Mistral-Nemo-Instruct-2407
    String model = 'mistralai/Mistral-Nemo-Instruct-2407',
    double temperature = 0.5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an AI that only responds with valid, raw JSON objects. No markdown formatting, no explanations.'
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': temperature,
          'max_tokens': 4000,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        String? content = data['choices']?[0]?['message']?['content'];
        
        if (content != null) {
          content = content.trim();
          if (content.startsWith('```json')) {
            content = content.replaceAll('```json', '').replaceAll('```', '').trim();
          }
          
          content = content.replaceAll('\n', ' ').replaceAll('\r', '');

          final decoded = json.decode(content);
          if (decoded is List) {
            // Cas où le modèle renvoie directement une liste au lieu d'un objet JSON.
            // On le wrappe de manière heuristique. S'il contient des repas, on le met sous "meals".
            if (decoded.isNotEmpty && decoded.first is Map && decoded.first.containsKey('mealName')) {
              return {'meals': decoded};
            }
            if (decoded.isNotEmpty && decoded.first is Map && decoded.first.containsKey('day_index')) {
              return {'workout_plan': decoded};
            }
            // Fallback par défaut
            return {'data': decoded};
          }
          return decoded as Map<String, dynamic>?;
        }
        return null;
      }

      debugPrint('DeepInfra API Error: ${response.statusCode} - ${response.body}');
      throw Exception('Erreur API Mistral/DeepInfra (${response.statusCode})');
    } catch (e) {
      debugPrint('AIService Exception: $e');
      rethrow;
    }
  }
}
