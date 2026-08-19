// File: screens/ranking_tab.dart
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/ranking_models.dart';
import '../services/ranking_service.dart';
import 'public_profile_screen.dart';
import 'widgets/evolution_arrow.dart';

enum RankingScope { friends, country, world }

class RankingTab extends StatefulWidget {
  final RankingService rankingService;
  final String myUid;
  final String myCountryCode;
  final List<String> friendIds;
  final bool initialFriendsVisible;
  final bool initialWorldVisible;
  final void Function(bool friendsVisible, bool worldVisible)? onVisibilityChanged;
  final Future<void> Function()? onStatsPublished;

  const RankingTab({
    super.key,
    required this.rankingService,
    required this.myUid,
    required this.myCountryCode,
    required this.friendIds,
    required this.initialFriendsVisible,
    required this.initialWorldVisible,
    this.onVisibilityChanged,
    this.onStatsPublished,
  });

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  RankingScope _scope = RankingScope.friends;
  late bool _friendsVisible;
  late bool _worldVisible;
  bool _loading = true;
  LeaderboardResult? _result;

  @override
  void initState() {
    super.initState();
    _friendsVisible = widget.initialFriendsVisible;
    _worldVisible = widget.initialWorldVisible;
    _load();
  }

  @override
  void didUpdateWidget(covariant RankingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friendIds.length != widget.friendIds.length) _load();
  }

  bool get _scopeVisible =>
      _scope == RankingScope.friends ? _friendsVisible : _worldVisible;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      LeaderboardResult result;
      switch (_scope) {
        case RankingScope.friends:
          result = await widget.rankingService.getFriendsLeaderboard(widget.friendIds);
          break;
        case RankingScope.country:
          result = await widget.rankingService.getCountryLeaderboard(widget.myCountryCode);
          break;
        case RankingScope.world:
          result = await widget.rankingService.getWorldLeaderboard();
          break;
      }
      if (mounted) setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyVisibility(bool friends, bool world) async {
    setState(() {
      _friendsVisible = friends;
      _worldVisible = world;
    });
    await widget.rankingService.setVisibility(friends: friends, world: world);
    widget.onVisibilityChanged?.call(friends, world);
    if (friends || world) await widget.onStatsPublished?.call();
    _load();
  }

  void _enableCurrentScope() {
    if (_scope == RankingScope.friends) {
      _applyVisibility(true, _worldVisible);
    } else {
      _applyVisibility(_friendsVisible, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMinimalistBar(),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : !_scopeVisible
                  ? _buildLockedView()
                  : _buildLeaderboard(),
        ),
      ],
    );
  }

  /// Barre unifiée et minimaliste regroupant la portée et les toggles de visibilité
  Widget _buildMinimalistBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        children: [
          // 1. Sélecteur de portée (Amis / Pays / Monde)
          Row(
            children: [
              Expanded(child: _scopeButton(RankingScope.friends, '👥 Amis')),
              const SizedBox(width: 6),
              Expanded(child: _scopeButton(RankingScope.country, '${widget.myCountryCode.flagEmoji} Pays')),
              const SizedBox(width: 6),
              Expanded(child: _scopeButton(RankingScope.world, '🌍 Monde')),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Visibilité discrète (Badges cliquables minimalistes)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Visibilité :',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              _minimalVisibilityToggle(
                label: 'Amis',
                isActive: _friendsVisible,
                onTap: () => _applyVisibility(!_friendsVisible, _worldVisible),
              ),
              const SizedBox(width: 6),
              _minimalVisibilityToggle(
                label: 'Public',
                isActive: _worldVisible,
                onTap: () => _applyVisibility(_friendsVisible, !_worldVisible),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _minimalVisibilityToggle({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.teal.shade900.withValues(alpha: 0.4) : Colors.teal.shade50)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Theme.of(context).primaryColor
                : (isDark ? const Color(0xFF333333) : Colors.grey.shade300),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.visibility : Icons.visibility_off,
              size: 13,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? Theme.of(context).primaryColor
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeButton(RankingScope scope, String label) {
    final selected = _scope == scope;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (_scope != scope) {
          setState(() => _scope = scope);
          _load();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor
              : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
            color: selected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedView() {
    final random = Random(42);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Column(
                children: List.generate(
                    6,
                    (i) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey.shade400,
                                  child: Text('${i + 1}')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      width: double.infinity,
                                      height: 12,
                                      color: Colors.grey.shade400),
                                  const SizedBox(height: 6),
                                  Container(
                                      width:
                                          120 + random.nextInt(60).toDouble(),
                                      height: 10,
                                      color: Colors.grey.shade300),
                                ],
                              )),
                              Text('${900 - i * 80} pts',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600)),
                            ],
                          ),
                        )),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 44, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text('Classement Masqué',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _scope == RankingScope.friends
                          ? 'Activez la visibilité Amis pour participer.'
                          : 'Activez la visibilité Publique pour participer.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _enableCurrentScope,
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Rendre visible'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    final entries = _result?.entries ?? [];
    final me = _result?.me;
    final meNotInList = me != null && !entries.any((e) => e.uid == widget.myUid);

    if (entries.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _scope == RankingScope.friends
              ? 'Aucun ami n\'a encore activé ce classement.'
              : 'Personne n\'a encore rejoint ce classement.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ));
    }

    return Column(
      children: [
        if (_result?.myRank != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).colorScheme.secondary
              ]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Votre rang : ${_result!.myRank}ᵉ',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(width: 10),
                if (me?.scoreEvolution != null)
                  EvolutionArrow(evolution: me!.scoreEvolution, fontSize: 12),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
            itemCount: entries.length + (meNotInList ? 2 : 0),
            itemBuilder: (context, index) {
              if (meNotInList && index == entries.length) {
                return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                        child: Text('⋯',
                            style: TextStyle(fontSize: 20, color: Colors.grey))));
              }
              if (meNotInList && index == entries.length + 1) {
                return _entryCard(me, 0, forcedRankText: '#${_result?.myRank}');
              }
              return _entryCard(entries[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _entryCard(RankingEntry entry, int index, {String? forcedRankText}) {
    final isMe = entry.uid == widget.myUid;
    final rankText = forcedRankText ?? '#${index + 1}';
    final level = RankLevel.fromScore(entry.score);

    Color? medalColor;
    if (forcedRankText == null) {
      if (index == 0) medalColor = Colors.amber;
      if (index == 1) medalColor = Colors.grey.shade400;
      if (index == 2) medalColor = Colors.brown;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMe
            ? BorderSide(color: Theme.of(context).primaryColor, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicUserProfileScreen(
                  uid: entry.uid,
                  myUid: widget.myUid,
                  rankingService: widget.rankingService),
            )),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: medalColor ?? Colors.grey.shade200,
          child: medalColor != null
              ? const Icon(Icons.emoji_events, color: Colors.white, size: 18)
              : Text(rankText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(
              isMe ? '${entry.displayName} (moi)' : entry.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isMe ? FontWeight.bold : FontWeight.w600),
            )),
            const SizedBox(width: 6),
            Text(entry.countryCode.flagEmoji, style: const TextStyle(fontSize: 14)),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                '🔥 ${entry.streak}j • 🏆 ${entry.badgesUnlocked} • 🎯 ${entry.goalProgress.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            EvolutionArrow(evolution: entry.scoreEvolution, fontSize: 11),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${entry.score.toStringAsFixed(0)} pts',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).primaryColor)),
            Text('${level.emoji} Niv. ${level.level}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
