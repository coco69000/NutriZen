import 'package:flutter/material.dart';

enum BadgeCategory { all, nutrition, fasting, activity, ecoScan, streak, social }

class BadgeItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final BadgeCategory category;
  final int maxProgress;
  int currentProgress;
  bool isUnlocked;
  DateTime? unlockedAt;

  BadgeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    this.maxProgress = 1,
    this.currentProgress = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'currentProgress': currentProgress,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  factory BadgeItem.fromMap(BadgeItem template, Map<String, dynamic> map) {
    return BadgeItem(
      id: template.id,
      title: template.title,
      description: template.description,
      icon: template.icon,
      color: template.color,
      category: template.category,
      maxProgress: template.maxProgress,
      currentProgress: map['currentProgress'] ?? 0,
      isUnlocked: map['isUnlocked'] ?? false,
      unlockedAt: map['unlockedAt'] != null ? DateTime.parse(map['unlockedAt']) : null,
    );
  }
}

/// Catalogue exhaustif de tous les badges de NutriZen
class BadgeCatalog {
  static List<BadgeItem> get allBadges => [
    // --- NUTRITION ---
    BadgeItem(
      id: 'first_meal',
      title: 'Premier Pas Gourmand',
      description: 'Enregistrer votre tout premier repas dans le journal.',
      icon: Icons.restaurant,
      color: Colors.orange,
      category: BadgeCategory.nutrition,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'macro_master',
      title: 'Maître des Macros',
      description: 'Atteindre vos objectifs en protéines, glucides et lipides sur une journée.',
      icon: Icons.pie_chart,
      color: Colors.deepOrange,
      category: BadgeCategory.nutrition,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'water_master',
      title: 'Océan de Vitalité',
      description: 'Atteindre votre objectif d’hydratation 5 jours au total.',
      icon: Icons.water_drop,
      color: Colors.blue,
      category: BadgeCategory.nutrition,
      maxProgress: 5,
    ),
    BadgeItem(
      id: 'custom_recipe',
      title: 'Chef Cordon Bleu',
      description: 'Créer et enregistrer une recette personnalisée.',
      icon: Icons.menu_book,
      color: Colors.amber,
      category: BadgeCategory.nutrition,
      maxProgress: 1,
    ),

    // --- JEÛNE (FASTING) ---
    BadgeItem(
      id: 'first_fast',
      title: 'Initiation Circadienne',
      description: 'Compléter votre première session de jeûne avec succès.',
      icon: Icons.timer,
      color: Colors.green,
      category: BadgeCategory.fasting,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'warrior_fast',
      title: 'Guerrier Métabolique',
      description: 'Compléter un jeûne prolongé de plus de 20 heures.',
      icon: Icons.local_fire_department,
      color: Colors.redAccent,
      category: BadgeCategory.fasting,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'fasting_streak_5',
      title: 'Horloge Biologique',
      description: 'Réussir 5 sessions de jeûne prévues dans votre programme.',
      icon: Icons.auto_mode,
      color: Colors.teal,
      category: BadgeCategory.fasting,
      maxProgress: 5,
    ),

    // --- ACTIVITÉ & SPORT ---
    BadgeItem(
      id: 'first_workout',
      title: 'En Mouvement',
      description: 'Enregistrer votre première séance de sport ou activité.',
      icon: Icons.fitness_center,
      color: Colors.purple,
      category: BadgeCategory.activity,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'step_titan',
      title: 'Titans des Pas',
      description: 'Atteindre 10 000 pas en une seule journée.',
      icon: Icons.directions_walk,
      color: Colors.cyan,
      category: BadgeCategory.activity,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'calorie_burner_500',
      title: 'Fournaise Métabolique',
      description: 'Brûler plus de 500 kcal en une seule séance sportive.',
      icon: Icons.flash_on,
      color: Colors.amber.shade900,
      category: BadgeCategory.activity,
      maxProgress: 1,
    ),

    // --- SCANNER & ÉCO-SCORE ---
    BadgeItem(
      id: 'first_scan',
      title: 'Inspecteur Nutrition',
      description: 'Scanner un code-barres de produit alimentaire.',
      icon: Icons.qr_code_scanner,
      color: Colors.indigo,
      category: BadgeCategory.ecoScan,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'eco_hero_5',
      title: 'Éco-Héros',
      description: 'Scanner 5 produits notés Eco-Score A ou B.',
      icon: Icons.eco,
      color: Colors.green.shade700,
      category: BadgeCategory.ecoScan,
      maxProgress: 5,
    ),

    // --- RÉGULARITÉ & ÉVOLUTION ---
    BadgeItem(
      id: 'streak_3',
      title: 'Sur les Rails',
      description: 'Se connecter 3 jours consécutifs.',
      icon: Icons.bolt,
      color: Colors.orangeAccent,
      category: BadgeCategory.streak,
      maxProgress: 3,
    ),
    BadgeItem(
      id: 'streak_7',
      title: 'Habitude d’Acier',
      description: 'Maintenir une série de 7 jours consécutifs.',
      icon: Icons.shield,
      color: Colors.deepPurpleAccent,
      category: BadgeCategory.streak,
      maxProgress: 7,
    ),
    BadgeItem(
      id: 'streak_30',
      title: 'Légende NutriZen',
      description: 'Atteindre 30 jours de série ininterrompue !',
      icon: Icons.workspace_premium,
      color: Colors.amber.shade700,
      category: BadgeCategory.streak,
      maxProgress: 30,
    ),
    BadgeItem(
      id: 'goal_achieved',
      title: 'Objectif Pulvérisé',
      description: 'Atteindre le poids cible défini dans votre profil.',
      icon: Icons.emoji_events,
      color: Colors.yellow.shade800,
      category: BadgeCategory.streak,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'progress_photo',
      title: 'Preuve en Image',
      description: 'Ajouter une photo à votre galerie de suivi corporel.',
      icon: Icons.camera_alt,
      color: Colors.pink,
      category: BadgeCategory.streak,
      maxProgress: 1,
    ),

    // --- SOCIAL & DÉFIS ---
    BadgeItem(
      id: 'social_first_friend',
      title: 'Esprit d’Équipe',
      description: 'Ajouter votre premier ami sur NutriZen.',
      icon: Icons.person_add,
      color: Colors.blueAccent,
      category: BadgeCategory.social,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'social_challenge_join',
      title: 'Compétiteur Né',
      description: 'Participer à un défi hebdomadaire de groupe.',
      icon: Icons.groups,
      color: Colors.teal.shade700,
      category: BadgeCategory.social,
      maxProgress: 1,
    ),
    BadgeItem(
      id: 'social_podium',
      title: 'Sur le Podium',
      description: 'Terminer dans le top 3 du classement hebdomadaire des amis.',
      icon: Icons.military_tech,
      color: Colors.amber,
      category: BadgeCategory.social,
      maxProgress: 1,
    ),
  ];
}
