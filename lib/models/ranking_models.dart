// File: models/ranking_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Évolution d'une métrique (flèche + pourcentage)
class Evolution {
  final double percent; // ex: +12.5 ou -3.2
  final bool isUp;
  const Evolution({required this.percent, required this.isUp});

  String get label => '${isUp ? '+' : ''}${percent.toStringAsFixed(1)}%';
}

/// Détail du score par catégorie
class ScoreBreakdown {
  final double nutrition;
  final double hydration;
  final double activity;
  final double fasting;
  final double goal;
  final double engagement;
  final double eco;

  const ScoreBreakdown({
    this.nutrition = 0,
    this.hydration = 0,
    this.activity = 0,
    this.fasting = 0,
    this.goal = 0,
    this.engagement = 0,
    this.eco = 0,
  });

  Map<String, dynamic> toMap() => {
        'nutrition': nutrition,
        'hydration': hydration,
        'activity': activity,
        'fasting': fasting,
        'goal': goal,
        'engagement': engagement,
        'eco': eco,
      };

  factory ScoreBreakdown.fromMap(Map<String, dynamic> map) => ScoreBreakdown(
        nutrition: (map['nutrition'] as num?)?.toDouble() ?? 0,
        hydration: (map['hydration'] as num?)?.toDouble() ?? 0,
        activity: (map['activity'] as num?)?.toDouble() ?? 0,
        fasting: (map['fasting'] as num?)?.toDouble() ?? 0,
        goal: (map['goal'] as num?)?.toDouble() ?? 0,
        engagement: (map['engagement'] as num?)?.toDouble() ?? 0,
        eco: (map['eco'] as num?)?.toDouble() ?? 0,
      );
}

/// Une entrée du classement
class RankingEntry {
  final String uid;
  final String displayName;
  final String countryCode;
  final double score;
  final ScoreBreakdown breakdown;

  // Évolutions (vs semaine dernière)
  final Evolution? scoreEvolution;
  final Evolution? weightEvolution;
  final Evolution? activityEvolution;
  final Evolution? nutritionEvolution;

  // Stats brutes pour le profil
  final int streak;
  final int badgesUnlocked;
  final double goalProgress;
  final double weeklyKcal;
  final int steps;
  final String goalType;
  final double weightDelta;
  final double currentWeight;
  final double waterAdherence;
  final int mealsLogged;
  final int fastingSessions;
  final int aiAnalyses;
  final DateTime lastActive;

  RankingEntry({
    required this.uid,
    required this.displayName,
    required this.countryCode,
    required this.score,
    required this.breakdown,
    this.scoreEvolution,
    this.weightEvolution,
    this.activityEvolution,
    this.nutritionEvolution,
    required this.streak,
    required this.badgesUnlocked,
    required this.goalProgress,
    required this.weeklyKcal,
    required this.steps,
    required this.goalType,
    required this.weightDelta,
    required this.currentWeight,
    required this.waterAdherence,
    required this.mealsLogged,
    required this.fastingSessions,
    required this.aiAnalyses,
    required this.lastActive,
  });

  factory RankingEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    // Évolutions
    Evolution? parseEvo(String key) {
      if (d[key] == null) return null;
      final val = (d[key] as num).toDouble();
      return Evolution(percent: val, isUp: val >= 0);
    }

    return RankingEntry(
      uid: doc.id,
      displayName: (d['displayName'] ?? 'Utilisateur NutriZen').toString(),
      countryCode: (d['countryCode'] ?? 'XX').toString(),
      score: (d['rank_score'] as num?)?.toDouble() ?? 0,
      breakdown: ScoreBreakdown.fromMap(
          Map<String, dynamic>.from(d['rank_breakdown'] ?? {})),
      scoreEvolution: parseEvo('evo_score'),
      weightEvolution: parseEvo('evo_weight'),
      activityEvolution: parseEvo('evo_activity'),
      nutritionEvolution: parseEvo('evo_nutrition'),
      streak: (d['rank_streak'] as num?)?.toInt() ?? 0,
      badgesUnlocked: (d['rank_badges'] as num?)?.toInt() ?? 0,
      goalProgress: (d['rank_goalProgress'] as num?)?.toDouble() ?? 0,
      weeklyKcal: (d['rank_weeklyKcal'] as num?)?.toDouble() ?? 0,
      steps: (d['rank_steps'] as num?)?.toInt() ?? 0,
      goalType: (d['rank_goalType'] ?? 'maintain').toString(),
      weightDelta: (d['rank_weightDelta'] as num?)?.toDouble() ?? 0,
      currentWeight: (d['rank_currentWeight'] as num?)?.toDouble() ?? 70,
      waterAdherence: (d['rank_waterAdherence'] as num?)?.toDouble() ?? 0,
      mealsLogged: (d['rank_mealsLogged'] as num?)?.toInt() ?? 0,
      fastingSessions: (d['rank_fastingSessions'] as num?)?.toInt() ?? 0,
      aiAnalyses: (d['rank_aiAnalyses'] as num?)?.toInt() ?? 0,
      lastActive: (d['rank_lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Niveau / titre du joueur
class RankLevel {
  final int level;
  final String title;
  final String emoji;
  const RankLevel(this.level, this.title, this.emoji);

  static RankLevel fromScore(double score) {
    if (score < 100) return const RankLevel(1, 'Recrue', '🌱');
    if (score < 200) return const RankLevel(2, 'Débutant', '🚶');
    if (score < 300) return const RankLevel(3, 'Habitué(e)', '🏃');
    if (score < 400) return const RankLevel(4, 'Athlète', '💪');
    if (score < 500) return const RankLevel(5, 'Champion(ne)', '🏅');
    if (score < 600) return const RankLevel(6, 'Elite', '🏆');
    return const RankLevel(7, 'Légende', '👑');
  }
}

/// Pays
class Countries {
  static const Map<String, String> names = {
    'FR': 'France',
    'BE': 'Belgique',
    'CH': 'Suisse',
    'CA': 'Canada',
    'LU': 'Luxembourg',
    'MA': 'Maroc',
    'DZ': 'Algérie',
    'TN': 'Tunisie',
    'SN': 'Sénégal',
    'CI': "Côte d'Ivoire",
    'CM': 'Cameroun',
    'ML': 'Mali',
    'BF': 'Burkina Faso',
    'TG': 'Togo',
    'BJ': 'Bénin',
    'GA': 'Gabon',
    'CG': 'Congo',
    'US': 'États-Unis',
    'GB': 'Royaume-Uni',
    'ES': 'Espagne',
    'DE': 'Allemagne',
    'IT': 'Italie',
    'PT': 'Portugal',
    'NL': 'Pays-Bas',
    'IE': 'Irlande',
    'SE': 'Suède',
    'NO': 'Norvège',
    'DK': 'Danemark',
    'PL': 'Pologne',
    'BR': 'Brésil',
    'MX': 'Mexique',
    'JP': 'Japon',
    'AU': 'Australie',
    'XX': 'International',
  };
  static List<String> get codes => names.keys.toList();
  static String nameOf(String code) => names[code.toUpperCase()] ?? code.toUpperCase();
}

extension FlagExtension on String {
  String get flagEmoji {
    final cc = toUpperCase().trim();
    if (cc.length != 2) return '🏳️';
    return String.fromCharCodes(cc.codeUnits.map((c) => 0x1F1E6 + (c - 65)));
  }
}

String goalTypeLabelFr(String type) {
  switch (type) {
    case 'lose':
      return 'Perte de poids';
    case 'gain':
      return 'Prise de muscle';
    default:
      return 'Maintien';
  }
}
