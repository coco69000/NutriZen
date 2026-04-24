import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class HybridFoodDatabaseService {
  static Database? _database;
  
  // Initialiser la BDD SQLite locale (cache CIQUAL)
  Future<void> initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'ciqual_cache.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE food (
            id INTEGER PRIMARY KEY,
            name TEXT,
            calories INTEGER,
            proteins REAL,
            carbs REAL,
            fats REAL
          )
        ''');
      },
    );
  }

  // Chercher d'abord en local, puis croiser avec OpenFoodFacts
  Future<Map<String, dynamic>?> searchFood(String name) async {
    if (_database == null) await initDatabase();
    
    // 1- Recherche Locale (Simule CIQUAL)
    final List<Map<String, dynamic>> maps = await _database!.query(
      'food',
      where: 'name LIKE ?',
      whereArgs: ['%$name%'],
    );
    
    if (maps.isNotEmpty) {
      return maps.first;
    }

    // 2- Recherche OpenFoodFacts (Base de secours)
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?search_terms=$name&search_simple=1&action=process&json=1');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null && data['products'].length > 0) {
          final product = data['products'][0];
          final nutriments = product['nutriments'];
          
          final result = {
            'name': product['product_name'] ?? name,
            'calories': nutriments['energy-kcal_100g'] ?? 0,
            'proteins': nutriments['proteins_100g'] ?? 0.0,
            'carbs': nutriments['carbohydrates_100g'] ?? 0.0,
            'fats': nutriments['fat_100g'] ?? 0.0,
          };
          
          // Mise en cache local pour la prochaine fois
          await _database!.insert('food', {
            'name': result['name'],
            'calories': result['calories'],
            'proteins': result['proteins'],
            'carbs': result['carbs'],
            'fats': result['fats']
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          
          return result;
        }
      }
    } catch (e) {
      print("Erreur OpenFoodFacts: $e");
    }
    
    return null; // Retourner null si rien n'est trouvé, pour que Gemini puisse prendre le relais.
  }
}
