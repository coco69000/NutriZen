import re

file_path = 'lib/screens/menu_planning_tab.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('class MenuPlanningTab extends StatefulWidget {')
end_idx = content.find('class RecipeDetailPage extends StatelessWidget {')

if start_idx == -1 or end_idx == -1:
    print(f"Error: start={start_idx}, end={end_idx}")
    exit(1)

new_code = '''class MenuPlanningTab extends StatefulWidget {
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

  // --- SCRAPING IMAGE BING AVEC LOGS ---
  Future<String?> _fetchImageUrl(String query) async {
    debugPrint("🔍 [IA-IMAGE] Tentative d'extraction d'image Bing pour : \");
    try {
      final url = Uri.parse(
        'https://www.bing.com/images/search?q=\&form=HDRSC3&first=1',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final RegExp regex = RegExp(
          r'(?:murl"|"murl"|murl&quot;)[:=]+(?:&quot;|")?(https?://[^"&;]+\.(?:jpg|jpeg|png))',
        );
        final match = regex.firstMatch(response.body);
        if (match != null) {
          debugPrint("✅ [IA-IMAGE] Image trouvée : \");
          return match.group(1);
        } else {
          debugPrint("⚠️ [IA-IMAGE] Aucune image trouvée dans le HTML pour : \");
        }
      } else {
        debugPrint("❌ [IA-IMAGE] Erreur HTTP \ lors de l'extraction d'image.");
      }
    } catch (e) {
      debugPrint("❌ [IA-IMAGE] Erreur (Exception) extraction image: \");
    }
    return null;
  }

  // --- LISTE DE COURSES AUTOMATIQUE PAR DATE ---
  void _showShoppingListDialog() {
    // Regrouper par date
    Map<DateTime, List<String>> ingredientsByDate = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var plan in widget.mealPlans) {
      // Filtrer les repas passés et s'assurer que les ingrédients existent
      if (!plan.date.isBefore(today) && plan.ingredients != null && plan.ingredients!.isNotEmpty) {
        final dateKey = DateTime(plan.date.year, plan.date.month, plan.date.day);
        if (!ingredientsByDate.containsKey(dateKey)) {
          ingredientsByDate[dateKey] = [];
        }
        ingredientsByDate[dateKey]!.addAll(plan.ingredients!);
      }
    }

    final sortedDates = ingredientsByDate.keys.toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🛒 Ma Liste de Courses'),
        content: SizedBox(
          width: double.maxFinite,
          child: ingredientsByDate.isEmpty
              ? const Text("Aucun ingrédient pour les repas planifiés à venir.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    // Filtrer les doublons quotidiens
                    final uniqueIngredients = ingredientsByDate[date]!.toSet().toList(); 
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                          child: Text(
                            DateFormat('EEEE d MMMM', 'fr_FR').format(date).toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                          ),
                        ),
                        ...uniqueIngredients.map((ing) => ListTile(
                          leading: const Icon(Icons.check_box_outline_blank, color: Colors.teal, size: 20),
                          title: Text(ing),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                        const Divider(),
                      ],
                    );
                  },
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

  // --- SUGGESTIONS THEMEALDB AVEC LOGS ---
  Future<void> _fetchDailySuggestions() async {
    if (!mounted) return;
    setState(() => _isLoadingApi = true);
    debugPrint("🔄 [TheMealDB] Démarrage de la récupération du menu du jour...");

    try {
      final categories = ['Starter', 'Beef', 'Dessert']; 
      List<dynamic> tempSuggestions = [];

      for (String cat in categories) {
        debugPrint("📡 [TheMealDB] Requête pour la catégorie: \");
        final response = await http.get(
          Uri.parse('https://www.themealdb.com/api/json/v1/1/filter.php?c=\'),
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['meals'] != null && (data['meals'] as List).isNotEmpty) {
            final meals = data['meals'] as List;
            final randomMeal = meals[Random().nextInt(meals.length)];
            
            debugPrint("🍲 [TheMealDB] Repas aléatoire trouvé (\) : \ (ID: \)");

            // Fetch details to get instructions
            final detailResp = await http.get(
              Uri.parse('https://www.themealdb.com/api/json/v1/1/lookup.php?i=\'),
            );
            if (detailResp.statusCode == 200) {
              final detailData = json.decode(detailResp.body);
              if (detailData['meals'] != null && detailData['meals'].isNotEmpty) {
                  tempSuggestions.add(detailData['meals'][0]);
                  debugPrint("✅ [TheMealDB] Détails récupérés pour \");
              } else {
                 debugPrint("⚠️ [TheMealDB] Détails vides pour l'ID \");
              }
            } else {
               debugPrint("❌ [TheMealDB] Erreur HTTP \ (Détails)");
            }
          } else {
            debugPrint("⚠️ [TheMealDB] Aucun repas trouvé pour la catégorie \");
          }
        } else {
           debugPrint("❌ [TheMealDB] Erreur HTTP \ (Catégorie)");
        }
      }

      if (mounted) {
        setState(() {
          _dailySuggestions = tempSuggestions;
          _isLoadingApi = false;
        });
        debugPrint("🎉 [TheMealDB] _dailySuggestions mis à jour avec \ repas.");
      }
    } catch (e) {
      debugPrint("❌ [TheMealDB] Erreur totale (Exception): \");
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
        Uri.parse('https://www.themealdb.com/api/json/v1/1/search.php?s=\'),
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
      debugPrint("Erreur recherche API: \");
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
              title: Text("Planifier : \"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text("Date"),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
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
                    decoration: const InputDecoration(labelText: 'Type de repas'),
                    items: [MealType.lunch, MealType.dinner, MealType.breakfast, MealType.snack]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.toCapitalizedString())))
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
                    String desc = "\ - \";
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
                        content: Text("\ ajouté !"),
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
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Récupération des recettes et calcul des calories USDA...")),
          ],
        ),
      ),
    );

    try {
      final cats = ['Starter', 'Beef', 'Dessert'];
      List<Map<String, dynamic>> rawMeals = [];

      for (String c in cats) {
        final r1 = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/filter.php?c=\'));
        if (r1.statusCode == 200) {
          final d1 = json.decode(r1.body);
          if (d1['meals'] != null) {
            final mList = d1['meals'] as List;
            final rMeal = mList[Random().nextInt(mList.length)];
            final r2 = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/lookup.php?i=\'));
            final d2 = json.decode(r2.body);
            rawMeals.add(d2['meals'][0]);
          }
        }
      }

      for (int i = 0; i < rawMeals.length; i++) {
        var m = rawMeals[i];
        List<String> extractedIngredients = [];
        double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;

        for (int j = 1; j <= 20; j++) {
          String? measure = m['strMeasure\'];
          String? ingredient = m['strIngredient\'];

          if (ingredient != null && ingredient.trim().isNotEmpty) {
            extractedIngredients.add("\ \".trim());
            final macros = await SL.usdaNlp.getMacrosFromUSDA(ingredient.trim(), measure ?? "");
            totalCal += macros['calories']!;
            totalPro += macros['proteins']!;
            totalCarb += macros['carbs']!;
            totalFat += macros['fats']!;
          }
        }

        MealType mType = (i == 1) ? MealType.dinner : MealType.snack;

        widget.addMealPlanEntry(
          MealPlanEntry(
            date: _selectedDay ?? DateTime.now(),
            mealType: mType,
            mealName: m['strMeal'] ?? "Repas",
            description: m['strCategory'] ?? "TheMealDB",
            recipeInstructions: m['strInstructions'],
            prepTime: 20,
            utensils: ["Standard"],
            ingredients: extractedIngredients,
            imageUrl: m['strMealThumb'],
            estimatedCalories: totalCal.toInt(),
            estimatedProteins: totalPro,
            estimatedCarbs: totalCarb,
            estimatedFats: totalFat,
          ),
        );
      }

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Menu TheMealDB généré !"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: \'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateMenuWithIA({bool isWeekly = false}) async {
    if (!widget.isPremiumUser) {
      return _generateFreeMealDBMenu();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("L'IA crée vos recettes, calcul des macros en cours...")),
          ],
        ),
      ),
    );

    final String prompt = \'\'\'
    Génère un plan de repas pour \.
    PROFIL: Objectif \.
    
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
          "recipe_instructions": "Étape 1. Étape 2."
        }
      ]
    }
    \'\'\';

    try {
      final result = await SL.aiService.fetchJSONResponse(prompt: prompt, temperature: 0.6);
      if (mounted) Navigator.pop(context);

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();
        final List<dynamic> mealsRaw = result['meals'] ?? [];

        DateTime baseDate = _selectedDay!;
        if (isWeekly) baseDate = baseDate.subtract(Duration(days: baseDate.weekday - 1));

        for (var m in mealsRaw) {
          int dayOffset = (m['day_offset'] as num?)?.toInt() ?? 0;
          DateTime mealDate = isWeekly ? baseDate.add(Duration(days: dayOffset)) : baseDate;

          List<dynamic> rawIngs = m['ingredients'] ?? [];
          List<String> combinedIngredients = [];
          double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;

          for (var ing in rawIngs) {
            String name = ing['name'] ?? '';
            String measure = ing['measure'] ?? '';
            combinedIngredients.add("\ \".trim());

            final macros = await SL.usdaNlp.getMacrosFromUSDA(name, measure);
            totalCal += macros['calories']!;
            totalPro += macros['proteins']!;
            totalCarb += macros['carbs']!;
            totalFat += macros['fats']!;
          }

          String? scrapedImageUrl = await _fetchImageUrl(m['mealName']);

          widget.addMealPlanEntry(
            MealPlanEntry(
              date: mealDate,
              mealType: MealType.values.firstWhere((e) => e.name == m['mealType'], orElse: () => MealType.unknown),
              mealName: m['mealName'],
              description: m['description'],
              recipeInstructions: m['recipe_instructions'],
              prepTime: (m['prepTime'] as num?)?.toInt(),
              utensils: (m['utensils'] as List?)?.map((e) => e.toString()).toList(),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur IA: \'), backgroundColor: Colors.red));
      }
    }
  }

  void _showRecipeDialog(MealPlanEntry meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ListView(
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
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroBadge("\ kcal", Colors.orange),
                _buildMacroBadge("\g Pro", Colors.blue),
                _buildMacroBadge("\g Glu", Colors.green),
                _buildMacroBadge("\g Lip", Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.timer, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text("Temps de préparation : \ minutes", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 32, thickness: 1),
            
            // --- USTENSILES ---
            if (meal.utensils != null && meal.utensils!.isNotEmpty) ...[
              Text(
                "Ustensiles Nécessaires",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: meal.utensils!.map((u) => Chip(
                  label: Text(u),
                  avatar: const Icon(Icons.kitchen, size: 18),
                  backgroundColor: Colors.grey.shade100,
                )).toList(),
              ),
              const Divider(height: 32, thickness: 1),
            ],

            // --- INGRÉDIENTS ---
            if (meal.ingredients != null && meal.ingredients!.isNotEmpty) ...[
              Text(
                "Ingrédients",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 8),
              ...meal.ingredients!.map((ing) => ListTile(
                leading: const Icon(Icons.circle, size: 8, color: Colors.teal),
                title: Text(ing),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              const Divider(height: 32, thickness: 1),
            ],

            // --- PRÉPARATION ---
            Text(
              "Préparation",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealsForSelectedDay = _selectedDay != null
        ? widget.mealPlans.where((plan) => isSameDay(plan.date, _selectedDay)).toList()
        : [];

    final Map<MealType, List<MealPlanEntry>> groupedMeals = {
      MealType.breakfast: [],
      MealType.lunch: [],
      MealType.snack: [],
      MealType.dinner: [],
    };
    for (var m in mealsForSelectedDay) {
      if (groupedMeals.containsKey(m.mealType)) groupedMeals[m.mealType]!.add(m);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menus & Recettes'),
        automaticallyImplyLeading: false,
      ),
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
            child: _isLoadingApi
                ? const Center(child: CircularProgressIndicator())
                : _dailySuggestions.isEmpty
                    ? const Center(child: Text("Aucune suggestion aujourd'hui, vérifiez votre connexion.", style: TextStyle(color: Colors.grey)))
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
                                      builder: (ctx) => RecipeDetailPage(
                                        mealData: meal,
                                        onAdd: () => _addApiMealToCalendar(meal),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            meal['strMeal'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            index == 0 ? "Entrée" : index == 1 ? "Plat" : "Dessert",
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                  Text("Générer un menu IA", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _recipeDifficulty,
                    decoration: const InputDecoration(labelText: "Difficulté des recettes"),
                    items: ["Simple", "Normal", "Difficile"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _recipeDifficulty = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(labelText: 'Préférences (ex: pas de viande)'),
                  ),
                  // Suppression de la Checkbox "Créer une liste de courses"
                  const SizedBox(height: 12),
                  const Text('Repas à inclure :', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: ['Petit-déjeuner', 'Déjeuner', 'Collation', 'Dîner']
                        .map((type) => FilterChip(
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
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _generateMenuWithIA(isWeekly: false),
                          icon: const Icon(Icons.restaurant),
                          label: Text(widget.isPremiumUser ? "Menu du Jour" : "Menu TheMealDB"),
                        ),
                      ),
                      if (widget.isPremiumUser) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _generateMenuWithIA(isWeekly: true),
                            icon: const Icon(Icons.date_range),
                            label: const Text("Semaine"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600),
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
            'Plan pour le \',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
            _buildMealSection("Petit-déjeuner", groupedMeals[MealType.breakfast]!),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
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
          onDaySelected: (selectedDay, focusedDay) => setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          }),
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
        ),
      ),
    );
  }

  Widget _buildMealPlanEntryCard(MealPlanEntry meal) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: meal.imageUrl != null
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
        title: Text(meal.mealName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('\ kcal'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.description, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Text(
                  'Macros: \P / \G / \L',
                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (meal.recipeInstructions != null && meal.recipeInstructions!.isNotEmpty)
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
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          tooltip: "Ajouter au suivi",
                          onPressed: () {
                            widget.addFoodEntryToTracker(meal.toFoodEntry());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("\ ajouté !")),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
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
'''

new_file_content = content[:start_idx] + new_code + content[end_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_file_content)

print("Updated successfully")