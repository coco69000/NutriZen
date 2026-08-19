import 'package:flutter/material.dart';
import '../models/badge_model.dart';
import '../services/badge_service.dart';

class BadgesScreen extends StatefulWidget {
  final BadgeService badgeService;

  const BadgesScreen({super.key, required this.badgeService});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  BadgeCategory _selectedCategory = BadgeCategory.all;
  List<BadgeItem> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);
    final badges = await widget.badgeService.getUserBadges();
    setState(() {
      _badges = badges;
      _isLoading = false;
    });
  }

  List<BadgeItem> get _filteredBadges {
    if (_selectedCategory == BadgeCategory.all) return _badges;
    return _badges.where((b) => b.category == _selectedCategory).toList();
  }

  String _getCategoryName(BadgeCategory cat) {
    switch (cat) {
      case BadgeCategory.all: return 'Tous';
      case BadgeCategory.nutrition: return 'Nutrition';
      case BadgeCategory.fasting: return 'Jeûne';
      case BadgeCategory.activity: return 'Sport';
      case BadgeCategory.ecoScan: return 'Scanner';
      case BadgeCategory.streak: return 'Régularité';
      case BadgeCategory.social: return 'Social';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _badges.where((b) => b.isUnlocked).length;
    final totalCount = _badges.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Trophées & Badges')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Résumé Global
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vos Récompenses', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('$unlockedCount / $totalCount débloqués', style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: totalCount > 0 ? (unlockedCount / totalCount) : 0,
                            valueColor: const AlwaysStoppedAnimation(Colors.amber),
                            backgroundColor: Colors.white24,
                            strokeWidth: 6,
                          ),
                          const Icon(Icons.military_tech, color: Colors.amber, size: 24),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filtres Catégories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: BadgeCategory.values.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(_getCategoryName(cat)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Grille des Badges
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _filteredBadges.length,
                    itemBuilder: (context, index) {
                      final badge = _filteredBadges[index];
                      return _BadgeCard(badge: badge);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeItem badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: badge.isUnlocked ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: badge.isUnlocked ? BorderSide(color: badge.color.withValues(alpha: 0.6), width: 1.5) : BorderSide.none,
      ),
      color: badge.isUnlocked ? null : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: badge.isUnlocked ? badge.color.withValues(alpha: 0.15) : Colors.grey.shade300,
              child: Icon(
                badge.isUnlocked ? badge.icon : Icons.lock,
                color: badge.isUnlocked ? badge.color : Colors.grey.shade600,
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: badge.isUnlocked ? null : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const Spacer(),
            if (!badge.isUnlocked && badge.maxProgress > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: LinearProgressIndicator(
                  value: badge.currentProgress / badge.maxProgress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(badge.color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
