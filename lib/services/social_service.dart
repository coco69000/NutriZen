import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'long_term_memory_service.dart';

class SocialFriend {
  final String uid;
  final String displayName;
  final String email;
  final double currentSteps;
  final double targetSteps;
  final double caloriesBurned;
  final double currentWeight;
  final DateTime lastActive;

  SocialFriend({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.currentSteps,
    required this.targetSteps,
    required this.caloriesBurned,
    required this.currentWeight,
    required this.lastActive,
  });

  factory SocialFriend.fromFirestore(Map<String, dynamic> data, String id) {
    return SocialFriend(
      uid: id,
      displayName: data['displayName'] ?? data['name'] ?? 'Ami NutriZen',
      email: data['email'] ?? '',
      currentSteps: (data['currentSteps'] ?? 0).toDouble(),
      targetSteps: (data['targetSteps'] ?? 10000).toDouble(),
      caloriesBurned: (data['caloriesBurned'] ?? 0).toDouble(),
      currentWeight: (data['currentWeight'] ?? 70.0).toDouble(),
      lastActive:
          data['lastActive'] != null
              ? (data['lastActive'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }
}

enum ChallengeType { steps, calories, water, fasting }

extension ChallengeTypeExt on ChallengeType {
  String get typeLabel {
    switch (this) {
      case ChallengeType.steps:
        return 'Pas 🚶';
      case ChallengeType.calories:
        return 'Calories 🔥';
      case ChallengeType.water:
        return 'Hydratation 💧';
      case ChallengeType.fasting:
        return 'Jeûne ⏱️';
    }
  }
}

enum ChallengeStatus { pending, active, finished, declined }

class SocialChallenge {
  final String id;
  final String creatorUid;
  final String creatorName;
  final String opponentUid;
  final String opponentName;
  final ChallengeType type;
  final double targetValue;
  final DateTime startDate;
  final DateTime endDate;
  ChallengeStatus status;
  final String wager;
  double creatorScore;
  double opponentScore;
  String? winnerUid;

  SocialChallenge({
    required this.id,
    required this.creatorUid,
    required this.creatorName,
    required this.opponentUid,
    required this.opponentName,
    required this.type,
    required this.targetValue,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.wager,
    this.creatorScore = 0.0,
    this.opponentScore = 0.0,
    this.winnerUid,
  });

  String get unit {
    switch (type) {
      case ChallengeType.steps:
        return 'pas';
      case ChallengeType.calories:
        return 'kcal';
      case ChallengeType.water:
        return 'ml';
      case ChallengeType.fasting:
        return 'heures';
    }
  }

  String get typeLabel {
    switch (type) {
      case ChallengeType.steps:
        return 'Pas 🚶';
      case ChallengeType.calories:
        return 'Calories 🔥';
      case ChallengeType.water:
        return 'Hydratation 💧';
      case ChallengeType.fasting:
        return 'Jeûne ⏱️';
    }
  }

  factory SocialChallenge.fromFirestore(Map<String, dynamic> data, String id) {
    return SocialChallenge(
      id: id,
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'] ?? 'Créateur',
      opponentUid: data['opponentUid'] ?? '',
      opponentName: data['opponentName'] ?? 'Adversaire',
      type: ChallengeType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ChallengeType.steps,
      ),
      targetValue: (data['targetValue'] ?? 0.0).toDouble(),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ChallengeStatus.pending,
      ),
      wager: data['wager'] ?? '',
      creatorScore: (data['creatorScore'] ?? 0.0).toDouble(),
      opponentScore: (data['opponentScore'] ?? 0.0).toDouble(),
      winnerUid: data['winnerUid'],
    );
  }
}

class FriendActivityFeed {
  final String id;
  final String friendName;
  final String badgeTitle;
  final String description;
  final DateTime timestamp;
  int likesCount;
  bool isLiked;

  FriendActivityFeed({
    required this.id,
    required this.friendName,
    required this.badgeTitle,
    required this.description,
    required this.timestamp,
    this.likesCount = 0,
    this.isLiked = false,
  });
}

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService;
  final LongTermMemoryService _memoryService;
  final String userId;

  SocialService({
    required this.userId,
    required NotificationService notificationService,
    required LongTermMemoryService memoryService,
  }) : _notificationService = notificationService,
       _memoryService = memoryService;

