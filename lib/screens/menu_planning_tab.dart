//menu_planing_screen.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../main.dart' hide isSameDay;
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
  final Set<String> _checkedIngredients = {};

  String _recipeDifficulty = 'Normal'; // Simple, Normal, Difficile
  final List<String> _selectedMealTypes = [
    'Petit-déjeuner',
    'Déjeuner',
    'Collation',
    'Dîner',
  ];

  List<dynamic> _dailySuggestions = [];
  List<dynamic> _apiSearchResults = [];
  bool _isLoadingApi = false;
  bool _isSearchingApi = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    debugPrint(
      "[TheMealDB] initState appelé - Lancement de _fetchDailySuggestions...",
    );

    _fetchDailySuggestions(); // <--- Assure-toi que c'est bien cette ligne
  }

  @override
  void dispose() {
    _promptController.dispose();
    _searchApiController.dispose();
    super.dispose();
  }

  Future<String?> _fetchImageUrl(String query) async {
    // ✅ CORRECTION : Le scraping Bing est instable et viole les règles des stores.
    // Remplacement par une image générique de haute qualité via Unsplash.
    return "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=300&fit=crop"; 
  }

  // --- LISTE DE COURSES AUTOMATIQUE PAR DATE ---
  void _showShoppingListDialog() {
    // Regrouper par date
    Map<DateTime, List<String>> ingredientsByDate = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var plan in widget.mealPlans) {
      // Filtrer les repas passés et s'assurer que les ingrédients existent
      if (!plan.date.isBefore(today) &&
          plan.ingredients != null &&
          plan.ingredients!.isNotEmpty) {
        final dateKey = DateTime(
          plan.date.year,
          plan.date.month,
          plan.date.day,
        );
        if (!ingredientsByDate.containsKey(dateKey)) {
          ingredientsByDate[dateKey] = [];
        }
        ingredientsByDate[dateKey]!.addAll(plan.ingredients!);
      }
    }

    final sortedDates = ingredientsByDate.keys.toList()..sort();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: const Text('🛒 Ma Liste de Courses'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child:
                        ingredientsByDate.isEmpty
                            ? const Text(
                              "Aucun ingrédient pour les repas planifiés à venir.",
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              itemCount: sortedDates.length,
                              itemBuilder: (context, index) {
                                final date = sortedDates[index];
                                // Filtrer les doublons quotidiens
                                final uniqueIngredients =
                                    ingredientsByDate[date]!.toSet().toList();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 16.0,
                                        bottom: 8.0,
                                      ),
                                      child: Text(
                                        DateFormat(
                                          'EEEE d MMMM',
                                          'fr_FR',
                                        ).format(date).toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                    ...uniqueIngredients.map((ing) {
                                      final isChecked = _checkedIngredients
                                          .contains(ing);
                                      return CheckboxListTile(
                                        value: isChecked,
                                        onChanged: (bool? val) {
                                          setStateDialog(() {
                                            if (val == true) {
                                              _checkedIngredients.add(ing);
                                            } else {
                                              _checkedIngredients.remove(ing);
                                            }
                                          });
                                        },
                                        title: Text(
                                          ing,
                                          style: TextStyle(
                                            decoration:
                                                isChecked
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                            color:
                                                isChecked ? Colors.grey : null,
                                          ),
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }),
                                    const Divider(),
                                  ],
                                );
                              },
                            ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setStateDialog(() {
                          _checkedIngredients.clear();
                        });
                      },
                      child: const Text('RÉINITIALISER'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('FERMER'),
                    ),
                  ],
                ),
          ),
    );
  }

  // --- SUGGESTIONS THEMEALDB AVEC LOGS ---
  // --- SUGGESTIONS THEMEALDB (VERSION CORRIGÉE ET ROBUSTE) ---
  // --- SUGGESTIONS THEMEALDB - VERSION FINALE (logs très précis) ---
  Future<void> _fetchDailySuggestions() async {
    if (!mounted) return;

    setState(() => _isLoadingApi = true);

    debugPrint("==================================================");
    debugPrint(
      "[TheMealDB] 🚀 DÉMARRAGE récupération suggestions quotidiennes",
    );

    try {
      // Catégories fiables selon TheMealDB en 2026
      final List<String> categories = ['Chicken', 'Beef', 'Seafood', 'Dessert'];

      final List<dynamic> tempSuggestions = [];

      for (final String category in categories) {
        debugPrint("\n[TheMealDB] === Catégorie : $category ===");

        final Uri url = Uri.https(
          'www.themealdb.com',
          '/api/json/v1/1/filter.php',
          {'c': category},
        );

        debugPrint("[TheMealDB] URL → $url");

        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 15));

        debugPrint("[TheMealDB] Status HTTP → ${response.statusCode}");
        debugPrint(
          "[TheMealDB] Taille réponse → ${response.body.length} caractères",
        );

        if (response.statusCode != 200) {
          debugPrint("[TheMealDB] ❌ Erreur HTTP ${response.statusCode}");
          continue;
        }

        final data = json.decode(response.body);

        debugPrint(
          "[TheMealDB] Clé 'meals' présente ? ${data.containsKey('meals')}",
        );
        debugPrint(
          "[TheMealDB] Type de 'meals' → ${data['meals']?.runtimeType}",
        );

        if (data['meals'] == null) {
          debugPrint(
            "[TheMealDB] ⚠️ 'meals' est NULL (comportement courant de TheMealDB)",
          );
          continue;
        }

        final List<dynamic>? meals = data['meals'] as List<dynamic>?;

        if (meals == null || meals.isEmpty) {
          debugPrint("[TheMealDB] ⚠️ Liste de repas vide pour $category");
          continue;
        }

        debugPrint("[TheMealDB] ✅ ${meals.length} repas trouvés !");

        // Sélection aléatoire
        final randomMeal = meals[Random().nextInt(meals.length)];
        final String mealId = randomMeal['idMeal'].toString();
        final String mealName = randomMeal['strMeal'] ?? 'Sans nom';

        debugPrint(
          "[TheMealDB] 🎲 Repas sélectionné → $mealName (ID: $mealId)",
        );

        // Récupération des détails complets
        final Uri detailUrl = Uri.https(
          'www.themealdb.com',
          '/api/json/v1/1/lookup.php',
          {'i': mealId},
        );

        final detailResp = await http
            .get(detailUrl)
            .timeout(const Duration(seconds: 10));

        if (detailResp.statusCode == 200) {
          final detailData = json.decode(detailResp.body);
          if (detailData['meals'] != null &&
              (detailData['meals'] as List).isNotEmpty) {
            tempSuggestions.add(detailData['meals'][0]);
            debugPrint("[TheMealDB] ✅ Détails ajoutés avec succès");
          } else {
            debugPrint("[TheMealDB] ⚠️ Détails vides pour cet ID");
          }
        } else {
          debugPrint(
            "[TheMealDB] ❌ Erreur lookup.php : ${detailResp.statusCode}",
          );
        }
      }

      debugPrint(
        "\n[TheMealDB] 🎯 FIN → ${tempSuggestions.length} suggestions récupérées",
      );

      if (mounted) {
        setState(() {
          _dailySuggestions = tempSuggestions;
          _isLoadingApi = false;
        });
      }

      if (tempSuggestions.isEmpty) {
        debugPrint(
          "[TheMealDB] ❌ Aucune suggestion n'a pu être chargée aujourd'hui",
        );
      }
    } catch (e, stackTrace) {
      debugPrint("[TheMealDB] 🔥 EXCEPTION : $e");
      debugPrint(stackTrace.toString());
      if (mounted) setState(() => _isLoadingApi = false);
    }

    debugPrint("==================================================\n");
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
          'https://www.themealdb.com/api/json/v1/1/search.php?s=${Uri.encodeQueryComponent(query)}',
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
              title: Text("Planifier : ${mealApiData['strMeal'] ?? ''}"),
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
                        "${mealApiData['strCategory'] ?? ''} - ${mealApiData['strArea'] ?? ''}"
                            .trim();
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
                    "Récupération des recettes et calcul des calories USDA...",
                  ),
                ),
              ],
            ),
          ),
    );

    try {
      final List<String> categories = ['Starter', 'Beef', 'Dessert'];
      final List<Map<String, dynamic>> rawMeals = [];

      // 1. Récupération des 3 repas depuis TheMealDB
      for (final String category in categories) {
        debugPrint("[TheMealDB] Génération menu → Catégorie : $category");

        final Uri filterUrl = Uri.https(
          'www.themealdb.com',
          '/api/json/v1/1/filter.php',
          {'c': category},
        );

        final r1 = await http
            .get(filterUrl)
            .timeout(const Duration(seconds: 10));

        if (r1.statusCode != 200) continue;

        final d1 = json.decode(r1.body);
        if (d1['meals'] == null || (d1['meals'] as List).isEmpty) continue;

        final mList = d1['meals'] as List;
        final randomMeal = mList[Random().nextInt(mList.length)];

        final Uri lookupUrl = Uri.https(
          'www.themealdb.com',
          '/api/json/v1/1/lookup.php',
          {'i': randomMeal['idMeal']},
        );

        final r2 = await http
            .get(lookupUrl)
            .timeout(const Duration(seconds: 10));

        if (r2.statusCode == 200) {
          final d2 = json.decode(r2.body);
          if (d2['meals'] != null && (d2['meals'] as List).isNotEmpty) {
            rawMeals.add(d2['meals'][0] as Map<String, dynamic>);
          }
        }
      }

      // 2. Traitement nutritionnel et ajout au Meal Plan
      for (int i = 0; i < rawMeals.length; i++) {
        final meal = rawMeals[i];

        List<String> ingredientsList = [];
        double totalCalories = 0;
        double totalProteins = 0;
        double totalCarbs = 0;
        double totalFats = 0;

        for (int j = 1; j <= 20; j++) {
          final String? measure = meal['strMeasure$j'];
          final String? ingredient = meal['strIngredient$j'];

          if (ingredient != null && ingredient.trim().isNotEmpty) {
            final cleanMeasure = (measure ?? '').trim();
            final cleanIngredient = ingredient.trim();

            final ingredientText =
                cleanMeasure.isEmpty
                    ? cleanIngredient
                    : '$cleanMeasure $cleanIngredient';

            ingredientsList.add(ingredientText);

            // Calcul des macros via USDA
            final macros = await SL.usdaNlp.getMacrosFromUSDA(
              cleanIngredient,
              cleanMeasure,
            );

            totalCalories += macros['calories'] ?? 0;
            totalProteins += macros['proteins'] ?? 0;
            totalCarbs += macros['carbs'] ?? 0;
            totalFats += macros['fats'] ?? 0;
          }
        }

        // Assignation intelligente du type de repas
        final MealType mealType = switch (i) {
          0 => MealType.lunch, // Starter
          1 => MealType.dinner, // Beef (plat principal)
          _ => MealType.snack, // Dessert
        };

        widget.addMealPlanEntry(
          MealPlanEntry(
            date: _selectedDay ?? DateTime.now(),
            mealType: mealType,
            mealName: meal['strMeal'] ?? "Repas TheMealDB",
            description: meal['strCategory'] ?? "TheMealDB",
            recipeInstructions: meal['strInstructions'],
            prepTime: 25,
            utensils: const ["Ustensiles standards"],
            ingredients: ingredientsList,
            imageUrl: meal['strMealThumb'],
            estimatedCalories: totalCalories.toInt(),
            estimatedProteins: totalProteins,
            estimatedCarbs: totalCarbs,
            estimatedFats: totalFats,
            source: 'TheMealDB',
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context); // Ferme le dialog de chargement
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Menu TheMealDB généré avec succès !"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint("[GenerateMenu] ERREUR : $e");
      debugPrint(stackTrace.toString());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la génération du menu : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateMenuWithIA({bool isWeekly = false}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (!widget.isPremiumUser) {
        return await _generateFreeMealDBMenu();
      }

      // 1. CALCUL DU RESTE MACRONUTRITIONNEL DE LA JOURNÉE
      final dailyEntries =
          widget.mealPlans
              .where((m) => isSameDay(m.date, _selectedDay ?? DateTime.now()))
              .toList();

      double consumedCarbs = dailyEntries.fold(
        0.0,
        (s, e) => s + e.estimatedCarbs,
      );
      double consumedPro = dailyEntries.fold(
        0.0,
        (s, e) => s + e.estimatedProteins,
      );

      String contextualConstraint = "";
      if (consumedCarbs > (widget.currentGoals.targetCarbs * 0.75)) {
        contextualConstraint =
            "L'utilisateur a déjà consommé l'essentiel de ses glucides (${consumedCarbs.toInt()}g). Propose impérativement des repas pauvres en glucides (Low-Carb), riches en protéines et légumes verts.";
      } else if (consumedPro < (widget.currentGoals.targetProteins * 0.4)) {
        contextualConstraint =
            "L'utilisateur manque de protéines aujourd'hui. Privilégie une source de protéine dense (poulet, poisson, tofu, œufs).";
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
                      "L'IA adapte les repas selon vos macronutriments restants...",
                    ),
                  ),
                ],
              ),
            ),
      );

      final String prompt = '''
      Génère un plan de repas pour ${isWeekly ? "7 JOURS (du Lundi au Dimanche)" : "1 JOUR"}.
      PROFIL: Objectif ${widget.currentGoals.weightGoalType}.
      CONTRAINTE CONTEXTUELLE DE LA JOURNÉE : $contextualConstraint
      INSTRUCTIONS VITALES:
      - Remplit le champ "recipe_instructions" avec des instructions TRES DETAILLEES, claires et étape par étape (plusieurs phrases) pour que l'utilisateur puisse cuisiner la recette. 
      - Le JSON doit valider avec certitude absolue la structure suivante. Evite les tableaux à la racine, mets toujours la clé "meals".
      
      Format JSON strict :
      {
        "meals": [
          {
            "day_offset": 0, 
            "mealType": "dinner",
            "mealName": "Titre plat",
            "description": "Courte",
            "prepTime": 15,
            "utensils": ["Poêle", "Casserole"],
            "ingredients": [
              {"name": "poulet", "measure": "100g"},
              {"name": "riz", "measure": "50g"}
            ],
            "recipe_instructions": "1. Coupez le poulet en dés. 2. Faites chauffer la poêle... etc."
          }
        ]
      }
      ''';

      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.6,
      );
      if (mounted) Navigator.pop(context);

      if (result != null) {
        final List<dynamic> mealsRaw = result['meals'] ?? [];

        DateTime baseDate = _selectedDay!;
        if (isWeekly)
          baseDate = baseDate.subtract(Duration(days: baseDate.weekday - 1));

        for (var m in mealsRaw) {
          int dayOffset = safeParseInt(m['day_offset']);
          DateTime mealDate =
              isWeekly ? baseDate.add(Duration(days: dayOffset)) : baseDate;

          List<dynamic> rawIngs = m['ingredients'] ?? [];
          List<String> combinedIngredients = [];
          double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;

          for (var ing in rawIngs) {
            String name = '';
            String measure = '';

            // ✅ CORRECTION : Gestion robuste des types (Map ou String)
            if (ing is Map) {
              name = ing['name']?.toString() ?? '';
              measure = ing['measure']?.toString() ?? '';
            } else if (ing is String) {
              name = ing;
              measure = '1 portion'; // Valeur par défaut si c'est juste une chaîne
            }

            combinedIngredients.add("${measure.trim()} ${name.trim()}".trim());
            
            final macros = await SL.usdaNlp.getMacrosFromUSDA(name, measure);
            totalCal += macros['calories'] ?? 0;
            totalPro += macros['proteins'] ?? 0;
            totalCarb += macros['carbs'] ?? 0;
            totalFat += macros['fats'] ?? 0;
          }

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
              prepTime:
                  m['prepTime'] != null ? safeParseInt(m['prepTime']) : null,
              utensils:
                  (m['utensils'] as List?)?.map((e) => e.toString()).toList(),
              ingredients: combinedIngredients,
              imageUrl: scrapedImageUrl,
              estimatedCalories: totalCal.toInt(),
              estimatedProteins: totalPro,
              estimatedCarbs: totalCarb,
              estimatedFats: totalFat,
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
                          "${meal.estimatedProteins.toStringAsFixed(0)}g Pro",
                          Colors.blue,
                        ),
                        _buildMacroBadge(
                          "${meal.estimatedCarbs.toStringAsFixed(0)}g Glu",
                          Colors.green,
                        ),
                        _buildMacroBadge(
                          "${meal.estimatedFats.toStringAsFixed(0)}g Lip",
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
                    const Divider(height: 32, thickness: 1),

                    // --- USTENSILES ---
                    if (meal.utensils != null && meal.utensils!.isNotEmpty) ...[
                      Text(
                        "Ustensiles Nécessaires",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children:
                            meal.utensils!
                                .map(
                                  (u) => Chip(
                                    label: Text(u),
                                    avatar: const Icon(Icons.kitchen, size: 18),
                                    backgroundColor: Colors.grey.shade100,
                                  ),
                                )
                                .toList(),
                      ),
                      const Divider(height: 32, thickness: 1),
                    ],

                    // --- INGRÉDIENTS ---
                    if (meal.ingredients != null &&
                        meal.ingredients!.isNotEmpty) ...[
                      Text(
                        "Ingrédients",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
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

                    // --- PRÉPARATION ---
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
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Bouton Liste de courses automatique au dessus
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ElevatedButton.icon(
              onPressed: _showShoppingListDialog,
              icon: const Icon(Icons.shopping_basket),
              label: const Text("Voir ma dernière liste de courses (Auto)"),
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
                    : _dailySuggestions.isEmpty
                    ? const Center(
                      child: Text(
                        "Aucune suggestion aujourd'hui, vérifiez votre connexion.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
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
                    initialValue: _recipeDifficulty,
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
                  // Suppression de la Checkbox "Créer une liste de courses"
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
                                    if (selected) {
                                      _selectedMealTypes.add(type);
                                    } else {
                                      _selectedMealTypes.remove(type);
                                    }
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
                          onPressed:
                              _isProcessing
                                  ? null
                                  : () => _generateMenuWithIA(isWeekly: false),
                          icon:
                              _isProcessing
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.restaurant),
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
                                _isProcessing
                                    ? null
                                    : () => _generateMenuWithIA(isWeekly: true),
                            icon:
                                _isProcessing
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.date_range),
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                meal.mealName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    meal.source == 'IA'
                        ? Colors.purple.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                meal.source,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: meal.source == 'IA' ? Colors.purple : Colors.green,
                ),
              ),
            ),
          ],
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
                              const SnackBar(content: Text(" ajouté !")),
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
