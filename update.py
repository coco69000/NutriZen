import re

file_path = 'lib/main.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('class MenuPlanningTab extends StatefulWidget {')
end_idx = content.find('class RecipeDetailPage extends StatelessWidget {')

if start_idx == -1 or end_idx == -1:
    print(f"Error: start={start_idx}, end={end_idx}")
    exit(1)

new_content = """class MenuPlanningTab extends StatefulWidget {
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

  bool _generateShoppingList = false;
  String? _fridgeContent;
  String _recipeDifficulty = 'Normal'; // Simple, Normal, Difficile

  List<dynamic> _dailySuggestions = [];
  List<dynamic> _apiSearchResults = [];
  bool _isLoadingApi = false;
  bool _isSearchingApi = false;

  List<String> _savedShoppingList = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchDailySuggestions();
    _loadShoppingList();
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
      final url = Uri.parse('https://www.bing.com/images/search?q=${Uri.encodeComponent(query + " recette plat")}&form=HDRSC3&first=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });
      if (response.statusCode == 200) {
        final RegExp regex = RegExp(r'murl&quot;:&quot;(https?://[^&]+)&quot;');
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

  // --- LISTE DE COURSES ---
  Future<void> _loadShoppingList() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedShoppingList = prefs.getStringList('shopping_list_${widget.userProfile.id}') ?? [];
    });
  }

  Future<void> _saveShoppingList(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('shopping_list_${widget.userProfile.id}', list);
    setState(() => _savedShoppingList = list);
  }

  // --- SUGGESTIONS THEMEALDB (Entrée, Plat, Dessert) ---
  Future<void> _fetchDailySuggestions() async {
    if (!mounted) return;
    setState(() => _isLoadingApi = true);

    try {
      final categories = ['Starter', 'Beef', 'Dessert']; // Entrée, Plat, Dessert
      List<dynamic> tempSuggestions = [];

      for (String cat in categories) {
        final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/filter.php?c=$cat'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['meals'] != null && (data['meals'] as List).isNotEmpty) {
            final meals = data['meals'] as List;
            final randomMeal = meals[Random().nextInt(meals.length)];
            
            // Fetch details to get instructions
            final detailResp = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/lookup.php?i=${randomMeal["idMeal"]}'));
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
      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/search.php?s=$query'));
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
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () {
                    String desc = "${mealApiData['strCategory'] ?? ''} - ${mealApiData['strArea'] ?? ''}";
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${mealApiData['strMeal']} ajouté !"), backgroundColor: Colors.green));
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
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Création du menu TheMealDB et calcul des calories en cours...")),
          ],
        ),
      ),
    );

    try {
      // 1. Récupérer Entrée, Plat, Dessert aléatoires
      final cats = ['Starter', 'Chicken', 'Dessert'];
      List<Map<String, dynamic>> rawMeals = [];
      for (String c in cats) {
        final r1 = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/filter.php?c=$c'));
        final d1 = json.decode(r1.body);
        if (d1['meals'] != null) {
          final mList = d1['meals'] as List;
          final rMeal = mList[Random().nextInt(mList.length)];
          final r2 = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/lookup.php?i=${rMeal["idMeal"]}'));
          final d2 = json.decode(r2.body);
          rawMeals.add(d2['meals'][0]);
        }
      }

      // 2. Utiliser l'IA (NLP Parser) pour estimer les calories à partir des ingrédients et traduire
      String mealsJsonString = jsonEncode(rawMeals.map((m) => {
        "titre": m['strMeal'],
        "instructions": m['strInstructions'],
        "ingredients": List.generate(20, (i) => "${m['strMeasure${i+1}']} ${m['strIngredient${i+1}']}").map((e) => e.trim()).where((e) => e.length > 2).toList()
      }).toList());

      final prompt = '''
      Voici 3 recettes issues de TheMealDB (Entrée, Plat, Dessert).
      TÂCHE : Fais office de parser NLP. Traduis les titres et instructions en français.
      Ensuite, calcule les calories et macros (protéines, glucides, lipides) pour CHAQUE recette en te basant sur sa liste d'ingrédients.
      Adapte la complexité de la recette selon cette difficulté demandée par l'utilisateur : $_recipeDifficulty (Simple = garde que l'essentiel, Difficile = instructions très détaillées).
      
      Recettes brutes : $mealsJsonString
      
      Retourne un JSON strict :
      {
        "meals": [
          {
            "mealType": "dinner", // assigner intelligemment (starter=lunch/dinner, etc.)
            "mealName": "Titre français",
            "description": "Brève description",
            "recipe_instructions": "Instructions traduites et adaptées à la difficulté",
            "estimatedCalories": int,
            "estimatedProteins": double,
            "estimatedCarbs": double,
            "estimatedFats": double
          }
        ],
        "shopping_list": ["liste", "des", "ingrédients", "traduits"]
      }
      ''';

      final result = await SL.aiService.fetchJSONResponse(prompt: prompt, temperature: 0.5);
      if (mounted) Navigator.pop(context);

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();
        
        final mealsList = result['meals'] as List;
        for (int i = 0; i < mealsList.length; i++) {
          var m = mealsList[i];
          widget.addMealPlanEntry(MealPlanEntry(
            date: _selectedDay ?? DateTime.now(),
            mealType: MealType.dinner, // On groupe tout dans un repas principal pour simplifier
            mealName: m['mealName'],
            description: m['description'],
            recipeInstructions: m['recipe_instructions'],
            imageUrl: rawMeals[i]['strMealThumb'], // On garde la vraie image
            estimatedCalories: m['estimatedCalories'] ?? 0,
            estimatedProteins: (m['estimatedProteins'] as num?)?.toDouble() ?? 0.0,
            estimatedCarbs: (m['estimatedCarbs'] as num?)?.toDouble() ?? 0.0,
            estimatedFats: (m['estimatedFats'] as num?)?.toDouble() ?? 0.0,
          ));
        }

        if (result['shopping_list'] != null) {
          await _saveShoppingList(List<String>.from(result['shopping_list']));
          if (mounted) _showShoppingListDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
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
      builder: (ctx) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Expanded(child: Text("Génération IA et recherche d'images en cours..."))]),
      ),
    );

    String shoppingListInstruction = _generateShoppingList
        ? "Ajoute une clé 'shopping_list' contenant la liste de courses globale en français."
        : "";

    final String prompt = '''
    Nutritionniste expert. Gère un plan de repas pour ${isWeekly ? "7 jours" : "1 jour"}.
    PROFIL: ${widget.userProfile.age} ans, ${widget.userProfile.gender}, Objectif: ${widget.currentGoals.weightGoalType}. Cal: ${widget.currentGoals.targetCalories} kcal/j.
    DIFFICULTÉ: $_recipeDifficulty. PRÉFÉRENCES: "${_promptController.text}". FRIGO: "${_fridgeContent ?? 'Non fourni'}".
    
    Pour Dîner/Déjeuner, propose un repas complet (Entrée, Plat, Dessert).
    INCLUS OBLIGATOIREMENT "recipe_instructions" (les étapes de préparation détaillées) pour chaque plat.
    
    Format JSON strict:
    "meals": [{"mealType": "breakfast|lunch|dinner|snack", "mealName": "...", "description": "...", "recipe_instructions": "...", "estimatedCalories": 0, "estimatedProteins": 0.0, "estimatedCarbs": 0.0, "estimatedFats": 0.0}]
    $shoppingListInstruction
    ''';

    try {
      final result = await SL.aiService.fetchJSONResponse(prompt: prompt, temperature: 0.7);
      if (mounted) Navigator.pop(context);

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();
        final List<dynamic> mealsRaw = result['meals'] ?? [];
        DateTime startDate = _selectedDay!;

        for (int i = 0; i < mealsRaw.length; i++) {
          var m = mealsRaw[i];
          DateTime mealDate = isWeekly ? startDate.add(Duration(days: (i / 4).floor())) : startDate;
          
          // Recherche d'image Bing automatique
          String? scrapedImageUrl = await _fetchImageUrl(m['mealName']);

          widget.addMealPlanEntry(MealPlanEntry(
            date: mealDate,
            mealType: MealType.values.firstWhere((e) => e.name == m['mealType'], orElse: () => MealType.unknown),
            mealName: m['mealName'],
            description: m['description'],
            recipeInstructions: m['recipe_instructions'],
            imageUrl: scrapedImageUrl,
            estimatedCalories: m['estimatedCalories'] ?? 0,
            estimatedProteins: (m['estimatedProteins'] as num?)?.toDouble() ?? 0.0,
            estimatedCarbs: (m['estimatedCarbs'] as num?)?.toDouble() ?? 0.0,
            estimatedFats: (m['estimatedFats'] as num?)?.toDouble() ?? 0.0,
          ));
        }

        if (_generateShoppingList && result['shopping_list'] != null) {
          await _saveShoppingList(List<String>.from(result['shopping_list']));
          if (mounted) _showShoppingListDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur IA: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _fridgeContent = null);
    }
  }

  void _showShoppingListDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ma Liste de Courses'),
        content: SizedBox(
          width: double.maxFinite,
          child: _savedShoppingList.isEmpty
              ? const Text("Votre liste est vide.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _savedShoppingList.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.check_box_outline_blank),
                    title: Text(_savedShoppingList[index]),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
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
                child: Image.network(meal.imageUrl!, height: 250, fit: BoxFit.cover, errorBuilder: (c,e,s) => const SizedBox()),
              ),
            const SizedBox(height: 16),
            Text(meal.mealName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroBadge("${meal.estimatedCalories} kcal", Colors.orange),
                _buildMacroBadge("${meal.estimatedProteins}g Pro", Colors.blue),
                _buildMacroBadge("${meal.estimatedCarbs}g Glu", Colors.green),
                _buildMacroBadge("${meal.estimatedFats}g Lip", Colors.purple),
              ],
            ),
            const Divider(height: 32, thickness: 1),
            Text("Préparation", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealsForSelectedDay = _selectedDay != null ? widget.mealPlans.where((plan) => isSameDay(plan.date, _selectedDay)).toList() : [];

    // Groupement par type de repas
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
      appBar: AppBar(title: const Text('Menus & Recettes'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_savedShoppingList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton.icon(
                onPressed: _showShoppingListDialog,
                icon: const Icon(Icons.shopping_basket),
                label: const Text("Voir ma dernière liste de courses"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade100, foregroundColor: Colors.teal.shade900),
              ),
            ),
          
          // Suggestions TheMealDB Complètes
          Text("Suggestion du Jour (TheMealDB)", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: _isLoadingApi 
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
                              Navigator.push(context, MaterialPageRoute(builder: (ctx) => RecipeDetailPage(mealData: meal, onAdd: () => _addApiMealToCalendar(meal))));
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Image.network(meal['strMealThumb'], width: double.infinity, fit: BoxFit.cover)),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(meal['strMeal'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(index == 0 ? "Entrée" : index == 1 ? "Plat" : "Dessert", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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

          // Générateur IA
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
                    items: ["Simple", "Normal", "Difficile"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _recipeDifficulty = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(labelText: 'Préférences (ex: pas de viande)'),
                  ),
                  if (widget.isPremiumUser)
                    CheckboxListTile(
                      title: const Text("Créer une liste de courses"),
                      value: _generateShoppingList,
                      onChanged: (v) => setState(() => _generateShoppingList = v ?? false),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _generateMenuWithIA(isWeekly: false),
                          icon: const Icon(Icons.restaurant),
                          label: Text(widget.isPremiumUser ? "Menu du Jour" : "Menu TheMealDB (Gratuit)"),
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
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildCalendar(),
          const SizedBox(height: 24),
          
          Text('Plan pour le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDay!)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          if (mealsForSelectedDay.isEmpty)
            const Center(child: Text("Aucun repas planifié pour ce jour.", style: TextStyle(color: Colors.grey)))
          else ...[
            _buildMealSection("Petit-déjeuner", groupedMeals[MealType.breakfast]!),
            _buildMealSection("Déjeuner", groupedMeals[MealType.lunch]!),
            _buildMealSection("Collation", groupedMeals[MealType.snack]!),
            _buildMealSection("Dîner", groupedMeals[MealType.dinner]!),
          ]
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
          child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
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
          onDaySelected: (selectedDay, focusedDay) => setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }),
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
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(meal.imageUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.fastfood)))
            : const Icon(Icons.restaurant),
        title: Text(meal.mealName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${meal.estimatedCalories} kcal'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.description, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Text('Macros: ${meal.estimatedProteins.toStringAsFixed(0)}P / ${meal.estimatedCarbs.toStringAsFixed(0)}G / ${meal.estimatedFats.toStringAsFixed(0)}L', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (meal.recipeInstructions != null && meal.recipeInstructions!.isNotEmpty)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.menu_book),
                        label: const Text('Voir la recette'),
                        onPressed: () => _showRecipeDialog(meal),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100, foregroundColor: Colors.orange.shade900),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          tooltip: "Ajouter au suivi",
                          onPressed: () {
                            widget.addFoodEntryToTracker(meal.toFoodEntry());
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${meal.mealName} ajouté !")));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => widget.deleteMealPlanEntry(meal.id),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
}\n\n"""

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content[:start_idx] + new_content + content[end_idx:])

print("Updated file.")
