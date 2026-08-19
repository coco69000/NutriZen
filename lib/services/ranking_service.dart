// File: services/ranking_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ranking_models.dart';

class LeaderboardResult {
  final List<RankingEntry> entries;
  final RankingEntry? me;
  final int? myRank;
  LeaderboardResult({required this.entries, this.me, this.myRank});
}

/// Données brutes de l'utilisateur pour calculer le score
class UserStatsInput {
  final String displayName;
  final String countryCode;

  // Nutrition
  final double nutritionAdherence; // 0-100
  final int mealsLogged;

  // Hydratation
  final double waterAdherence; // 0-100

  // Activité
  final double weeklyKcal;
  final int steps;
  final int workoutsCount;

  // Jeûne
  final int fastingSessions;
  final double fastingAdherence; // 0-100

  // Objectif
  final double goalProgress; // 0-100
  final String goalType;
  final double weightDelta;
  final double currentWeight;

  // Engagement
  final int streak;
  final int badgesUnlocked;
  final int aiAnalyses;
  final int scansCount;

  // Éco
  final double ecoScore; // 0-100

  const UserStatsInput({
    required this.displayName,
    required this.countryCode,
    this.nutritionAdherence = 0,
    this.mealsLogged = 0,
    this.waterAdherence = 0,
    this.weeklyKcal = 0,
    this.steps = 0,
    this.workoutsCount = 0,
    this.fastingSessions = 0,
    this.fastingAdherence = 0,
    this.goalProgress = 0,
    this.goalType = 'maintain',
    this.weightDelta = 0,
    this.currentWeight = 70,
    this.streak = 0,
    this.badgesUnlocked = 0,
    this.aiAnalyses = 0,
    this.scansCount = 0,
    this.ecoScore = 50,
  });
}

class RankingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  RankingService({required this.userId});

  // ═══════════════════════════════════════════════════════════
  // CALCUL DU SCORE GLOBAL
  // ═══════════════════════════════════════════════════════════

  static ScoreBreakdown computeBreakdown(UserStatsInput stats) {
    // 🍽️ Nutrition (max ~150)
    final nutrition = (stats.nutritionAdherence.clamp(0.0, 100.0) * 1.0) +
        (stats.mealsLogged.clamp(0, 10) * 5.0);

    // 💧 Hydratation (max ~50)
    final hydration = stats.waterAdherence.clamp(0.0, 100.0) * 0.5;

    // 🏃 Activité (max ~100)
    final activity = (stats.weeklyKcal / 500).clamp(0.0, 30.0) +
        (stats.steps / 10000).clamp(0.0, 1.0) * 20.0 +
        (stats.workoutsCount.clamp(0, 10) * 5.0);

    // ⏱️ Jeûne (max ~50)
    final fasting = (stats.fastingSessions.clamp(0, 5) * 5.0) +
        (stats.fastingAdherence.clamp(0.0, 100.0) * 0.25);

    // 🎯 Objectif (max ~100)
    final goal = stats.goalProgress.clamp(0.0, 100.0) * 1.0;

    // 🔥 Engagement (max ~200)
    final engagement = (stats.streak.clamp(0, 60) * 2.0) +
        (stats.badgesUnlocked.clamp(0, 50) * 1.0) +
        (stats.aiAnalyses.clamp(0, 10) * 2.0) +
        (stats.scansCount.clamp(0, 10) * 1.0);

    // 🌿 Éco (max ~30)
    final eco = stats.ecoScore.clamp(0.0, 100.0) * 0.3;

    return ScoreBreakdown(
      nutrition: double.parse(nutrition.toStringAsFixed(1)),
      hydration: double.parse(hydration.toStringAsFixed(1)),
      activity: double.parse(activity.toStringAsFixed(1)),
      fasting: double.parse(fasting.toStringAsFixed(1)),
      goal: double.parse(goal.toStringAsFixed(1)),
      engagement: double.parse(engagement.toStringAsFixed(1)),
      eco: double.parse(eco.toStringAsFixed(1)),
    );
  }

  static double computeTotalScore(ScoreBreakdown b) {
    return double.parse((b.nutrition +
            b.hydration +
            b.activity +
            b.fasting +
            b.goal +
            b.engagement +
            b.eco)
        .toStringAsFixed(1));
  }

  // ═══════════════════════════════════════════════════════════
  // PUBLICATION DES STATS + HISTORIQUE POUR ÉVOLUTION
  // ═══════════════════════════════════════════════════════════

  Future<void> publishMyStats(UserStatsInput stats) async {
    if (userId.isEmpty) return;
    try {
      final breakdown = computeBreakdown(stats);
      final score = computeTotalScore(breakdown);

      // 1. Récupérer l'historique pour calculer les évolutions
      final history = await _getScoreHistory();
      final lastWeekEntry = _getLastWeekEntry(history);

      // 2. Calculer les évolutions
      double? evoScore, evoWeight, evoActivity, evoNutrition;

      if (lastWeekEntry != null) {
        // Évolution du score global
        if (lastWeekEntry['score'] != null && (lastWeekEntry['score'] as num) > 0) {
          evoScore = ((score - (lastWeekEntry['score'] as num).toDouble()) /
                  (lastWeekEntry['score'] as num).toDouble()) *
              100;
        }
        // Évolution du poids (négatif = perte = positif pour 'lose')
        if (lastWeekEntry['weight'] != null) {
          final lastWeight = (lastWeekEntry['weight'] as num).toDouble();
          if (lastWeight > 0) {
            evoWeight = ((stats.currentWeight - lastWeight) / lastWeight) * 100;
            if (stats.goalType == 'lose') evoWeight = -evoWeight;
          }
        }
        // Évolution activité
        if (lastWeekEntry['activity'] != null &&
            (lastWeekEntry['activity'] as num) > 0) {
          evoActivity = ((breakdown.activity -
                      (lastWeekEntry['activity'] as num).toDouble()) /
                  (lastWeekEntry['activity'] as num).toDouble()) *
              100;
        }
        // Évolution nutrition
        if (lastWeekEntry['nutrition'] != null &&
            (lastWeekEntry['nutrition'] as num) > 0) {
          evoNutrition = ((breakdown.nutrition -
                      (lastWeekEntry['nutrition'] as num).toDouble()) /
                  (lastWeekEntry['nutrition'] as num).toDouble()) *
              100;
        }
      }

      // 3. Sauvegarder le snapshot actuel dans l'historique
      await _saveScoreSnapshot(score, breakdown, stats.currentWeight);

      // 4. Publier dans le document utilisateur avec gardes de sécurité
      await _db.collection('users').doc(userId).set({
        'displayName': stats.displayName,
        'countryCode': stats.countryCode,
        'rank_score': score,
        'rank_breakdown': breakdown.toMap(),
        'rank_streak': stats.streak.clamp(0, 365),
        'rank_badges': stats.badgesUnlocked.clamp(0, 100),
        'rank_goalProgress': stats.goalProgress.clamp(0.0, 100.0),
        'rank_weeklyKcal': stats.weeklyKcal.clamp(0.0, 35000.0),
        'rank_steps': stats.steps.clamp(0, 100000),
        'rank_goalType': stats.goalType,
        'rank_weightDelta': stats.weightDelta.clamp(-50.0, 50.0),
        'rank_currentWeight': stats.currentWeight.clamp(20.0, 300.0),
        'rank_waterAdherence': stats.waterAdherence.clamp(0.0, 100.0),
        'rank_mealsLogged': stats.mealsLogged.clamp(0, 50),
        'rank_fastingSessions': stats.fastingSessions.clamp(0, 50),
        'rank_aiAnalyses': stats.aiAnalyses.clamp(0, 100),
        'evo_score': evoScore,
        'evo_weight': evoWeight,
        'evo_activity': evoActivity,
        'evo_nutrition': evoNutrition,
        'rank_lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
          '✅ Stats publiées: score=$score, evo=${evoScore?.toStringAsFixed(1)}%');
    } catch (e) {
      debugPrint('Erreur publication stats: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // HISTORIQUE DES SCORES (pour les évolutions)
  // ═══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _getScoreHistory() async {
    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('scoreHistory')
          .orderBy('date', descending: true)
          .limit(10)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic>? _getLastWeekEntry(List<Map<String, dynamic>> history) {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    for (var entry in history) {
      final date = (entry['date'] as Timestamp?)?.toDate();
      if (date != null && date.isBefore(oneWeekAgo)) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _saveScoreSnapshot(
      double score, ScoreBreakdown breakdown, double weight) async {
    try {
      final today = DateTime.now();
      final docId =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _db
          .collection('users')
          .doc(userId)
          .collection('scoreHistory')
          .doc(docId)
          .set({
        'date': FieldValue.serverTimestamp(),
        'score': score,
        'weight': weight,
        'nutrition': breakdown.nutrition,
        'activity': breakdown.activity,
        'hydration': breakdown.hydration,
        'fasting': breakdown.fasting,
        'goal': breakdown.goal,
        'engagement': breakdown.engagement,
        'eco': breakdown.eco,
      });
    } catch (e) {
      debugPrint('Erreur sauvegarde snapshot: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // VISIBILITÉ
  // ═══════════════════════════════════════════════════════════

  Future<void> setVisibility({bool? friends, bool? world}) async {
    try {
      await _db.collection('users').doc(userId).set({
        if (friends != null) 'privacyFriends': friends,
        if (world != null) 'privacyWorld': world,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erreur visibilité: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CLASSEMENTS
  // ═══════════════════════════════════════════════════════════

  Future<LeaderboardResult> getFriendsLeaderboard(
      List<String> friendIds) async {
    try {
      final ids = <String>{...friendIds, userId}.toList();
      if (ids.isEmpty) return LeaderboardResult(entries: []);

      final List<RankingEntry> pool = [];
      for (var i = 0; i < ids.length; i += 30) {
        final chunk =
            ids.sublist(i, (i + 30) > ids.length ? ids.length : (i + 30));
        final snap = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          if (doc.data()['privacyFriends'] == true) {
            pool.add(RankingEntry.fromFirestore(doc));
          }
        }
      }
      pool.sort((a, b) => b.score.compareTo(a.score));
      final myIndex = pool.indexWhere((e) => e.uid == userId);
      return LeaderboardResult(
        entries: pool,
        me: myIndex >= 0 ? pool[myIndex] : null,
        myRank: myIndex >= 0 ? myIndex + 1 : null,
      );
    } catch (e) {
      debugPrint('Erreur classement amis: $e');
      return LeaderboardResult(entries: []);
    }
  }

  Future<LeaderboardResult> getCountryLeaderboard(String countryCode) async {
    try {
      final snap = await _db
          .collection('users')
          .where('countryCode', isEqualTo: countryCode)
          .where('privacyWorld', isEqualTo: true)
          .orderBy('rank_score', descending: true)
          .limit(100)
          .get();
      final entries =
          snap.docs.map((d) => RankingEntry.fromFirestore(d)).toList();
      return await _attachMyRank(entries);
    } catch (e) {
      debugPrint('Erreur classement pays: $e');
      return LeaderboardResult(entries: []);
    }
  }

  Future<LeaderboardResult> getWorldLeaderboard() async {
    try {
      final snap = await _db
          .collection('users')
          .where('privacyWorld', isEqualTo: true)
          .orderBy('rank_score', descending: true)
          .limit(100)
          .get();
      final entries =
          snap.docs.map((d) => RankingEntry.fromFirestore(d)).toList();
      return await _attachMyRank(entries);
    } catch (e) {
      debugPrint('Erreur classement monde: $e');
      return LeaderboardResult(entries: []);
    }
  }

  Future<LeaderboardResult> _attachMyRank(List<RankingEntry> entries) async {
    final myIndex = entries.indexWhere((e) => e.uid == userId);
    if (myIndex >= 0) {
      return LeaderboardResult(
          entries: entries, me: entries[myIndex], myRank: myIndex + 1);
    }
    RankingEntry? me;
    int? rank;
    try {
      final myDoc = await _db.collection('users').doc(userId).get();
      if (myDoc.exists && myDoc.data()?['privacyWorld'] == true) {
        me = RankingEntry.fromFirestore(myDoc);
        final countSnap = await _db
            .collection('users')
            .where('privacyWorld', isEqualTo: true)
            .where('rank_score', isGreaterThan: me.score)
            .count()
            .get();
        rank = (countSnap.count ?? 0) + 1;
      }
    } catch (e) {
      debugPrint('Erreur calcul rang: $e');
    }
    return LeaderboardResult(entries: entries, me: me, myRank: rank);
  }

  // ═══════════════════════════════════════════════════════════
  // PROFIL PUBLIC
  // ═══════════════════════════════════════════════════════════

  Future<RankingEntry?> getPublicProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final d = doc.data() ?? {};
      final isPublic =
          (d['privacyFriends'] == true) || (d['privacyWorld'] == true);
      if (!isPublic) return null;
      return RankingEntry.fromFirestore(doc);
    } catch (e) {
      debugPrint('Erreur profil public: $e');
      return null;
    }
  }
}