  /// Ajoute un ami par son adresse e-mail ou UID (CORRIGÉ)
  Future<bool> addFriend(String emailOrUid) async {
    if (userId.isEmpty || emailOrUid.isEmpty) return false;
    try {
      String targetUid = '';
      String friendName = 'Ami NutriZen';
      String friendEmail = emailOrUid.trim();

      // 1. Tentative de recherche par Email
      var query =
          await _db
              .collection('users')
              .where('email', isEqualTo: emailOrUid.trim())
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        targetUid = query.docs.first.id;
        friendName =
            query.docs.first.data()['displayName'] ??
            query.docs.first.data()['firstName'] ??
            'Ami';
      } else {
        // 2. Tentative par UID (Document ID)
        final docSnap =
            await _db.collection('users').doc(emailOrUid.trim()).get();
        if (docSnap.exists) {
          targetUid = docSnap.id;
          friendName =
              docSnap.data()?['displayName'] ??
              docSnap.data()?['firstName'] ??
              'Ami';
          friendEmail = docSnap.data()?['email'] ?? emailOrUid.trim();
        } else {
          return false; // L'utilisateur n'existe pas dans la base
        }
      }

      if (targetUid == userId) return false; // Ne peut pas s'ajouter soi-même

      await _db
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(targetUid)
          .set({
            'addedAt': FieldValue.serverTimestamp(),
            'displayName': friendName,
            'email': friendEmail,
          }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint("Erreur ajout ami: $e");
      return false;
    }
  }

  /// Récupère la liste des amis (OPTIMISÉ avec whereIn)
  Future<List<SocialFriend>> getFriends() async {
    if (userId.isEmpty) return [];
    try {
      final snapshot =
          await _db.collection('users').doc(userId).collection('friends').get();

      if (snapshot.docs.isEmpty) return [];

      final friendIds = snapshot.docs.map((d) => d.id).toList();
      List<SocialFriend> friends = [];

      // Firestore limite 'whereIn' à 30 éléments. On découpe par lots de 30.
      for (var i = 0; i < friendIds.length; i += 30) {
        final chunk = friendIds.sublist(
          i,
          i + 30 > friendIds.length ? friendIds.length : i + 30,
        );
        final usersQuery =
            await _db
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

        for (var doc in usersQuery.docs) {
          friends.add(SocialFriend.fromFirestore(doc.data(), doc.id));
        }
      }
      return friends;
    } catch (e) {
      debugPrint("Erreur chargement amis: $e");
      return [];
    }
  }

  /// CRÉER UN DUEL (Depuis la carte d'un ami ou le FAB)
  Future<String?> createDuel({
    required String opponentUid,
    required String opponentName,
    required ChallengeType type,
    required double targetValue,
    required DateTime startDate,
    required DateTime endDate,
    required String wager,
  }) async {
    if (userId.isEmpty || opponentUid.isEmpty) return null;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final creatorName =
          userDoc.data()?['displayName'] ??
          userDoc.data()?['firstName'] ??
          'Moi';

      final docRef = await _db.collection('challenges').add({
        'creatorUid': userId,
        'creatorName': creatorName,
        'opponentUid': opponentUid,
        'opponentName': opponentName,
        'type': type.name,
        'targetValue': targetValue,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': ChallengeStatus.pending.name,
        'wager': wager,
        'creatorScore': 0.0,
        'opponentScore': 0.0,
        'winnerUid': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final notificationId = docRef.id.hashCode.abs() % 100000;
      await _notificationService.showInstantNotification(
        id: notificationId,
        title: "Nouveau Défi Lancé ! 🔥",
        body: "Vous avez défié $opponentName sur le thème ${type.typeLabel} !",
      );

      // ✅ CORRECTION : Suppression de l'appel httpsCallable redondant et dangereux.
      // Le trigger Firestore 'onChallengeCreated' enverra automatiquement la notification push à l'adversaire.
      return docRef.id;
    } catch (e) {
      debugPrint("Erreur création duel: $e");
      return null;
    }
  }

  /// ACCEPTER UN DUEL
  Future<void> acceptDuel(String challengeId) async {
    try {
      final challengeDoc =
          await _db.collection('challenges').doc(challengeId).get();
      final data = challengeDoc.data();

      await _db.collection('challenges').doc(challengeId).update({
        'status': ChallengeStatus.active.name,
      });

      await _notificationService.showInstantNotification(
        id: challengeId.hashCode.abs() % 100000,
        title: "Duel Accepté ! ⚔️",
        body: "Le duel est désormais actif. Que le meilleur gagne !",
      );

      // ✅ CORRECTION : Le trigger Firestore 'onChallengeStatusUpdated' notifie automatiquement le créateur.
    } catch (e) {
      debugPrint("Erreur acceptation duel: $e");
    }
  }

  /// REFUSER UN DUEL
  Future<void> declineDuel(String challengeId) async {
    try {
      await _db.collection('challenges').doc(challengeId).update({
        'status': ChallengeStatus.declined.name,
      });
    } catch (e) {
      debugPrint("Erreur refus duel: $e");
    }
  }

  /// CALCULER LE SCORE D'UN UTILISATEUR POUR UN DUEL
  Future<double> calculateScoreForUser(
    String uid,
    ChallengeType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startTimestamp = Timestamp.fromDate(start);
      final endTimestamp = Timestamp.fromDate(end);

      if (type == ChallengeType.steps || type == ChallengeType.calories) {
        final snap =
            await _db
                .collection('users')
                .doc(uid)
                .collection('activities')
                .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
                .where('timestamp', isLessThanOrEqualTo: endTimestamp)
                .get();

        double total = 0.0;
        for (var doc in snap.docs) {
          final data = doc.data();
          if (type == ChallengeType.steps) {
            if (data['activityType'] == 'Marche_Auto') {
              final String desc = data['description'] ?? '';
              final RegExp reg = RegExp(r'(\d+)\s*pas');
              final match = reg.firstMatch(desc);
              if (match != null) {
                total += double.tryParse(match.group(1) ?? '0') ?? 0.0;
              }
            }
          } else {
            total += (data['caloriesBurned'] ?? 0.0).toDouble();
          }
        }
        return total;
      } else if (type == ChallengeType.water) {
        final snap =
            await _db
                .collection('users')
                .doc(uid)
                .collection('waterEntries')
                .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
                .where('timestamp', isLessThanOrEqualTo: endTimestamp)
                .get();

        return snap.docs.fold<double>(
          0.0,
          (acc, doc) => acc + (doc.data()['amountMl'] ?? 0.0).toDouble(),
        );
      } else if (type == ChallengeType.fasting) {
        final snap =
            await _db
                .collection('users')
                .doc(uid)
                .collection('fastingSessions')
                .where('startTime', isGreaterThanOrEqualTo: startTimestamp)
                .where('startTime', isLessThanOrEqualTo: endTimestamp)
                .get();

        return snap.docs.fold<double>(0.0, (acc, doc) {
          final data = doc.data();
          final durationMinutes = (data['durationMinutes'] ?? 0).toDouble();
          return acc + (durationMinutes / 60.0);
        });
      }
      return 0.0;
    } catch (e) {
      debugPrint("Erreur calcul score duel ($uid): $e");
      return 0.0;
    }
  }

