/// Comparateur de défis équitables basé sur le pourcentage de progression
class ChallengeComparator {
  /// Compare deux utilisateurs de niveaux différents sur leur pourcentage d'adhérence
  static Map<String, dynamic> calculateFairDuel({
    required double userAActualSteps,
    required double userATargetSteps,
    required double userBActualSteps,
    required double userBTargetSteps,
  }) {
    double progressA = userATargetSteps > 0 ? (userAActualSteps / userATargetSteps) * 100 : 0;
    double progressB = userBTargetSteps > 0 ? (userBActualSteps / userBTargetSteps) * 100 : 0;

    String winner = progressA >= progressB ? "Utilisateur A" : "Utilisateur B";

    return {
      'progressA': progressA.clamp(0.0, 200.0),
      'progressB': progressB.clamp(0.0, 200.0),
      'winner': winner,
      'differencePercent': (progressA - progressB).abs().toStringAsFixed(1),
    };
  }
}
