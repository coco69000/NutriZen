import 'package:uuid/uuid.dart';
// onboarding_flow_screen.dart

import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Assurez-vous que les imports vers les services et modèles sont corrects

// ... (La classe ProfileCreationLoadingScreen reste inchangée)
class ProfileCreationLoadingScreen extends StatefulWidget {
  final String userId;
  const ProfileCreationLoadingScreen({super.key, required this.userId});

  @override
  State<ProfileCreationLoadingScreen> createState() => _ProfileCreationLoadingScreenState();
}

class _ProfileCreationLoadingScreenState extends State<ProfileCreationLoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MyAppTabsWrapper(userId: widget.userId)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              "Création de votre profil personnalisé...",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Nous préparons tout pour vous.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  _OnboardingFlowScreenState createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _pageController = PageController();
  final List<GlobalKey<FormState>> _formKeys = List.generate(6, (_) => GlobalKey<FormState>());

  int _currentPage = 0;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _bodyFatController = TextEditingController();

  final Map<String, dynamic> _onboardingData = {
    'weightGoalType': 'maintain',
    'activityLevel': 'moderate',
    'gender': 'male',
    'physicalCondition': 'mince',
    'fastingExperience': 'beginner',
    'dietaryPreferences': <String>[],
    'healthConditions': <String>[],
    'age': 0,
    'weight': 0.0,
    'height': 0.0,
    'sleepHours': 7,
    'stressLevel': 'moderate',
    'mainMotivation': 'health',
    'dietQuality': 'moyenne',
    'waterIntake': 'moyen',
    // NOUVEAU: Ajout des clés avec valeurs par défaut
    'availableEquipment': <String>[],
    'gymMode': false,
    'likesCooking': 'likes',
    'cookingFrequency': 'few_times_week',
    'likedSports': '',
    'dislikedSports': '',
    'bodyFatPercentage': null,
  };

  double? _calculateBmi() {
    final height = _onboardingData['height'];
    final weight = _onboardingData['weight'];
    if (height != null && height > 0 && weight != null && weight > 0) {
      return weight / ((height / 100) * (height / 100));
    }
    return null;
  }

  // MODIFIÉ: Logique de recommandation d'objectif revue pour intégrer l'alerte
  Map<String, dynamic> _getGoalRecommendation(double? bmi, String physicalCondition, String activityLevel) {
    if (bmi == null) {
      return {
        'recommendedGoal': null,
        'bmiMessage': RichText(text: const TextSpan(text: "Calculez votre IMC pour une recommandation.", style: TextStyle(color: Colors.black, fontSize: 16))),
        'recommendationMessage': "Veuillez remplir vos informations pour obtenir une recommandation personnalisée.",
        'recommendationColor': Colors.grey.shade200,
        'maintainLabel': "Maintenir mon poids",
      };
    }

    final String bmiCategory = _getBmiCategory(bmi);
    final bool isAthletic = (physicalCondition == 'muscle' || physicalCondition == 'legerement_muscle') &&
        (activityLevel == 'active' || activityLevel == 'very_active');

    // Cas 1 : Surpoids ou Obésité
    if (bmi >= 25) {
      if (isAthletic) {
        return {
          'recommendedGoal': null, // Aucune recommandation forte
          'bmiMessage': RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 16, color: Colors.blue.shade800),
              children: [
                TextSpan(text: "Votre IMC est de ${bmi.toStringAsFixed(1)} ($bmiCategory). "),
                const TextSpan(
                  text: "Cependant, votre profil sportif indique que ce n'est probablement pas un indicateur fiable.",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          'recommendationMessage': "En tant que sportif/ve, choisissez l'objectif qui correspond à votre phase actuelle (prise de masse, maintien, sèche).",
          'recommendationColor': Colors.green.shade100,
          'maintainLabel': "Maintenir mes muscles", // Label personnalisé
        };
      } else {
        // Personne en surpoids non-athlétique -> On force la perte de poids
        _onboardingData['weightGoalType'] = 'lose';
        return {
          'recommendedGoal': 'lose',
          'bmiMessage': RichText(
              textAlign: TextAlign.center,
              text: TextSpan(style: TextStyle(fontSize: 16, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                  children: [
                    const WidgetSpan(child: Icon(Icons.warning, color: Colors.red, size: 20)),
                    TextSpan(text: " ALERTE SANTÉ : Votre IMC est de ${bmi.toStringAsFixed(1)} ($bmiCategory).")
                  ]
              )),
          'recommendationMessage': "Pour votre santé, maintenir ce poids n'est pas une option. Il est impératif de viser une perte de poids. Nous avons pré-sélectionné cet objectif pour vous.",
          'recommendationColor': Colors.red.shade100,
          'maintainLabel': "Maintenir mon poids",
        };
      }
    }
    // Cas 2 : Poids normal
    else if (bmi >= 18.5) {
      return {
        'recommendedGoal': null,
        'bmiMessage': RichText(text: TextSpan(style: TextStyle(fontSize: 16, color: Colors.green.shade800), text:"Votre IMC est de ${bmi.toStringAsFixed(1)} ($bmiCategory).")),
        'recommendationMessage': "Votre poids est dans la norme. Choisissez l'objectif qui correspond le mieux à vos attentes.",
        'recommendationColor': Colors.green.shade100,
        'maintainLabel': isAthletic ? "Maintenir mes muscles" : "Maintenir mon poids",
      };
    }
    // Cas 3 : Maigreur -> On force la prise de poids/muscle
    else {
      _onboardingData['weightGoalType'] = 'gain';
      return {
        'recommendedGoal': 'gain',
        'bmiMessage': RichText(
            textAlign: TextAlign.center,
            text: TextSpan(style: TextStyle(fontSize: 16, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                children: [
                  const WidgetSpan(child: Icon(Icons.warning, color: Colors.red, size: 20)),
                  TextSpan(text: " ALERTE SANTÉ : Votre IMC est de ${bmi.toStringAsFixed(1)} ($bmiCategory).")
                ]
            )),
        'recommendationMessage': "Votre poids est inférieur à la norme de santé. Nous vous recommandons fortement de viser une prise de masse saine.",
        'recommendationColor': Colors.red.shade100,
        'maintainLabel': "Maintenir mon poids",
      };
    }
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return "Maigreur";
    if (bmi < 25) return "Poids normal";
    if (bmi < 30) return "Surpoids";
    return "Obésité";
  }

  void _showUSNavyCalculator() {
    final TextEditingController waistController = TextEditingController();
    final TextEditingController neckController = TextEditingController();
    final TextEditingController hipController = TextEditingController();
    final isFemale = _onboardingData['gender'] == 'female';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Calcul avec la méthode US Navy"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Saisissez vos mensurations en cm :"),
                const SizedBox(height: 16),
                TextField(
                  controller: neckController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Tour de cou (cm)"),
                ),
                TextField(
                  controller: waistController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Tour de taille (cm) - au nombril"),
                ),
                if (isFemale)
                  TextField(
                    controller: hipController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Tour de hanches (cm) - au plus large"),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                final waist = double.tryParse(waistController.text);
                final neck = double.tryParse(neckController.text);
                final hip = isFemale ? double.tryParse(hipController.text) : 0.0;
                final height = _onboardingData['height'] as double?;

                if (waist != null && neck != null && height != null && height > 0 && (!isFemale || hip != null)) {
                  double bf = 0.0;
                  double log10(double x) => math.log(x) / math.ln10;

                  if (isFemale) {
                    bf = 495 / (1.29579 - 0.35004 * log10(waist + hip! - neck) + 0.22100 * log10(height)) - 450;
                  } else {
                    bf = 495 / (1.0324 - 0.19077 * log10(waist - neck) + 0.15456 * log10(height)) - 450;
                  }

                  if (bf > 0 && bf < 70) {
                    setState(() {
                      _bodyFatController.text = bf.toStringAsFixed(1);
                    });
                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Les mesures semblent incorrectes, calcul impossible.")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Veuillez remplir correctement (avec votre taille étape précédente).")),
                  );
                }
              },
              child: const Text("Calculer"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
  }

  List<Widget> _buildPages(BuildContext context) {
    final double? bmi = _calculateBmi();
    final recommendation = _getGoalRecommendation(
        bmi,
        _onboardingData['physicalCondition'],
        _onboardingData['activityLevel']
    );

    final String? recommendedGoal = recommendation['recommendedGoal'];
    final RichText bmiMessage = recommendation['bmiMessage'];
    final String recommendationMessage = recommendation['recommendationMessage'];
    final Color recommendationColor = recommendation['recommendationColor'];
    final String maintainLabel = recommendation['maintainLabel'];

    final List<Widget> pages = [
      _buildQuestionPage(context: context, title: "Parlons de vous...", child: _buildChoiceSelector(key: 'gender', options: { 'Homme': 'male', 'Femme': 'female', 'Autre': 'other' })),
      _buildTextFieldPage(formKey: _formKeys[0], title: "Quel âge avez-vous ?", child: TextFormField(controller: _ageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Âge', border: OutlineInputBorder()), validator: (v) => v!.isEmpty || int.tryParse(v) == null || int.parse(v) < 13 ? 'Âge invalide' : null, onSaved: (v) => _onboardingData['age'] = int.parse(v!))),
      _buildTextFieldPage(formKey: _formKeys[1], title: "Votre poids actuel ?", child: TextFormField(controller: _weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Poids (kg)', border: OutlineInputBorder()), validator: (v) => v!.isEmpty || double.tryParse(v) == null || double.parse(v) < 30 ? 'Poids invalide' : null, onSaved: (v) => _onboardingData['weight'] = double.parse(v!))),
      _buildTextFieldPage(formKey: _formKeys[2], title: "Votre taille ?", child: TextFormField(controller: _heightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Taille (cm)', border: OutlineInputBorder()), validator: (v) => v!.isEmpty || double.tryParse(v) == null || double.parse(v) < 100 ? 'Taille invalide' : null, onSaved: (v) => _onboardingData['height'] = double.parse(v!))),
      _buildTextFieldPage(
        formKey: _formKeys[4], 
        title: "Quel est votre pourcentage de masse grasse ? (Optionnel)", 
        child: Column(
          children: [
            TextFormField(
              controller: _bodyFatController, 
              keyboardType: const TextInputType.numberWithOptions(decimal: true), 
              decoration: const InputDecoration(
                labelText: 'Masse grasse (%)', 
                border: OutlineInputBorder(),
                hintText: 'Ex: 15.5',
              ), 
              validator: (v) {
                if (v == null || v.isEmpty) return null; // Optionnel
                final val = double.tryParse(v);
                if (val == null || val < 1 || val > 70) return 'Pourcentage invalide (1 - 70)';
                return null;
              }, 
              onSaved: (v) {
                if (v != null && v.isNotEmpty) {
                  _onboardingData['bodyFatPercentage'] = double.tryParse(v);
                } else {
                  _onboardingData['bodyFatPercentage'] = null;
                }
              }
            ),
            const SizedBox(height: 16),
            const Text(
              "Vous pouvez l'estimer avec la méthode de l'US Navy (tour de taille, cou, hanches) ou le laisser vide si vous ne le connaissez pas.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showUSNavyCalculator,
              icon: const Icon(Icons.calculate),
              label: const Text("Estimer via méthode US Navy"),
            )
          ]
        )
      ),
      _buildQuestionPage(context: context, title: "Quel est votre niveau d'activité ?", child: _buildChoiceSelector(key: 'activityLevel', options: { 'Sédentaire': 'sedentary', 'Léger': 'light', 'Modéré': 'moderate', 'Actif': 'active', 'Très actif': 'very_active' })),
      _buildQuestionPage(context: context, title: "Quelle est votre condition physique ?", child: _buildChoiceSelector(key: 'physicalCondition', options: { 'Mince': 'mince', 'Légèrement musclé(e)': 'legerement_muscle', 'Musclé(e)': 'muscle', 'En surpoids': 'en_surpoids', 'Obèse': 'obese' })),

      _buildQuestionPage(
        context: context,
        title: "Quel est votre objectif principal ?",
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
              ),
              child: bmiMessage,
            ),
            Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: recommendationColor, borderRadius: BorderRadius.circular(12)), child: Text(recommendationMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
            _buildChoiceSelector(
                key: 'weightGoalType',
                options: {
                  'Perdre du poids': 'lose',
                  'Prendre du muscle': 'gain',
                  maintainLabel: 'maintain',
                },
                disabledOptions: recommendedGoal == null ? {} : {'lose', 'gain', 'maintain'}.difference({recommendedGoal}),
                onChanged: (value) => setState(() {})
            ),
          ],
        ),
      ),

      if (_onboardingData['weightGoalType'] == 'lose' || _onboardingData['weightGoalType'] == 'gain')
        _buildTextFieldPage(
          formKey: _formKeys[3],
          title: _onboardingData['weightGoalType'] == 'lose' ? "Quel est votre poids cible ?" : "Quel poids visez-vous (muscle inclus) ?",
          child: TextFormField(
            controller: _targetWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Poids cible (kg)', border: OutlineInputBorder()),
            validator: (v) {
              if (v == null || v.isEmpty || double.tryParse(v) == null) return 'Poids invalide';
              final targetWeight = double.parse(v);
              final currentWeight = _onboardingData['weight'] as double;
              if (_onboardingData['weightGoalType'] == 'lose' && targetWeight >= currentWeight) {
                return 'Le poids cible doit être inférieur au poids actuel.';
              }
              if (_onboardingData['weightGoalType'] == 'gain' && targetWeight <= currentWeight) {
                return 'Le poids cible doit être supérieur au poids actuel.';
              }
              return null;
            },
            onSaved: (v) => _onboardingData['targetWeight'] = double.parse(v!),
          ),
        ),

      // ================== QUESTIONS MODIFIÉES ET AJOUTÉES ==================
      _buildQuestionPage(context: context, title: "Qualité de votre alimentation ?", child: _buildChoiceSelector(key: 'dietQuality', options: {'Plutôt saine': 'saine', 'Assez variable': 'moyenne', 'Peu équilibrée': 'peu_saine'})),
      _buildQuestionPage(context: context, title: "Combien d'eau buvez-vous par jour ?", child: _buildChoiceSelector(key: 'waterIntake', options: {'Moins de 1L': 'peu', 'Entre 1L et 2L': 'moyen', 'Plus de 2L': 'beaucoup'})),
      _buildQuestionPage(context: context, title: "Combien d'heures dormez-vous par nuit ?", child: _buildChoiceSelector(key: 'sleepHours', options: { 'Moins de 5h': 4, '5-6 heures': 5, '7-8 heures': 7, 'Plus de 8h': 9 })),
      _buildQuestionPage(context: context, title: "Votre niveau de stress général ?", child: _buildChoiceSelector(key: 'stressLevel', options: { 'Faible': 'low', 'Modéré': 'moderate', 'Élevé': 'high' })),
      _buildQuestionPage(context: context, title: "Votre motivation principale ?", child: _buildChoiceSelector(key: 'mainMotivation', options: { 'Améliorer ma santé': 'health', 'Améliorer mon apparence': 'aesthetics', 'Augmenter mes performances': 'performance' })),
      // =========================================================================
      _buildQuestionPage(
        context: context,
        title: "Aimez-vous cuisiner ?",
        child: _buildChoiceSelector(
          key: 'likesCooking',
          options: {
            "J'adore ça !": 'loves',
            "Ça va, de temps en temps": 'likes',
            "Pas vraiment, je préfère la simplicité": 'dislikes',
          },
        ),
      ),
      _buildQuestionPage(
        context: context,
        title: "À quelle fréquence cuisinez-vous ?",
        child: _buildChoiceSelector(
          key: 'cookingFrequency',
          options: {
            "Tous les jours": 'daily',
            "Quelques fois par semaine": 'few_times_week',
            "Le week-end uniquement": 'weekends_only',
            "Très rarement": 'rarely',
          },
        ),
      ),
      _buildQuestionPage(
        context: context,
        title: "Lieu d'entraînement principal ?",
        child: _buildChoiceSelector(
          key: 'gymMode',
          options: { 'À la salle de sport (Machines)': true, 'À la maison / Dehors': false },
        ),
      ),
      if (_onboardingData['gymMode'] == false)
        _buildMultiSelectChipPage(
          context: context,
          title: "Quel matériel avez-vous à la maison ?",
          options: ['Haltères', 'Bande de résistance', 'Barre de traction', 'Kettlebell', 'Tapis de sol', 'Banc'],
          selected: List<String>.from(_onboardingData['availableEquipment'] ?? <String>[]),
          onSelectionChanged: (selected) => setState(() => _onboardingData['availableEquipment'] = selected),
        ),
      _buildTextFieldPage(
        formKey: _formKeys[5],
        title: "Vos préférences sportives",
        child: Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Sports que vous aimez (ex: Vélo, Musculation)',
                border: OutlineInputBorder(),
              ),
              onSaved: (v) => _onboardingData['likedSports'] = v?.trim() ?? '',
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Sports que vous détestez (ex: Course à pied)',
                border: OutlineInputBorder(),
              ),
              onSaved: (v) => _onboardingData['dislikedSports'] = v?.trim() ?? '',
            ),
          ],
        ),
      ),
      _buildQuestionPage(context: context, title: "Votre expérience avec le jeûne ?", child: _buildChoiceSelector(key: 'fastingExperience', options: { 'Débutant(e)': 'beginner', 'Intermédiaire': 'intermediate', 'Expérimenté(e)': 'expert' })),
      _buildMultiSelectChipPage(context: context, title: "Avez-vous des préférences alimentaires ?", options: ['Végétarien', 'Végétalien', 'Sans Gluten', 'Sans Lactose', 'Halal', 'Casher'], selected: _onboardingData['dietaryPreferences'], onSelectionChanged: (selected) => setState(() => _onboardingData['dietaryPreferences'] = selected)),
      _buildMultiSelectChipPage(context: context, title: "Avez-vous des conditions de santé à noter ?", encouragement: "Vous avez presque fini !", options: ['Diabète', 'Hypertension', 'Maladie Cœliaque', 'Allergies'], selected: _onboardingData['healthConditions'], onSelectionChanged: (selected) => setState(() => _onboardingData['healthConditions'] = selected)),
    ];
    return pages;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  void _nextPage(List<Widget> pages) {
    FocusScope.of(context).unfocus();

    final currentPageWidget = pages[_currentPage];
    if (currentPageWidget is _TextFieldPage) {
      final formKey = currentPageWidget.formKey;
      if (formKey.currentState != null && !formKey.currentState!.validate()) {
        return;
      }
      formKey.currentState?.save();
    }

    setState(() {});

    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => OnboardingAuthScreen(onboardingData: _onboardingData)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = _buildPages(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                tween: Tween<double>(begin: 0, end: (_currentPage + 1) / pages.length),
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    minHeight: 10,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _nextPage(pages),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: Text(_currentPage < pages.length - 1 ? 'Suivant' : 'Terminer et créer mon compte'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AuthScreen())),
                    child: const Text("J'ai déjà un compte, me connecter"),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage({required BuildContext context, required String title, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }

  Widget _buildMultiSelectChipPage({
    required BuildContext context,
    required String title,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onSelectionChanged,
    String? encouragement,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (bool value) {
                  List<String> newSelected = List.from(selected);
                  if (value) {
                    newSelected.add(option);
                  } else {
                    newSelected.remove(option);
                  }
                  onSelectionChanged(newSelected);
                },
                backgroundColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.grey.shade200,
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.8),
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          if (encouragement != null)
            Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Text(encouragement, style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _buildChoiceSelector({
    required String key,
    required Map<String, dynamic> options, // Accepte dynamic pour les heures de sommeil
    Set<String> disabledOptions = const {},
    ValueChanged<dynamic>? onChanged,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark; // VÉRIFICATION THEME

    return Column(
      children: options.entries.map((entry) {
        final bool isSelected = _onboardingData[key] == entry.value;
        // La valeur peut être un String ou un int, donc on la convertit en String pour la comparaison
        final bool isDisabled = disabledOptions.contains(entry.value.toString());

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: GestureDetector(
            onTap: isDisabled ? null : () {
              FocusScope.of(context).unfocus(); // Ferme aussi le clavier au clic
              setState(() => _onboardingData[key] = entry.value);
              onChanged?.call(entry.value);
              // Optionnel : auto-next si ce n'est pas la page des objectifs qui demande de rester sur la page
              if (onChanged == null) {
                Future.delayed(const Duration(milliseconds: 300), () => _nextPage(_buildPages(context)));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).primaryColor.withOpacity(0.15) 
                    : (isDisabled ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200) : (isDark ? Colors.grey.shade900 : Colors.white)),
                border: Border.all(
                  color: isSelected ? Theme.of(context).primaryColor : (isDisabled ? Colors.grey.shade300 : Colors.grey.shade300),
                  width: isSelected ? 2.5 : 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected 
                        ? (isDark ? Colors.tealAccent : Theme.of(context).primaryColor) 
                        : (isDisabled ? Colors.grey.shade500 : (isDark ? Colors.white : Colors.black87)),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TextFieldPage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String title;
  final Widget child;
  final String? encouragement;

  const _TextFieldPage({
    required this.formKey,
    required this.title,
    required this.child,
    this.encouragement,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 40),
                child,
                if (encouragement != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Text(encouragement!, style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildTextFieldPage({
  required GlobalKey<FormState> formKey,
  required String title,
  required Widget child,
  String? encouragement,
}) {
  return _TextFieldPage(
    formKey: formKey,
    title: title,
    child: child,
    encouragement: encouragement,
  );
}


class OnboardingAuthScreen extends StatefulWidget {
  final Map<String, dynamic> onboardingData;
  const OnboardingAuthScreen({super.key, required this.onboardingData});

  @override
  _OnboardingAuthScreenState createState() => _OnboardingAuthScreenState();
}

class _OnboardingAuthScreenState extends State<OnboardingAuthScreen> {
  final uuid = const Uuid();
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _firstName = '';
  String _lastName = '';
  String _errorMessage = '';
  bool _isLoading = false;

  // ================== NOUVELLE FONCTION ==================
  /// Calcule le niveau de rigueur initial du plan sur une échelle de 1 à 5.
  int _calculateInitialPlanStrictness(Map<String, dynamic> data) {
    int score = 3; // Base: modéré

    // Influence de la qualité de l'alimentation
    if (data['dietQuality'] == 'saine') score++;
    if (data['dietQuality'] == 'peu_saine') score--;

    // Influence de la condition physique
    final condition = data['physicalCondition'];
    if (condition == 'obese' || condition == 'en_surpoids') {
      score--; // Démarrage plus doux pour les personnes en surpoids
    }
    if (condition == 'muscle' || condition == 'legerement_muscle') {
      score++; // Peut supporter un plan plus strict
    }

    // Influence du sommeil
    if (data['sleepHours'] < 6) score--; // Moins de sommeil = plan plus doux pour compenser

    return score.clamp(1, 5); // Assure que le score reste entre 1 et 5
  }
  // =========================================================

  void _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final UserCredential? userCredential = await _auth.registerWithEmailAndPassword(_email, _password);

      if (userCredential != null) {
        final userId = userCredential.user!.uid;
        final firestoreService = FirestoreService(userId: userId);

        final int initialStrictness = _calculateInitialPlanStrictness(widget.onboardingData);

        // 1. Crée la première entrée d'historique d'objectif
        final initialGoalEntry = GoalHistoryEntry(
          goalType: widget.onboardingData['weightGoalType'],
          startWeight: widget.onboardingData['weight'],
          targetWeight: widget.onboardingData['targetWeight'] ?? widget.onboardingData['weight'],
          startDate: DateTime.now(),
          status: GoalStatus.inProgress,
        );

        // MODIFIÉ: Ajout des nouvelles données au constructeur de UserProfile
        final UserProfile finalProfile = UserProfile(
          firstName: _firstName,
          lastName: _lastName,
          email: _email,
          age: widget.onboardingData['age'],
          weight: widget.onboardingData['weight'],
          height: widget.onboardingData['height'],
          gender: widget.onboardingData['gender'],
          activityLevel: widget.onboardingData['activityLevel'],
          physicalCondition: widget.onboardingData['physicalCondition'],
          fastingExperience: widget.onboardingData['fastingExperience'],
          dietaryPreferences: List<String>.from(widget.onboardingData['dietaryPreferences']),
          healthConditions: List<String>.from(widget.onboardingData['healthConditions']),
          sleepHours: widget.onboardingData['sleepHours'],
          stressLevel: widget.onboardingData['stressLevel'],
          mainMotivation: widget.onboardingData['mainMotivation'],
          dietQuality: widget.onboardingData['dietQuality'],
          planStrictness: initialStrictness,
          likesCooking: widget.onboardingData['likesCooking'],
          cookingFrequency: widget.onboardingData['cookingFrequency'],
          likedSports: widget.onboardingData['likedSports'] ?? '',
          dislikedSports: widget.onboardingData['dislikedSports'] ?? '',
          bodyFatPercentage: widget.onboardingData['bodyFatPercentage'],
          goalHistory: [initialGoalEntry],
        );

        double bmr = (finalProfile.gender == 'male')
            ? (10 * finalProfile.weight) + (6.25 * finalProfile.height) - (5 * finalProfile.age) + 5
            : (10 * finalProfile.weight) + (6.25 * finalProfile.height) - (5 * finalProfile.age) - 161;

        double activityMultiplier;
        switch (finalProfile.activityLevel) {
          case 'sedentary': activityMultiplier = 1.2; break;
          case 'light': activityMultiplier = 1.375; break;
          case 'active': activityMultiplier = 1.725; break;
          case 'very_active': activityMultiplier = 1.9; break;
          default: activityMultiplier = 1.55;
        }
        final tdee = bmr * activityMultiplier;

        double targetCalories;
        switch (widget.onboardingData['weightGoalType']) {
          case 'gain': targetCalories = tdee + 300; break;
          case 'lose': targetCalories = tdee - 500; break;
          default: targetCalories = tdee;
        }

        double? targetMuscleGain;
        if (widget.onboardingData['weightGoalType'] == 'gain' && widget.onboardingData['targetWeight'] != null) {
          targetMuscleGain = (widget.onboardingData['targetWeight'] as double) - finalProfile.weight;
        }

        // Définir l'objectif d'eau en fonction de la réponse
        double targetWater;
        switch (widget.onboardingData['waterIntake']) {
          case 'peu': targetWater = 1.8; break;
          case 'beaucoup': targetWater = 2.5; break;
          default: targetWater = 2.2;
        }

        final DailyGoal finalGoals = DailyGoal(
          weightGoalType: widget.onboardingData['weightGoalType'],
          targetWeight: widget.onboardingData['targetWeight'] ?? finalProfile.weight,
          targetCalories: targetCalories.round(),
          targetProteins: finalProfile.weight * (widget.onboardingData['weightGoalType'] == 'gain' ? 2.0 : 1.8),
          targetFats: finalProfile.weight * 0.9,
          targetCarbs: (targetCalories - (finalProfile.weight * (widget.onboardingData['weightGoalType'] == 'gain' ? 2.0 : 1.8) * 4) - (finalProfile.weight * 0.9 * 9)) / 4,
          targetMuscleGain: targetMuscleGain,
          targetWater: targetWater, // On sauvegarde l'objectif d'eau
        );
        // =================================================================

        await firestoreService.updateUserProfile(finalProfile);
        await firestoreService.updateDailyGoals(finalGoals);
        await firestoreService.setOnboardingComplete();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboardingCompleted', true);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ProfileCreationLoadingScreen(userId: userId)),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Une erreur est survenue.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Finalisez votre inscription")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text("Créez votre compte pour sauvegarder vos objectifs", style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    TextFormField(decoration: const InputDecoration(labelText: 'Prénom'), validator: (v) => v!.isEmpty ? 'Veuillez entrer un prénom.' : null, onSaved: (v) => _firstName = v!),
                    const SizedBox(height: 16),
                    TextFormField(decoration: const InputDecoration(labelText: 'Nom'), validator: (v) => v!.isEmpty ? 'Veuillez entrer un nom.' : null, onSaved: (v) => _lastName = v!),
                    const SizedBox(height: 16),
                    TextFormField(keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Adresse E-mail'), validator: (v) => v!.isEmpty || !v.contains('@') ? 'Email invalide.' : null, onSaved: (v) => _email = v!),
                    const SizedBox(height: 16),
                    TextFormField(obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe'), validator: (v) => v!.length < 6 ? 'Le mot de passe doit faire au moins 6 caractères.' : null, onSaved: (v) => _password = v!),
                    const SizedBox(height: 20),
                    if (_errorMessage.isNotEmpty) Text(_errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 10),
                    _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _submitAuthForm, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('Accéder à l\'application')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}