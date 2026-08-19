// File: screens/widgets/evolution_arrow.dart
import 'package:flutter/material.dart';
import '../../models/ranking_models.dart';

/// Widget flèche ↑↓ avec pourcentage
class EvolutionArrow extends StatelessWidget {
  final Evolution? evolution;
  final double fontSize;
  final bool invertColors; // true si une baisse est positive (ex: perte de poids)

  const EvolutionArrow({
    super.key,
    required this.evolution,
    this.fontSize = 12,
    this.invertColors = false,
  });

  @override
  Widget build(BuildContext context) {
    if (evolution == null) {
      return Text('—', style: TextStyle(fontSize: fontSize, color: Colors.grey));
    }

    final isPositive = invertColors ? !evolution!.isUp : evolution!.isUp;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = evolution!.isUp ? Icons.arrow_upward : Icons.arrow_downward;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: fontSize + 2),
        const SizedBox(width: 2),
        Text(
          '${evolution!.percent.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Badge de score avec flèche
class ScoreBadge extends StatelessWidget {
  final double score;
  final Evolution? evolution;

  const ScoreBadge({super.key, required this.score, this.evolution});

  @override
  Widget build(BuildContext context) {
    final level = RankLevel.fromScore(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(level.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            '${score.toStringAsFixed(0)} pts',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 6),
          EvolutionArrow(evolution: evolution, fontSize: 11),
        ],
      ),
    );
  }
}
