// File: screens/public_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ranking_models.dart';
import '../services/ranking_service.dart';
import 'widgets/evolution_arrow.dart';

class PublicUserProfileScreen extends StatefulWidget {
  final String uid;
  final String myUid;
  final RankingService rankingService;

  const PublicUserProfileScreen({
    super.key,
    required this.uid,
    required this.myUid,
    required this.rankingService,
  });

  @override
  State<PublicUserProfileScreen> createState() => _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  RankingEntry? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.rankingService.getPublicProfile(widget.uid);
    if (mounted) {
      setState(() {
        _profile = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil du joueur')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? _buildLockedProfile()
              : _buildContent(),
    );
  }

  Widget _buildLockedProfile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Profil privé',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Cet utilisateur n\'a pas encore activé les classements.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    final level = RankLevel.fromScore(p.score);
    final isMe = widget.uid == widget.myUid;
    final initials = p.displayName.trim().isNotEmpty
        ? p.displayName.trim()[0].toUpperCase()
        : 'N';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ═══════════ EN-TÊTE ═══════════
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white24,
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                      child: Text(p.displayName,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(p.countryCode.flagEmoji,
                      style: const TextStyle(fontSize: 22)),
                  if (isMe) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('Moi',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  '${Countries.nameOf(p.countryCode)} • ${level.emoji} ${level.title}',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              // Score global avec flèche d'évolution
              ScoreBadge(score: p.score, evolution: p.scoreEvolution),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════ ÉVOLUTIONS ═══════════
              Text('📈 Évolutions (vs semaine dernière)',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _evolutionRow('Score global', Icons.stars,
                          p.scoreEvolution, false),
                      const Divider(),
                      _evolutionRow('Poids', Icons.monitor_weight,
                          p.weightEvolution, p.goalType == 'lose'),
                      const Divider(),
                      _evolutionRow('Activité', Icons.directions_run,
                          p.activityEvolution, false),
                      const Divider(),
                      _evolutionRow('Nutrition', Icons.restaurant,
                          p.nutritionEvolution, false),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ═══════════ STATISTIQUES ═══════════
              Text('📊 Statistiques',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _statCard('Série', '${p.streak} jours',
                        Icons.local_fire_department, Colors.orange)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statCard('Badges', '${p.badgesUnlocked}',
                        Icons.military_tech, Colors.deepPurple)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _statCard('Pas (jour)', '${p.steps}',
                        Icons.directions_walk, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statCard('IA utilisées', '${p.aiAnalyses}',
                        Icons.smart_toy, Colors.purple)),
              ]),
              const SizedBox(height: 24),

              // ═══════════ PROGRESSION OBJECTIF ═══════════
              Text('🎯 Progression de l\'objectif',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag,
                              color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(goalTypeLabelFr(p.goalType),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${p.goalProgress.toStringAsFixed(0)} %',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                            value: (p.goalProgress / 100).clamp(0.0, 1.0),
                            minHeight: 10),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.weightDelta == 0
                            ? 'Pas encore de variation enregistrée.'
                            : 'Variation : ${p.weightDelta > 0 ? '+' : ''}${p.weightDelta.toStringAsFixed(1)} kg',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ═══════════ HYDRATATION & JEÛNE ═══════════
              Row(children: [
                Expanded(
                    child: Card(
                  child: ListTile(
                    leading:
                        Icon(Icons.water_drop, color: Colors.blue.shade700),
                    title: const Text('Hydratation'),
                    subtitle: Text
                        ('${p.waterAdherence.toStringAsFixed(0)}% de l\'objectif'),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: Card(
                  child: ListTile(
                    leading: Icon(Icons.timer, color: Colors.green.shade700),
                    title: const Text('Jeûnes'),
                    subtitle: Text('${p.fastingSessions} sessions'),
                  ),
                )),
              ]),
              const SizedBox(height: 16),

              // ═══════════ DERNIÈRE ACTIVITÉ ═══════════
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.access_time, color: Colors.blueGrey),
                  title: const Text('Dernière activité'),
                  trailing: Text(
                    DateFormat('d MMM yyyy à HH:mm', 'fr_FR')
                        .format(p.lastActive),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _evolutionRow(
      String label, IconData icon, Evolution? evolution, bool invertColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          EvolutionArrow(
              evolution: evolution, fontSize: 13, invertColors: invertColors),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
