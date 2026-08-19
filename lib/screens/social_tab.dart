import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/social_service.dart';
import '../services/challenge_comparator.dart';
import '../services/ranking_service.dart';
import 'ranking_tab.dart';
import 'public_profile_screen.dart';

class SocialTab extends StatefulWidget {
  final SocialService socialService;
  final RankingService rankingService;
  final String myUid;
  final String myCountryCode;
  final bool friendsRankingVisible;
  final bool worldRankingVisible;
  final void Function(bool friends, bool world)? onRankingVisibilityChanged;
  final Future<void> Function()? onPublishRankingStats;
  final double userCurrentSteps;
  final double userTargetSteps;
  final double userCaloriesBurned;
  final double userWeight;

  const SocialTab({
    super.key,
    required this.socialService,
    required this.rankingService,
    required this.myUid,
    required this.myCountryCode,
    this.friendsRankingVisible = false,
    this.worldRankingVisible = false,
    this.onRankingVisibilityChanged,
    this.onPublishRankingStats,
    required this.userCurrentSteps,
    required this.userTargetSteps,
    this.userCaloriesBurned = 0.0,
    this.userWeight = 0.0,
  });

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SocialFriend> _friends = [];
  List<SocialChallenge> _duels = [];
  List<FriendActivityFeed> _activityFeed = [];
  bool _isLoading = true;

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSocialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Helper pour formater le temps écoulé de manière intelligente
  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return "À l'instant";
    if (difference.inMinutes < 60) return "Il y a ${difference.inMinutes} min";
    if (difference.inHours < 24) return "Il y a ${difference.inHours}h";
    if (difference.inDays < 7) return "Il y a ${difference.inDays}j";
    return DateFormat('d MMM', 'fr_FR').format(timestamp);
  }

  Future<void> _loadSocialData() async {
    setState(() => _isLoading = true);
    final friends = await widget.socialService.getFriends();
    final duels = await widget.socialService.getMyDuels();
    final feed = await widget.socialService.getFriendActivityFeed();
    await widget.socialService.checkFriendsInactivity();

    if (mounted) {
      setState(() {
        _friends = friends;
        _duels = duels;
        _activityFeed = feed;
        _isLoading = false;
      });
    }
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter un Ami 👤', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez l\'adresse e-mail ou l\'identifiant unique de votre ami pour vous comparer et lancer des duels.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'E-mail ou ID unique',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isNotEmpty) {
                final success = await widget.socialService.addFriend(email);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _emailController.clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Ami ajouté avec succès ! 🎉'
                              : 'Impossible d\'ajouter cet ami.',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                  _loadSocialData();
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  /// DIALOGUE POUR CRÉER UN DUEL PRIVÉ
  void _showCreateDuelDialog({SocialFriend? preselectedFriend}) {
    if (_friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Ajoutez au moins un ami avant de pouvoir lancer un duel ! 👥'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    SocialFriend selectedFriend = preselectedFriend ?? _friends.first;
    ChallengeType selectedType = ChallengeType.steps;
    int durationDays = 3;
    final targetController = TextEditingController(text: '10000');
    final wagerController =
        TextEditingController(text: 'Le perdant paie le café ! ☕');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('🔥 Lancer un Duel Privé',
                textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adversaire :',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SocialFriend>(
                    initialValue: selectedFriend,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _friends.map((f) {
                      return DropdownMenuItem(
                        value: f,
                        child: Text(f.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedFriend = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Type de Défi :',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ChallengeType>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ChallengeType.steps,
                        child: Text('Marcher (Pas 🚶)'),
                      ),
                      DropdownMenuItem(
                        value: ChallengeType.calories,
                        child: Text('Brûler (Calories 🔥)'),
                      ),
                      DropdownMenuItem(
                        value: ChallengeType.water,
                        child: Text('Hydratation (Eau 💧)'),
                      ),
                      DropdownMenuItem(
                        value: ChallengeType.fasting,
                        child: Text('Jeûner (Heures ⏱️)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                          if (val == ChallengeType.steps) {
                            targetController.text = '10000';
                          } else if (val == ChallengeType.calories) {
                            targetController.text = '500';
                          } else if (val == ChallengeType.water) {
                            targetController.text = '2000';
                          } else if (val == ChallengeType.fasting) {
                            targetController.text = '16';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Objectif total (${selectedType.name}) :',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Durée du Duel :',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [1, 3, 7].map((days) {
                      final isSelected = durationDays == days;
                      return ChoiceChip(
                        label: Text('$days jour${days > 1 ? 's' : ''}'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => durationDays = days);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Enjeu / Gage (Social) 🏆 :',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: wagerController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      hintText: 'Ex: Le perdant paie le café ! ☕',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final targetVal =
                      double.tryParse(targetController.text.trim()) ?? 10000;
                  final startDate = DateTime.now();
                  final endDate = startDate.add(Duration(days: durationDays));

                  final challengeId = await widget.socialService.createDuel(
                    opponentUid: selectedFriend.uid,
                    opponentName: selectedFriend.displayName,
                    type: selectedType,
                    targetValue: targetVal,
                    startDate: startDate,
                    endDate: endDate,
                    wager: wagerController.text.trim(),
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            challengeId != null
                                ? 'Duel envoyé à ${selectedFriend.displayName} ! ⚔️'
                                : 'Erreur lors de la création du duel.',
                          ),
                          backgroundColor:
                              challengeId != null ? Colors.green : Colors.red,
                        ),
                      );
                    }
                    _loadSocialData();
                  }
                },
                child: const Text('Lancer le Duel !'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double userProgressPercent = widget.userTargetSteps > 0
        ? (widget.userCurrentSteps / widget.userTargetSteps) * 100
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social & Duels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_kabaddi),
            tooltip: 'Lancer un duel',
            onPressed: () => _showCreateDuelDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Ajouter un ami',
            onPressed: _showAddFriendDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Comparatif'),
            Tab(icon: Icon(Icons.sports_kabaddi), text: 'Mes Duels'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Classement'),
            Tab(icon: Icon(Icons.notifications_active), text: 'Succès'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. TABLEAU DE BORD COMPARATIF
                _buildComparativeDashboard(userProgressPercent),

                // 2. DUELS PRIVÉS (PEER-TO-PEER)
                _buildDuelsList(),

                // 3. CLASSEMENT (AMIS / PAYS / MONDE)
                RankingTab(
                  rankingService: widget.rankingService,
                  myUid: widget.myUid,
                  myCountryCode: widget.myCountryCode,
                  friendIds: _friends.map((f) => f.uid).toList(),
                  initialFriendsVisible: widget.friendsRankingVisible,
                  initialWorldVisible: widget.worldRankingVisible,
                  onVisibilityChanged: widget.onRankingVisibilityChanged,
                  onStatsPublished: widget.onPublishRankingStats,
                ),

                // 4. FIL D'ACTUALITÉ ET SUCCÈS DES AMIS
                _buildFriendActivityFeedList(),
              ],
            ),
    );
  }

  /// 1. Vue du Tableau de Bord Comparatif
  Widget _buildComparativeDashboard(double userProgressPercent) {
    return RefreshIndicator(
      onRefresh: _loadSocialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte Récapitulative Utilisateur
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Theme.of(context).primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person,
                              size: 32, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mon Tableau de Bord',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${widget.userCurrentSteps.toInt()} pas • ${widget.userCaloriesBurned.toInt()} kcal • ${widget.userWeight} kg',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (userProgressPercent / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.amber),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              '📊 Comparatif des Amis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (_friends.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.group_add, size: 50, color: Colors.grey),
                      const SizedBox(height: 10),
                      const Text(
                        'Aucun ami ajouté pour le moment.\nAjoutez vos amis par email ou ID pour comparer vos performances et lancer des duels !',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text('Ajouter un ami'),
                        onPressed: _showAddFriendDialog,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  final duelResult = ChallengeComparator.calculateFairDuel(
                    userAActualSteps: widget.userCurrentSteps,
                    userATargetSteps: widget.userTargetSteps,
                    userBActualSteps: friend.currentSteps,
                    userBTargetSteps: friend.targetSteps,
                  );

                  final double friendProgress =
                      (duelResult['progressB'] as double);
                  final bool isAhead = userProgressPercent >= friendProgress;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isAhead
                                    ? Colors.amber.shade100
                                    : Colors.grey.shade200,
                                child: Icon(
                                  isAhead
                                      ? Icons.emoji_events
                                      : Icons.directions_walk,
                                  color: isAhead
                                      ? Colors.amber.shade800
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PublicUserProfileScreen(
                                          uid: friend.uid,
                                          myUid: widget.myUid,
                                          rankingService: widget.rankingService,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend.displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      Text(
                                        friend.email,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // BOUTON LE DÉFIER
                              IconButton(
                                icon: const Icon(Icons.sports_kabaddi,
                                    color: Colors.deepOrange),
                                tooltip: 'Défier cet ami 🔥',
                                onPressed: () => _showCreateDuelDialog(
                                    preselectedFriend: friend),
                              ),
                              // BOUTON ENVOYER DE LA FORCE
                              IconButton(
                                icon: const Icon(Icons.bolt,
                                    color: Colors.amber),
                                tooltip: 'Envoyer de la force 💪',
                                onPressed: () {
                                  widget.socialService.sendEncouragement(
                                    friend.uid,
                                    friend.displayName,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Encouragement envoyé à ${friend.displayName} ! 💪'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Divider(),

                          // Grille comparative
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricColumn(
                                  'Pas',
                                  '${friend.currentSteps.toInt()} / ${friend.targetSteps.toInt()}',
                                  Icons.directions_walk,
                                  Colors.blue),
                              _buildMetricColumn(
                                  'Calories',
                                  '${friend.caloriesBurned.toInt()} kcal',
                                  Icons.local_fire_department,
                                  Colors.orange),
                              _buildMetricColumn(
                                  'Poids',
                                  '${friend.currentWeight} kg',
                                  Icons.monitor_weight,
                                  Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  /// 2. Vue des Duels Privés (Peer-to-Peer)
  Widget _buildDuelsList() {
    final pendingDuels =
        _duels.where((d) => d.status == ChallengeStatus.pending).toList();
    final activeDuels =
        _duels.where((d) => d.status == ChallengeStatus.active).toList();
    final finishedDuels =
        _duels.where((d) => d.status == ChallengeStatus.finished).toList();

    return RefreshIndicator(
      onRefresh: _loadSocialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bouton de lancement de duel
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('🔥 Lancer un nouveau Duel'),
                onPressed: () => _showCreateDuelDialog(),
              ),
            ),
            const SizedBox(height: 20),

            // DUELS EN ATTENTE
            if (pendingDuels.isNotEmpty) ...[
              const Text(
                '📩 Duels en Attente d\'Acceptation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...pendingDuels.map((duel) {
                final isMyInvitation =
                    duel.creatorUid == widget.socialService.userId;
                return Card(
                  color: Colors.amber.shade50,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.mark_email_unread,
                                color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isMyInvitation
                                    ? 'Invitation envoyée à ${duel.opponentName}'
                                    : '${duel.creatorName} vous défie !',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Défi : ${duel.targetValue.toInt()} ${duel.unit} (${duel.typeLabel})',
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                        if (duel.wager.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Gage 🏆 : ${duel.wager}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange)),
                        ],
                        const SizedBox(height: 10),
                        if (!isMyInvitation)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  onPressed: () async {
                                    await widget.socialService
                                        .acceptDuel(duel.id);
                                    _loadSocialData();
                                  },
                                  child: const Text('Accepter ⚔️'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    await widget.socialService
                                        .declineDuel(duel.id);
                                    _loadSocialData();
                                  },
                                  child: const Text('Refuser'),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text('En attente de la réponse de l\'ami...',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // DUELS ACTIFS
            const Text(
              '⚔️ Duels en Cours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (activeDuels.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      'Aucun duel actif. Défiez vos amis pour pimenter votre routine ! 🔥',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ...activeDuels.map((duel) {
                final isCreator = duel.creatorUid == widget.socialService.userId;
                final myScore =
                    isCreator ? duel.creatorScore : duel.opponentScore;
                final opponentScore =
                    isCreator ? duel.opponentScore : duel.creatorScore;
                final opponentName =
                    isCreator ? duel.opponentName : duel.creatorName;

                final myPercent = duel.targetValue > 0
                    ? (myScore / duel.targetValue).clamp(0.0, 1.0)
                    : 0.0;
                final opponentPercent = duel.targetValue > 0
                    ? (opponentScore / duel.targetValue).clamp(0.0, 1.0)
                    : 0.0;

                final bool iAmLeading = myScore >= opponentScore;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              duel.typeLabel,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Chip(
                              label: Text(iAmLeading ? 'Vous menez 👑' : 'Meneur: $opponentName'),
                              backgroundColor: iAmLeading
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              labelStyle: TextStyle(
                                  color: iAmLeading
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (duel.wager.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Gage 🏆 : ${duel.wager}',
                              style: const TextStyle(
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                        const SizedBox(height: 14),

                        // BARRE DE PROGRESSION VS
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Moi : ${myScore.toInt()} ${duel.unit}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: myPercent,
                                    color: Colors.teal,
                                    backgroundColor: Colors.teal.shade50,
                                    minHeight: 8,
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text('VS',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Colors.red)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('$opponentName : ${opponentScore.toInt()} ${duel.unit}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: opponentPercent,
                                    color: Colors.orange,
                                    backgroundColor: Colors.orange.shade50,
                                    minHeight: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Fin du duel le ${DateFormat('d MMM à HH:mm', 'fr_FR').format(duel.endDate)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            // DUELS TERMINÉS
            if (finishedDuels.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '🏁 Duels Terminés',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...finishedDuels.map((duel) {
                final bool iWon = duel.winnerUid == widget.socialService.userId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          iWon ? Colors.amber : Colors.grey.shade400,
                      child: Icon(
                        iWon ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      iWon
                          ? 'Victoire contre ${duel.creatorUid == widget.socialService.userId ? duel.opponentName : duel.creatorName} ! 🎉'
                          : 'Défaite en duel',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Scores : ${duel.creatorScore.toInt()} vs ${duel.opponentScore.toInt()} • Gage : ${duel.wager}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// 3. Vue des Notifications et Succès des Amis
  Widget _buildFriendActivityFeedList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _activityFeed.length,
      itemBuilder: (context, index) {
        final activity = _activityFeed[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(Icons.workspace_premium, color: Colors.white),
            ),
            title: Text(
              '${activity.friendName} a débloqué le badge ${activity.badgeTitle}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(activity.description, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _getTimeAgo(activity.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                activity.isLiked ? Icons.favorite : Icons.favorite_border,
                color: activity.isLiked ? Colors.red : Colors.grey,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final bool wasLiked = activity.isLiked;
                setState(() {
                  activity.isLiked = !wasLiked;
                  activity.likesCount += activity.isLiked ? 1 : -1;
                });

                await widget.socialService
                    .toggleLikeOnFeed(activity.id, wasLiked);

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(activity.isLiked
                        ? 'Félicitations envoyées à ${activity.friendName} ! 👏'
                        : 'Mention J\'aime retirée.'),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
