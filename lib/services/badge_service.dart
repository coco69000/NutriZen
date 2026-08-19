import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/badge_model.dart';

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
}