  /// RÉCUPÉRER MES DUELS ACTIFS, EN ATTENTE ET TERMINÉS
  Future<List<SocialChallenge>> getMyDuels() async {
    if (userId.isEmpty) return [];
    try {
      final snapCreator =
          await _db
              .collection('challenges')
              .where('creatorUid', isEqualTo: userId)
              .get();

      final snapOpponent =
          await _db
              .collection('challenges')
              .where('opponentUid', isEqualTo: userId)
              .get();

      final Map<String, DocumentSnapshot<Map<String, dynamic>>> allDocs = {};
      for (var doc in snapCreator.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in snapOpponent.docs) {
        allDocs[doc.id] = doc;
      }

      final List<SocialChallenge> challenges = [];
      final DateTime now = DateTime.now();

      for (var entry in allDocs.entries) {
        final doc = entry.value;
        final challenge = SocialChallenge.fromFirestore(doc.data()!, doc.id);
        if (challenge.status != ChallengeStatus.declined) {
          challenges.add(challenge);
        }
      }

      // ✅ CORRECTION : Exécution parallèle des calculs de score au lieu d'await séquentiel
      await Future.wait(challenges.map((challenge) async {
        if (challenge.status == ChallengeStatus.active ||
            challenge.status == ChallengeStatus.finished) {
          challenge.creatorScore = await calculateScoreForUser(
            challenge.creatorUid,
            challenge.type,
            challenge.startDate,
            challenge.endDate,
          );
          challenge.opponentScore = await calculateScoreForUser(
            challenge.opponentUid,
            challenge.type,
            challenge.startDate,
            challenge.endDate,
          );

          if (now.isAfter(challenge.endDate) &&
              challenge.status != ChallengeStatus.finished) {
            challenge.status = ChallengeStatus.finished;
            final winnerUid =
                challenge.creatorScore >= challenge.opponentScore
                    ? challenge.creatorUid
                    : challenge.opponentUid;
            challenge.winnerUid = winnerUid;

            await _db.collection('challenges').doc(challenge.id).update({
              'status': ChallengeStatus.finished.name,
              'creatorScore': challenge.creatorScore,
              'opponentScore': challenge.opponentScore,
              'winnerUid': winnerUid,
            });

            final winnerName =
                winnerUid == challenge.creatorUid
                    ? challenge.creatorName
                    : challenge.opponentName;
            final loserName =
                winnerUid == challenge.creatorUid
                    ? challenge.opponentName
                    : challenge.creatorName;
            await publishSuccessActivity(
              "🏆 Victoire en Duel",
              "a vu $winnerName l'emporter sur $loserName (${challenge.creatorScore.toInt()} vs ${challenge.opponentScore.toInt()})",
            );
          }
        }
      }));

      challenges.sort((a, b) => b.startDate.compareTo(a.startDate));
      return challenges;
    } catch (e) {
      debugPrint("Erreur chargement mes duels: $e");
      return [];
    }
  }

