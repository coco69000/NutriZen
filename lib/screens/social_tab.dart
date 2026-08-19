// File: screens/social_tab.dart
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
        title: Row(
          children: [
            Icon(Icons.person_add, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            const Text('Ajouter un ami'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrez l\'adresse e-mail ou l\'identifiant unique de votre ami pour lancer des duels et comparer vos progrès.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'E-mail ou ID utilisateur',
                prefixIcon: const Icon(Icons.alternate_email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
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
                              : 'Impossible de trouver ou d\'ajouter cet utilisateur.',
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

  void _showCreateDuelDialog({SocialFriend? preselectedFriend}) {
    if (_friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez d\'abord un ami pour pouvoir lancer un duel ! 👥'),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.sports_kabaddi, color: Colors.deepOrange),
                SizedBox(width: 10),
                Text('Nouveau Duel'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adversaire :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SocialFriend>(
                    initialValue: selectedFriend,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _friends.map((f) {
                      return DropdownMenuItem(
                        value: f,
                        child: Text(f.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedFriend = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Type d\'épreuve :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ChallengeType>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ChallengeType.steps,
                        child: Text('Marche (Nombre de Pas 🚶)'),
                      ),
                      DropdownMenuItem(
                        value: ChallengeType.calories,
                        child: Text('Sport (Calories Brûlées 🔥)'),
                      ),
                      DropdownMenuItem(
                        value: ChallengeType.water,
                        child: Text('Hydratation (Eau 💧)'),
                      ),
                      DropdownMenuItem(
                        value: ChallengeType.fasting,
                        child: Text('Jeûne (Heures ⏱️)'),
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
                    'Objectif (${selectedType.name}) :',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Durée du duel :', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  const Text('Enjeu / Gage 🏆 :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: wagerController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      hintText: 'Ex: Le perdant paie le smoothie !',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
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
                                ? 'Défi lancé à ${selectedFriend.displayName} ! 🔥'
                                : 'Erreur lors du lancement.',
                          ),
                          backgroundColor:
                              challengeId != null ? Colors.green : Colors.red,
                        ),
                      );
                    }
                    _loadSocialData();
                  }
                },
                child: const Text('Lancer le défi'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double userProgressPercent = widget.userTargetSteps > 0
        ? (widget.userCurrentSteps / widget.userTargetSteps) * 100
        : 0;

    return Scaffold(
      body: Column(
        children: [
          // ── EN-TÊTE SOCIAL ET ACTIONS RAPIDES ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
                ),
              ),
            ),
            child: Column(
              children: [
                // Boutons d'actions rapides stylisés
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text(
                          'Ajouter un ami',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _showAddFriendDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.sports_kabaddi, size: 18),
                        label: const Text(
                          'Nouveau Duel',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _showCreateDuelDialog(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Onglets en pilules arrondies
                Container(
                  height: 42,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222222) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(fontSize: 12),
                    tabs: const [
                      Tab(text: 'Comparatif'),
                      Tab(text: 'Duels'),
                      Tab(text: 'Classement'),
                      Tab(text: 'Succès'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── CONTENU DES ONGLETS ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // 1. TABLEAU DE BORD COMPARATIF
                      _buildComparativeDashboard(userProgressPercent),

                      // 2. DUELS PRIVÉS
                      _buildDuelsList(),

                      // 3. CLASSEMENT
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

                      // 4. FIL D'ACTUALITÉ & SUCCÈS
                      _buildFriendActivityFeedList(),
                    ],
                  ),
          ),
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
            // Carte Mon Résumé
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Theme.of(context).primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, size: 30, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ma Progression Actuelle',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.userCurrentSteps.toInt()} pas • ${widget.userCaloriesBurned.toInt()} kcal • ${widget.userWeight} kg',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (userProgressPercent / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.amber),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📊 Comparatif avec mes Amis',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_friends.length} ami(s)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_friends.isEmpty)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      const Icon(Icons.group_add_outlined, size: 54, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'Aucun ami pour le moment',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ajoutez vos amis pour comparer vos activités et lancer des défis hebdomadaires !',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text('Inviter un ami'),
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
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                                            fontSize: 15),
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
                              IconButton(
                                icon: const Icon(Icons.sports_kabaddi,
                                    color: Colors.deepOrange),
                                tooltip: 'Défier cet ami',
                                onPressed: () => _showCreateDuelDialog(
                                    preselectedFriend: friend),
                              ),
                              IconButton(
                                icon: const Icon(Icons.bolt, color: Colors.amber),
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
                          const Divider(height: 20),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  /// 2. Vue des Duels Privés
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
            if (pendingDuels.isNotEmpty) ...[
              const Text(
                '📨 Invitations en Attente',
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
                            const Icon(Icons.mark_email_unread, color: Colors.amber),
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
                                    await widget.socialService.acceptDuel(duel.id);
                                    _loadSocialData();
                                  },
                                  child: const Text('Accepter ⚔️'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    await widget.socialService.declineDuel(duel.id);
                                    _loadSocialData();
                                  },
                                  child: const Text('Refuser'),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text('En attente de la réponse de votre ami...',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            const Text(
              '⚔️ Duels en Cours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (activeDuels.isEmpty)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'Aucun duel actif pour l\'instant.\nCliquez sur "Nouveau Duel" ci-dessus pour vous mesurer à un ami ! 🔥',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ...activeDuels.map((duel) {
                final isCreator = duel.creatorUid == widget.socialService.userId;
                final myScore = isCreator ? duel.creatorScore : duel.opponentScore;
                final opponentScore = isCreator ? duel.opponentScore : duel.creatorScore;
                final opponentName = isCreator ? duel.opponentName : duel.creatorName;

                final myPercent = duel.targetValue > 0
                    ? (myScore / duel.targetValue).clamp(0.0, 1.0)
                    : 0.0;
                final opponentPercent = duel.targetValue > 0
                    ? (opponentScore / duel.targetValue).clamp(0.0, 1.0)
                    : 0.0;

                final bool iAmLeading = myScore >= opponentScore;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Chip(
                              label: Text(iAmLeading ? 'Vous menez 👑' : 'Meneur : $opponentName'),
                              backgroundColor: iAmLeading ? Colors.green.shade50 : Colors.orange.shade50,
                              labelStyle: TextStyle(
                                  color: iAmLeading ? Colors.green.shade800 : Colors.orange.shade800,
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
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Moi : ${myScore.toInt()} ${duel.unit}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          'Fin du duel : ${DateFormat('d MMM à HH:mm', 'fr_FR').format(duel.endDate)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }),

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
                      backgroundColor: iWon ? Colors.amber : Colors.grey.shade400,
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
    if (_activityFeed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_none, size: 50, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Aucune activité récente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Les accomplissements et trophées débloqués par vos amis apparaîtront ici !',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

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

                await widget.socialService.toggleLikeOnFeed(activity.id, wasLiked);

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
