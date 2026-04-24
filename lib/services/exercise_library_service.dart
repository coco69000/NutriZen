import 'dart:convert';
import 'package:http/http.dart' as http;

class ExerciseItem {
  final String id;
  final String name;
  final String? force;
  final String level;
  final String? mechanic;
  final String? equipment;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String category;
  final List<String> images;

  ExerciseItem({
    required this.id,
    required this.name,
    this.force,
    required this.level,
    this.mechanic,
    this.equipment,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.instructions,
    required this.category,
    required this.images,
  });

  factory ExerciseItem.fromJson(Map<String, dynamic> json) {
    String id = json['id'] as String;
    List<String> images = List<String>.from(json['images'] ?? []);
    if (images.isEmpty) {
      images = ['$id/0.jpg', '$id/1.jpg'];
    }

    return ExerciseItem(
      id: id,
      name: json['name'] as String,
      force: json['force'] as String?,
      level: json['level'] as String? ?? 'beginner',
      mechanic: json['mechanic'] as String?,
      equipment: json['equipment'] as String?,
      primaryMuscles: List<String>.from(json['primaryMuscles'] ?? []),
      secondaryMuscles: List<String>.from(json['secondaryMuscles'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
      category: json['category'] as String? ?? 'strength',
      images: images,
    );
  }

  String getImageUrl(int index) {
    if (images.isNotEmpty && index >= 0 && index < images.length) {
      final path = images[index];
      final encodedPath = path.split('/').map((e) => Uri.encodeComponent(e)).join('/');
      return "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/" + encodedPath;
    }
    return '';
  }
}

class ExerciseLibraryService {
  final String _dbUrl = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json";
  List<ExerciseItem> _cachedExercises = [];

  Future<List<ExerciseItem>> fetchExercises() async {
    if (_cachedExercises.isNotEmpty) return _cachedExercises;
    
    try {
      final response = await http.get(Uri.parse(_dbUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cachedExercises = data.map((e) => ExerciseItem.fromJson(e)).toList();
        return _cachedExercises;
      } else {
        throw Exception('Failed to load exercises');
      }
    } catch (e) {
      print('Error fetching exercises: $e');
      return [];
    }
  }

  ExerciseItem? getExerciseById(String id) {
    try {
      return _cachedExercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ExerciseItem> search(String query) {
    if (query.isEmpty) return _cachedExercises;
    final lowerQuery = query.toLowerCase();
    return _cachedExercises.where((e) => 
      e.name.toLowerCase().contains(lowerQuery) || 
      e.primaryMuscles.any((m) => m.toLowerCase().contains(lowerQuery)) ||
      e.equipment != null && e.equipment!.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}