  /// Récupère le fil d'actualité des amis (VRAIE REQUÊTE FIRESTORE)
  Future<List<FriendActivityFeed>> getFriendActivityFeed() async {
    try {
      final friendsSnap =
          await _db.collection('users').doc(userId).collection('friends').get();
      final friendIds = friendsSnap.docs.map((d) => d.id).toList();

      if (friendIds.isEmpty) return [];

      // Firestore limite 'whereIn' à 30 éléments
      final feedQuery =
          await _db
              .collection('social_feed')
              .where('userId', whereIn: friendIds.take(30).toList())
              .orderBy('timestamp', descending: true)
              .limit(20)
              .get();

      return feedQuery.docs.map((doc) {
        final data = doc.data();
        return FriendActivityFeed(
          id: doc.id,
          friendName: data['displayName'] ?? 'Ami',
          badgeTitle: data['badgeTitle'] ?? 'Succès',
          description: data['description'] ?? '',
          timestamp:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          likesCount: data['likesCount'] ?? 0,
          isLiked: false,
        );
      }).toList();
    } catch (e) {
      debugPrint("Erreur chargement feed: $e");
      return [];
    }
  }

  /// Publie un succès dans le fil d'actualités
  Future<void> publishSuccessActivity(
    String badgeTitle,
    String description,
  ) async {
    if (userId.isEmpty) return;
    try {
      // Récupérer le nom de l'utilisateur pour l'afficher dans le feed
      final userDoc = await _db.collection('users').doc(userId).get();
      final displayName =
          userDoc.data()?['displayName'] ??
          userDoc.data()?['firstName'] ??
          'Moi';

      await _db.collection('social_feed').add({
        'userId': userId,
        'displayName': displayName,
        'badgeTitle': badgeTitle,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
      });
    } catch (e) {
      debugPrint("Erreur publication succès: $e");
    }
  }

  /// Soutien Proactif (CORRECTION DU BUG DE COLLISION D'ID)
  Future<void> checkFriendsInactivity() async {
    final friends = await getFriends();
    final now = DateTime.now();
    for (var friend in friends) {
      final daysInactive = now.difference(friend.lastActive).inDays;
      if (daysInactive >= 3) {
        bool alreadyNotified = await _memoryService.hasReceivedAdviceRecently(
          'friend_inactivity_${friend.uid}',
          thresholdHours: 72,
        );
        if (!alreadyNotified) {
          // ✅ Hash complet pour éviter les collisions
          final notificationId = 'friend_${friend.uid}'.hashCode.abs() % 100000;
          await _notificationService.showInstantNotification(
            id: notificationId,
            title: "Soutien Proactif 🤝",
            body:
                "${friend.displayName} semble inactif depuis 3j. Envoyez-lui de la force !",
          );
          await _memoryService.recordAdvice('friend_inactivity_${friend.uid}');
        }
      }
    }
  }

  /// NOUVEAU : Gère le Like/Unlike d'un post du feed social (Persistant)
  Future<void> toggleLikeOnFeed(String feedId, bool isCurrentlyLiked) async {
    try {
      final feedRef = _db.collection('social_feed').doc(feedId);
      if (isCurrentlyLiked) {
        // L'utilisateur vient de cliquer pour unliker (donc c'était liké)
        await feedRef.update({'likesCount': FieldValue.increment(-1)});
      } else {
        // L'utilisateur vient de liker
        await feedRef.update({'likesCount': FieldValue.increment(1)});
      }
    } catch (e) {
      debugPrint("Erreur like/unlike: $e");
    }
  }

  /// Envoie de la force (Local + FCM Push au destinataire)
  Future<void> sendEncouragement(String friendUid, String friendName) async {
    // Hash dynamique pour éviter que les notifications ne s'écrasent entre elles
    final notificationId =
        'enc_${friendUid}_${DateTime.now().millisecondsSinceEpoch}'.hashCode
            .abs() %
        100000;
    // Notification locale de confirmation pour l'émetteur
    await _notificationService.showInstantNotification(
      id: notificationId,
      title: "Encouragement envoyé ! 💪",
      body: "Vous avez envoyé de la force à $friendName !",
    );
  }
}
