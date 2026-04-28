import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:podometre/models/meal_plan_entry.dart';
import 'package:podometre/models/meal_type.dart';
import 'package:podometre/models/food_entry.dart';
import 'package:podometre/providers/usage_tracker_service.dart';
import 'package:podometre/providers/user_profile.dart';
import 'package:podometre/services/service_locator.dart';

class MenuPlanningTab extends StatefulWidget {
  final List<MealPlanEntry> mealPlans;
  final Function(MealPlanEntry) addMealPlanEntry;
  final Function(String) deleteMealPlanEntry;
  final Function(FoodEntry) addFoodEntryToTracker;
  final DailyGoal currentGoals;
  final bool isPremiumUser;
  final UsageTrackerService usageTrackerService;
  final UserProfile userProfile;

  const MenuPlanningTab({
    super.key,
    required this.mealPlans,
    required this.addMealPlanEntry,
    required this.deleteMealPlanEntry,
    required this.addFoodEntryToTracker,
    required this.currentGoals,
    required this.isPremiumUser,
    required this.usageTrackerService,
    required this.userProfile,
  });

  @override
  State<MenuPlanningTab> createState() => _MenuPlanningTabState();
}

class _MenuPlanningTabState extends State<MenuPlanningTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _searchApiController = TextEditingController();

  String? _fridgeContent;
  String _recipeDifficulty = 'Normal'; // Simple, Normal, Difficile

  List<String> _selectedMealTypes = ['Dîner'];
  List<String> _selectedDishStyles = ['Plat chaud'];

  List<dynamic> _dailySuggestions = [];
  List<dynamic> _apiSearchResults = [];
  bool _isLoadingApi = false;
  bool _isSearchingApi = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchDailySuggestions();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _searchApiController.dispose();
    super.dispose();
  }

  // --- SCRAPING IMAGE BING ---
  Future<String?> _fetchImageUrl(String query) async {
    try {
      final url = Uri.parse(
        'https://www.bing.com/images/search?q=${Uri.encodeComponent(query + " recette plat")}&form=HDRSC3&first=1',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      if (response.statusCode == 200) {
        final RegExp regex = RegExp(r'murl":"(https?://[^&]+)"');
        final match = regex.firstMatch(response.body);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (e) {
      debugPrint("Erreur scraping image: $e");
    }
    return null;
  }

  // --- SUGGESTIONS THEMEALDB (Entrée, Plat, Dessert) ---
  Future<void> _fetchDailySuggestions() async {
    if (!mounted) return;
    setState(() => _isLoadingApi = true);

    try {
      final categories = [
        'Starter',
        'Beef',
        'Dessert',
      ]; // Entrée, Plat, Dessert
      List<dynamic> tempSuggestions = [];

      for (String cat in categories) {
        final response = await http.get(
          Uri.parse(
            'https://www.themealdb.com/api/json/v1/1/filter.php?c=$cat',
          ),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['meals'] != null && (data['meals'] as List).isNotEmpty) {
            final meals = data['meals'] as List;
            final randomMeal = meals[Random().nextInt(meals.length)];

            // Fetch details to get instructions
            final detailResp = await http.get(
              Uri.parse(
                'https://www.themealdb.com/api/json/v1/1/lookup.php?i=${randomMeal["idMeal"]}',
              ),
            );
            if (detailResp.statusCode == 200) {
              final detailData = json.decode(detailResp.body);
              tempSuggestions.add(detailData['meals'][0]);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _dailySuggestions = tempSuggestions;
          _isLoadingApi = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur API MealDB: $e");
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  Future<void> _searchApiRecipes(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearchingApi = false;
        _apiSearchResults = [];
      });
      return;
    }
    setState(() {
      _isLoadingApi = true;
      _isSearchingApi = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://www.themealdb.com/api/json/v1/1/search.php?s=$query',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _apiSearchResults = (data['meals'] as List?) ?? [];
            _isLoadingApi = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur recherche API: $e");
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  Future<void> _addApiMealToCalendar(dynamic mealApiData) async {
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    MealType selectedType = MealType.dinner;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Planifier : ${mealApiData['strMeal']}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text("Date"),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                  DropdownButtonFormField<MealType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type de repas',
                    ),
                    items:
                        [
                              MealType.lunch,
                              MealType.dinner,
                              MealType.breakfast,
                              MealType.snack,
                            ]
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.toCapitalizedString()),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    String desc =
                        "${mealApiData['strCategory'] ?? ''} - ${mealApiData['strArea'] ?? ''}";
                    widget.addMealPlanEntry(
                      MealPlanEntry(
                        date: selectedDate,
                        mealType: selectedType,
                        mealName: mealApiData['strMeal'],
                        description: desc,
                        imageUrl: mealApiData['strMealThumb'],
                        recipeInstructions: mealApiData['strInstructions'],
                      ),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${mealApiData['strMeal']} ajouté !"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MENU GRATUIT THEMEALDB (NLP Parsing via IA) ---
  Future<void> _generateFreeMealDBMenu() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "Création du menu TheMealDB et calcul des calories en cours...",
                  ),
                ),
              ],
            ),
          ),
    );

    try {
      final cats = ['Starter', 'Chicken', 'Dessert'];
      List<Map<String, dynamic>> rawMeals = [];
      for (String c in cats) {
        final r1 = await http.get(
          Uri.parse('https://www.themealdb.com/api/json/v1/1/filter.php?c=$c'),
        );
        final d1 = json.decode(r1.body);
        if (d1['meals'] != null) {
          final mList = d1['meals'] as List;
          final rMeal = mList[Random().nextInt(mList.length)];
          final r2 = await http.get(
            Uri.parse(
              'https://www.themealdb.com/api/json/v1/1/lookup.php?i=${rMeal["idMeal"]}',
            ),
          );
          final d2 = json.decode(r2.body);
          rawMeals.add(d2['meals'][0]);
        }
      }

      // TRÈS IMPORTANT : On raccourcit drastiquement les données envoyées à l'IA pour ne pas saturer sa mémoire
      String mealsJsonString = jsonEncode(
        rawMeals.map((m) {
          String rawInstructions = m['strInstructions'] ?? "";
          if (rawInstructions.length > 200)
            rawInstructions = rawInstructions.substring(
              0,
              200,
            ); // On coupe l'entrée !

          return {
            "titre": m['strMeal']?.replaceAll('"', "'"),
            "instructions": rawInstructions
                .replaceAll('\r', ' ')
                .replaceAll('\n', ' ')
                .replaceAll('"', "'"),
            "ingredients":
                List.generate(
                  10,
                  (i) =>
                      "${m['strMeasure${i + 1}']} ${m['strIngredient${i + 1}']}",
                ).map((e) => e.trim()).where((e) => e.length > 2).toList(),
          };
        }).toList(),
      );

      final prompt = '''
      Voici 3 recettes issues de TheMealDB (Entrée, Plat, Dessert).
      TÂCHE : Traduis les titres et instructions en français. Calcule les calories et macros.
      Adapte la complexité à la difficulté : $_recipeDifficulty.
      
      RÈGLES STRICTES POUR NE PAS COUPER LA RÉPONSE JSON :
      1. "description" : MAXIMUM 3 MOTS.
      2. "recipe_instructions" : MAXIMUM 1 SEULE PHRASE TRES COURTE.
      
      Recettes brutes : $mealsJsonString
      
      Retourne UNIQUEMENT un JSON strict :
      {
        "meals": [
          {
            "mealType": "dinner",
            "mealName": "Titre français",
            "description": "Très court",
            "prepTime": 15,
            "utensils": ["Poêle"],
            "ingredients": ["100g riz"],
            "recipe_instructions": "Une seule ligne d'instruction.",
            "estimatedCalories": 400, "estimatedProteins": 20.0, "estimatedCarbs": 30.0, "estimatedFats": 10.0
          }
        ]
      }
      ''';

      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.3,
      );
      if (mounted) Navigator.pop(context);

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();

        final mealsList = result['meals'] as List;
        for (int i = 0; i < mealsList.length; i++) {
          var m = mealsList[i];
          widget.addMealPlanEntry(
            MealPlanEntry(
              date: _selectedDay ?? DateTime.now(),
              mealType: MealType.dinner,
              mealName: m['mealName'],
              description: m['description'],
              recipeInstructions: m['recipe_instructions'],
              prepTime: (m['prepTime'] as num?)?.toInt(),
              utensils:
                  (m['utensils'] as List?)?.map((e) => e.toString()).toList(),
              ingredients:
                  (m['ingredients'] as List?)
                      ?.map((e) => e.toString())
                      .toList(),
              imageUrl:
                  rawMeals.length > i ? rawMeals[i]['strMealThumb'] : null,
              estimatedCalories: m['estimatedCalories'] ?? 0,
              estimatedProteins:
                  (m['estimatedProteins'] as num?)?.toDouble() ?? 0.0,
              estimatedCarbs: (m['estimatedCarbs'] as num?)?.toDouble() ?? 0.0,
              estimatedFats: (m['estimatedFats'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- MENU PREMIUM (Génération totale IA) ---
  Future<void> _generateMenuWithIA({bool isWeekly = false}) async {
    if (!widget.isPremiumUser) {
      return _generateFreeMealDBMenu();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "Génération IA et recherche d'images en cours...",
                  ),
                ),
              ],
            ),
          ),
    );

    final String prompt = '''
    Nutritionniste expert. Génère un plan de repas pour ${isWeekly ? "7 JOURS COMPLETS (Lundi à Dimanche)" : "1 JOUR"}.
    PROFIL: ${widget.userProfile.age} ans, ${widget.userProfile.gender}, Objectif: ${widget.currentGoals.weightGoalType}. Cal: ${widget.currentGoals.targetCalories} kcal/j.
    FILTRES DEMANDÉS: Repas (${_selectedMealTypes.join(', ')}), Style (${_selectedDishStyles.join(', ')}).
    DIFFICULTÉ: $_recipeDifficulty. PRÉFÉRENCES: "${_promptController.text}". FRIGO: "${_fridgeContent ?? 'Non fourni'}".
    
    RÈGLES STRICTES POUR NE PAS PLANTER L'API :
    1. "description": MAX 3 MOTS.
    2. "recipe_instructions": MAX 2 PHRASES TRES COURTES.
    3. "ingredients": MAX 5 INGREDIENTS ESSENTIELS.
    4. Pas de sauts de ligne dans les valeurs.
    
    Format JSON strict :
    {
      "meals": [
        {
          "day_offset": 0, // 0 = Lundi, 1 = Mardi, ... jusqu'à 6 = Dimanche (Si mode semaine)
          "mealType": "breakfast|lunch|dinner|snack",
          "mealName": "...",
          "description": "...",
          "prepTime": 15,
          "utensils": ["Poêle"],
          "ingredients": ["100g de poulet"],
          "recipe_instructions": "...",
          "estimatedCalories": 0, "estimatedProteins": 0.0, "estimatedCarbs": 0.0, "estimatedFats": 0.0
        }
      ]
    }
    ''';

    try {
      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.7,
      );
      if (mounted) Navigator.pop(context);

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();
        final List<dynamic> mealsRaw = result['meals'] ?? [];

        // CORRECTION DE LA DATE HEBDOMADAIRE (Trouver le lundi)
        DateTime baseDate = _selectedDay!;
        if (isWeekly) {
          // Retire le nombre de jours correspondant au jour actuel (Lundi = 1, donc on retire 0) pour tomber sur lundi.
          baseDate = baseDate.subtract(Duration(days: baseDate.weekday - 1));
        }

        for (var m in mealsRaw) {
          int dayOffset = (m['day_offset'] as num?)?.toInt() ?? 0;
          DateTime mealDate =
              isWeekly ? baseDate.add(Duration(days: dayOffset)) : baseDate;

          String? scrapedImageUrl = await _fetchImageUrl(m['mealName']);

          widget.addMealPlanEntry(
            MealPlanEntry(
              date: mealDate,
              mealType: MealType.values.firstWhere(
                (e) => e.name == m['mealType'],
                orElse: () => MealType.unknown,
              ),
              mealName: m['mealName'],
              description: m['description'],
              recipeInstructions: m['recipe_instructions'],
              prepTime: (m['prepTime'] as num?)?.toInt(),
              utensils:
                  (m['utensils'] as List?)?.map((e) => e.toString()).toList(),
              ingredients:
                  (m['ingredients'] as List?)
                      ?.map((e) => e.toString())
                      .toList(),
              imageUrl: scrapedImageUrl,
              estimatedCalories: m['estimatedCalories'] ?? 0,
              estimatedProteins:
                  (m['estimatedProteins'] as num?)?.toDouble() ?? 0.0,
              estimatedCarbs: (m['estimatedCarbs'] as num?)?.toDouble() ?? 0.0,
              estimatedFats: (m['estimatedFats'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur IA: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showShoppingListDialog() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Récupérer les ingrédients à partir d'aujourd'hui
    List<String> computedList = [];
    for (var plan in widget.mealPlans) {
      if (!plan.date.isBefore(today) && plan.ingredients != null) {
        computedList.addAll(plan.ingredients!);
      }
    }

    // Retirer les doublons tout en gardant une liste
    final uniqueIngredients = computedList.toSet().toList();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('🛒 Ma Liste de Courses'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  uniqueIngredients.isEmpty
                      ? const Text(
                        "Aucun ingrédient pour les repas planifiés à venir.",
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: uniqueIngredients.length,
                        itemBuilder:
                            (context, index) => ListTile(
                              leading: const Icon(
                                Icons.check_box_outline_blank,
                                color: Colors.teal,
                              ),
                              title: Text(uniqueIngredients[index]),
                              dense: true,
                            ),
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  void _showRecipeDialog(MealPlanEntry meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (_, controller) => ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (meal.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          meal.imageUrl!,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const SizedBox(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      meal.mealName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroBadge(
                          "${meal.estimatedCalories} kcal",
                          Colors.orange,
                        ),
                        _buildMacroBadge(
                          "${meal.estimatedProteins}g Pro",
                          Colors.blue,
                        ),
                        _buildMacroBadge(
                          "${meal.estimatedCarbs}g Glu",
                          Colors.green,
                        ),
                        _buildMacroBadge(
                          "${meal.estimatedFats}g Lip",
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          "Temps de préparation : ${meal.prepTime ?? '?'} minutes",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (meal.utensils != null && meal.utensils!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.kitchen, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Ustensiles : ${meal.utensils!.join(', ')}",
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 32, thickness: 1),
                    if (meal.ingredients != null &&
                        meal.ingredients!.isNotEmpty) ...[
                      Text(
                        "Ingrédients",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...meal.ingredients!.map(
                        (ing) => ListTile(
                          leading: const Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.teal,
                          ),
                          title: Text(ing),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const Divider(height: 32, thickness: 1),
                    ],
                    Text(
                      "Préparation",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      meal.recipeInstructions ?? "Aucune instruction générée.",
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check),
                      label: const Text("Fermer"),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildMacroBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealsForSelectedDay =
        _selectedDay != null
            ? widget.mealPlans
                .where((plan) => isSameDay(plan.date, _selectedDay))
                .toList()
            : [];

    final Map<MealType, List<MealPlanEntry>> groupedMeals = {
      MealType.breakfast: [],
      MealType.lunch: [],
      MealType.snack: [],
      MealType.dinner: [],
    };
    for (var m in mealsForSelectedDay) {
      if (groupedMeals.containsKey(m.mealType))
        groupedMeals[m.mealType]!.add(m);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menus & Recettes'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Bouton Liste de courses gardé en haut
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ElevatedButton.icon(
              onPressed:
                  _showShoppingListDialog, // Cette fonction agrège automatiquement les ingrédients du calendrier
              icon: const Icon(Icons.shopping_basket),
              label: const Text("Voir ma liste de courses (auto)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade100,
                foregroundColor: Colors.teal.shade900,
              ),
            ),
          ),

          Text(
            "Suggestion du Jour (TheMealDB)",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child:
                _isLoadingApi
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _dailySuggestions.length,
                      itemBuilder: (context, index) {
                        final meal = _dailySuggestions[index];
                        return Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (ctx) => RecipeDetailPage(
                                          mealData: meal,
                                          onAdd:
                                              () => _addApiMealToCalendar(meal),
                                        ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Image.network(
                                      meal['strMealThumb'],
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          meal['strMeal'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          index == 0
                                              ? "Entrée"
                                              : index == 1
                                              ? "Plat"
                                              : "Dessert",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          const Divider(height: 32),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Générer un menu IA",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _recipeDifficulty,
                    decoration: const InputDecoration(
                      labelText: "Difficulté des recettes",
                    ),
                    items:
                        ["Simple", "Normal", "Difficile"]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _recipeDifficulty = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      labelText: 'Préférences (ex: pas de viande)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Repas à inclure :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8,
                    children:
                        ['Petit-déjeuner', 'Déjeuner', 'Collation', 'Dîner']
                            .map(
                              (type) => FilterChip(
                                label: Text(type),
                                selected: _selectedMealTypes.contains(type),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected)
                                      _selectedMealTypes.add(type);
                                    else
                                      _selectedMealTypes.remove(type);
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Style :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8,
                    children:
                        ['Plat chaud', 'Plat froid', 'Dessert', 'Végétarien']
                            .map(
                              (type) => FilterChip(
                                label: Text(type),
                                selected: _selectedDishStyles.contains(type),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected)
                                      _selectedDishStyles.add(type);
                                    else
                                      _selectedDishStyles.remove(type);
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _generateMenuWithIA(isWeekly: false),
                          icon: const Icon(Icons.restaurant),
                          label: Text(
                            widget.isPremiumUser
                                ? "Menu du Jour"
                                : "Menu TheMealDB",
                          ),
                        ),
                      ),
                      if (widget.isPremiumUser) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                () => _generateMenuWithIA(isWeekly: true),
                            icon: const Icon(Icons.date_range),
                            label: const Text("Semaine"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildCalendar(),
          const SizedBox(height: 24),

          Text(
            'Plan pour le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDay!)}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (mealsForSelectedDay.isEmpty)
            const Center(
              child: Text(
                "Aucun repas planifié pour ce jour.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else ...[
            _buildMealSection(
              "Petit-déjeuner",
              groupedMeals[MealType.breakfast]!,
            ),
            _buildMealSection("Déjeuner", groupedMeals[MealType.lunch]!),
            _buildMealSection("Collation", groupedMeals[MealType.snack]!),
            _buildMealSection("Dîner", groupedMeals[MealType.dinner]!),
          ],
        ],
      ),
    );
  }

  Widget _buildMealSection(String title, List<MealPlanEntry> meals) {
    if (meals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        ...meals.map((meal) => _buildMealPlanEntryCard(meal)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCalendar() {
    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          locale: 'fr_FR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected:
              (selectedDay, focusedDay) => setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              }),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
      ),
    );
  }

  Widget _buildMealPlanEntryCard(MealPlanEntry meal) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading:
            meal.imageUrl != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    meal.imageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.fastfood),
                  ),
                )
                : const Icon(Icons.restaurant),
        title: Text(
          meal.mealName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${meal.estimatedCalories} kcal'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.description,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Text(
                  'Macros: ${meal.estimatedProteins.toStringAsFixed(0)}P / ${meal.estimatedCarbs.toStringAsFixed(0)}G / ${meal.estimatedFats.toStringAsFixed(0)}L',
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (meal.recipeInstructions != null &&
                        meal.recipeInstructions!.isNotEmpty)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.menu_book),
                        label: const Text('Voir la recette'),
                        onPressed: () => _showRecipeDialog(meal),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade100,
                          foregroundColor: Colors.orange.shade900,
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                          ),
                          tooltip: "Ajouter au suivi",
                          onPressed: () {
                            widget.addFoodEntryToTracker(meal.toFoodEntry());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("${meal.mealName} ajouté !"),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => widget.deleteMealPlanEntry(meal.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecipeDetailPage extends StatelessWidget {
  final Map<String, dynamic> mealData;
  final VoidCallback onAdd;

  const RecipeDetailPage({
    super.key,
    required this.mealData,
    required this.onAdd,
  });

  List<String> _getIngredients() {
    List<String> ingredients = [];
    for (int i = 1; i <= 20; i++) {
      final ingredient = mealData['strIngredient$i'];
      final measure = mealData['strMeasure$i'];

      if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
        String entry = ingredient;
        if (measure != null && measure.toString().trim().isNotEmpty) {
          entry = '$entry ($measure)';
        }
        ingredients.add(entry);
      }
    }
    return ingredients;
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = _getIngredients();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                mealData['strMeal'] ?? 'Recette',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              background:
                  mealData['strMealThumb'] != null
                      ? Image.network(
                        mealData['strMealThumb'],
                        fit: BoxFit.cover,
                        errorBuilder:
                            (c, e, s) => Container(color: Colors.grey),
                      )
                      : Container(color: Colors.teal),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (mealData['strCategory'] != null)
                          Chip(
                            avatar: const Icon(Icons.category, size: 18),
                            label: Text(mealData['strCategory']),
                            backgroundColor: Colors.orange.shade100,
                          ),
                        const SizedBox(width: 10),
                        if (mealData['strArea'] != null)
                          Chip(
                            avatar: const Icon(Icons.public, size: 18),
                            label: Text(mealData['strArea']),
                            backgroundColor: Colors.blue.shade100,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ingrédients',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children:
                            ingredients.map((ing) {
                              return ListTile(
                                leading: const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.teal,
                                ),
                                title: Text(ing),
                                dense: true,
                              );
                            }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mealData['strInstructions'] ??
                          'Aucune instruction disponible.',
                      style: const TextStyle(fontSize: 16, height: 1.6),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          onAdd();
        },
        label: const Text('Planifier ce repas'),
        icon: const Icon(Icons.calendar_month),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }
}
