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
        _buildPrivacyCard(),
        _buildScopeSelector(),
        const SizedBox(height: 8),
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

  Widget _buildPrivacyCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
        child: Row(
          children: [
            Icon(Icons.visibility, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Amis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: _friendsVisible,
                      onChanged: (v) => _applyVisibility(v, _worldVisible),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mondial', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: _worldVisible,
                      onChanged: (v) => _applyVisibility(_friendsVisible, v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(child: _scopeChip(RankingScope.friends, Icons.group, 'Amis')),
          const SizedBox(width: 8),
          Expanded(
              child: _scopeChip(RankingScope.country, Icons.flag,
                  '${widget.myCountryCode.flagEmoji} Pays')),
          const SizedBox(width: 8),
          Expanded(child: _scopeChip(RankingScope.world, Icons.public, 'Monde')),
        ],
      ),
    );
  }

  Widget _scopeChip(RankingScope scope, IconData icon, String label) {
    final selected = _scope == scope;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (_scope != scope) {
          setState(() => _scope = scope);
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? Theme.of(context).primaryColor : Colors.grey.shade400),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : null),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selected ? Colors.white : null)),
          ],
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
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text('Classement verrouillé',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      _scope == RankingScope.friends
                          ? 'Activez le classement Amis pour y apparaître.'
                          : 'Activez le classement Mondial pour y apparaître.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _enableCurrentScope,
                      icon: const Icon(Icons.remove_red_eye),
                      label: const Text('Me mettre en prévisualisation'),
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
              ? 'Aucun ami n\'a encore activé le classement.'
              : 'Personne n\'a encore rejoint ce classement.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ));
    }

    return Column(
      children: [
        // Bannière mon rang
        if (_result?.myRank != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).colorScheme.secondary
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: Colors.white),
                const SizedBox(width: 8),
                Text('Votre position : ${_result!.myRank}ᵉ',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(width: 12),
                if (me?.scoreEvolution != null)
                  EvolutionArrow(evolution: me!.scoreEvolution, fontSize: 13),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
            itemCount: entries.length + (meNotInList ? 2 : 0),
            itemBuilder: (context, index) {
              if (meNotInList && index == entries.length) {
                return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: Text('⋯',
                            style:
                                TextStyle(fontSize: 24, color: Colors.grey))));
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
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isMe
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicUserProfileScreen(
                  uid: entry.uid,
                  myUid: widget.myUid,
                  rankingService: widget.rankingService),
            )),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: medalColor ?? Colors.grey.shade200,
          child: medalColor != null
              ? const Icon(Icons.emoji_events, color: Colors.white, size: 22)
              : Text(rankText,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(
              isMe ? '${entry.displayName} (moi)' : entry.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: isMe ? FontWeight.bold : FontWeight.w600),
            )),
            const SizedBox(width: 6),
            Text(entry.countryCode.flagEmoji,
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                '🔥 ${entry.streak}j • 🏅 ${entry.badgesUnlocked} • 🎯 ${entry.goalProgress.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            // Flèche d'évolution du score
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
                    color: Theme.of(context).primaryColor)),
            Text('${level.emoji} Niv. ${level.level}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
