import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/badge_model.dart';
import 'service_locator.dart';
import 'social_service.dart';

class BadgeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  BadgeService({required this.userId});

  /// Récupère la liste de tous les badges avec la progression de l'utilisateur
  Future<List<BadgeItem>> getUserBadges() async {
    final templates = BadgeCatalog.allBadges;
    if (userId.isEmpty) return templates;

    try {
      final snapshot = await _db.collection('users').doc(userId).collection('badges').get();
      final Map<String, Map<String, dynamic>> userBadgeData = {
        for (var doc in snapshot.docs) doc.id: doc.data()
      };

      return templates.map((template) {
        if (userBadgeData.containsKey(template.id)) {
          return BadgeItem.fromMap(template, userBadgeData[template.id]!);
        }
        return template;
      }).toList();
    } catch (e) {
      debugPrint("Erreur récupération badges: $e");
      return templates;
    }
  }

  /// Évalue automatiquement les badges en fonction de l'état actuel de l'utilisateur
  Future<List<BadgeItem>> evaluateBadges({
    required List<FoodEntry> foods,
    required List<FastingSession> fasts,
    required List<ActivityEntry> activities,
    required List<ScannedProduct> scans,
    required int streak,
    required bool hasAchievedGoal,
    required int friendsCount,
    required int photoGalleryCount,
    BuildContext? context,
  }) async {
    final badges = await getUserBadges();
    List<BadgeItem> newlyUnlocked = [];

    for (var badge in badges) {
      if (badge.isUnlocked) continue;

      int progress = badge.currentProgress;
      bool unlock = false;

      switch (badge.id) {
        case 'first_meal':
          progress = foods.length;
          unlock = foods.isNotEmpty;
          break;
        case 'custom_recipe':
          unlock = foods.any((f) => f.source == 'Recette Perso');
          progress = unlock ? 1 : 0;
          break;
        case 'first_fast':
          unlock = fasts.any((f) => f.isTargetReached || f.duration.inHours >= 12);
          progress = unlock ? 1 : 0;
          break;
        case 'warrior_fast':
          unlock = fasts.any((f) => f.duration.inHours >= 20);
          progress = unlock ? 1 : 0;
          break;
        case 'fasting_streak_5':
          progress = fasts.length;
          unlock = progress >= 5;
          break;
        case 'first_workout':
          progress = activities.length;
          unlock = activities.isNotEmpty;
          break;
        case 'calorie_burner_500':
          unlock = activities.any((a) => a.caloriesBurned >= 500);
          progress = unlock ? 1 : 0;
          break;
        case 'first_scan':
          progress = scans.length;
          unlock = scans.isNotEmpty;
          break;
        case 'eco_hero_5':
          progress = scans.where((s) => s.nutriScore == 'A' || s.nutriScore == 'B').length;
          unlock = progress >= 5;
          break;
        case 'streak_3':
          progress = streak;
          unlock = streak >= 3;
          break;
        case 'streak_7':
          progress = streak;
          unlock = streak >= 7;
          break;
        case 'streak_30':
          progress = streak;
          unlock = streak >= 30;
          break;
        case 'goal_achieved':
          unlock = hasAchievedGoal;
          progress = unlock ? 1 : 0;
          break;
        case 'progress_photo':
          progress = photoGalleryCount;
          unlock = photoGalleryCount >= 1;
          break;
        case 'social_first_friend':
          progress = friendsCount;
          unlock = friendsCount >= 1;
          break;
      }

      badge.currentProgress = progress.clamp(0, badge.maxProgress);

      if (unlock && !badge.isUnlocked) {
        badge.isUnlocked = true;
        badge.unlockedAt = DateTime.now();
        newlyUnlocked.add(badge);

        // Sauvegarder dans Firestore
        await _db.collection('users').doc(userId).collection('badges').doc(badge.id).set(badge.toMap());

        // 🚀 NOUVEAU : Publier le succès dans le fil d'actualité social
        final socialService = SocialService(
          userId: userId,
          notificationService: SL.notificationService,
          memoryService: SL.memoryService,
        );
        await socialService.publishSuccessActivity(badge.title, badge.description);

        // Alerte visuelle / Notification locale
        if (context != null && context.mounted) {
          _showBadgeUnlockedDialog(context, badge);
        }
      } else {
        // Mise à jour de la progression
        await _db.collection('users').doc(userId).collection('badges').doc(badge.id).set(badge.toMap(), SetOptions(merge: true));
      }
    }

    return newlyUnlocked;
  }

  void _showBadgeUnlockedDialog(BuildContext context, BadgeItem badge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🏆 Succès Déverrouillé !', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: badge.color.withValues(alpha: 0.2),
              child: Icon(badge.icon, size: 45, color: badge.color),
            ),
            const SizedBox(height: 16),
            Text(badge.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(badge.description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Génial !'),
            ),
          )
        ],
      ),
    );
  }
}
