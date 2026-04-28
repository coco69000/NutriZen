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
          return json.decode(content) as Map<String, dynamic>?;
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
