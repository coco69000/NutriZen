import 'notification_service.dart';
import 'long_term_memory_service.dart';

class ExpertSystemService {
  final NotificationService _notificationService;
  final LongTermMemoryService _memoryService;

  ExpertSystemService(this._notificationService, this._memoryService);

  // 1. Analyse "Just-in-Time": Prévention Glycémique
  Future<void> analyzeMealForSpike(double carbsGrams) async {
    // Si le repas contient beaucoup de glucides (ex: > 70g)
    if (carbsGrams > 70.0) {
      bool adviceAlreadyGiven = await _memoryService.hasReceivedAdviceRecently('carb_spike_walk');
      
      if (!adviceAlreadyGiven) {
        await _notificationService.showInstantNotification(
          id: 1,
          title: "Alerte Glycémie 📈",
          body: "Ce repas est riche en glucides. Que diriez-vous d'une marche de 15 minutes pour stabiliser votre énergie ?",
        );
        await _memoryService.recordAdvice('carb_spike_walk');
      }
    }
  }

  // 2. Analyse de la Densité Nutritionnelle (Micronutriments virtuels)
  Future<void> evaluateDailyNutrition(double currentIronPercent, double currentMagnesiumPercent) async {
    if (currentIronPercent < 60.0) {
      await _notificationService.showInstantNotification(
        id: 2,
        title: "Carence détectée 🥬",
        body: "Vos calories sont bonnes, mais il manque du fer (-40%). Pensez à ajouter des épinards ou des lentilles au dîner.",
      );
    }
    if (currentMagnesiumPercent < 60.0) {
      await _notificationService.showInstantNotification(
        id: 3,
        title: "Magnésium faible ⚡",
        body: "Votre apport en magnésium est bas. Un peu d'amandes ou de graines de courge peut aider.",
      );
    }
  }

  // 3. TDEE Dynamique : Analyse si le métabolisme s'est adapté
  String? evaluateMetabolicAdaptation(double weightChangeWeekly, double averageCaloricDeficit) {
    if (averageCaloricDeficit < -400 && weightChangeWeekly > -0.1) {
      return "⚠️ Votre perte de poids stagne malgré un déficit théorique. "
             "Votre métabolisme (TDEE) s'est probablement adapté à la baisse. "
             "IA suggère : Baissez votre TDEE de 10% ou faites une 'pause diététique' d'une semaine au maintien.";
    }
    return null;
  }

  // 3. Ajustement Dynamique du Programme de Jeûne Intermittent
  Future<void> adjustFastingWindow(bool isIntenseWorkoutScheduled) async {
    if (isIntenseWorkoutScheduled) {
      bool accepted = await _memoryService.hasUserAcceptedAdvice('adjust_fasting_workout');
      
      if (accepted || !(await _memoryService.hasReceivedAdviceRecently('adjust_fasting_workout'))) {
        await _notificationService.showInstantNotification(
          id: 3,
          title: "Ajustement du Jeûne ⏱️",
          body: "Activité intense détectée. Nous vous conseillons de rompre votre jeûne 1h plus tôt pour la récupération musculaire.",
        );
        await _memoryService.recordAdvice('adjust_fasting_workout');
      }
    }
  }

  // 4. IA Prédictive de Craquage (Ex: Vendredi soir)
  Future<void> predictiveCravingSupport() async {
    final now = DateTime.now();
    // Si c'est vendredi après-midi (ex: 15h)
    if (now.weekday == DateTime.friday && now.hour == 15) {
      // Vérifier si l'utilisateur a l'habitude de craquer le vendredi (stocké en mémoire)
      bool usuallyOvereats = await _memoryService.doesOvereatOnFridays();
      
      if (usuallyOvereats) {
        await _notificationService.showInstantNotification(
          id: 4,
          title: "Anticipez le week-end ! 🍕",
          body: "Le vendredi soir est souvent difficile. Essayez notre recette de Pizza Healthy pour vous faire plaisir sans culpabiliser.",
        );
      }
    }
  }

  /// 5. Détection de plateau métabolique (Famine Métabolique)
  Future<String?> evaluateMetabolicAdaptationDetailed({
    required List<double> recentWeights, // Poids des 3 dernières semaines
    required double averageCaloricDeficit, // ex: -500 kcal
  }) async {
    if (recentWeights.length < 3) return null;

    // Calcul de la variation de poids sur 3 semaines
    double totalWeightLoss = recentWeights.first - recentWeights.last;

    // Si l'utilisateur est en déficit marqué (< -350 kcal) mais perd moins de 100g sur 3 semaines
    if (averageCaloricDeficit < -350 && totalWeightLoss < 0.1) {
      bool alreadyAdvised = await _memoryService.hasReceivedAdviceRecently('diet_break_advice', thresholdHours: 72);
      if (!alreadyAdvised) {
        await _notificationService.showInstantNotification(
          id: 10,
          title: "Plateau Métabolique Détecté 🛑",
          body: "Votre poids stagne malgré votre rigueur. L'IA vous conseille 1 semaine au maintien calorique (Diet Break) pour relancer votre leptine.",
        );
        await _memoryService.recordAdvice('diet_break_advice');
      }
      return "Plateau métabolique détecté : votre organisme s'est adapté à la baisse. Prévoyez 5 à 7 jours au maintien calorique pour relancer la perte.";
    }
    return null;
  }

  /// 6. Intelligence Comportementale : Prédiction des craquages croisant sommeil & vendredi soir
  Future<void> evaluateBehavioralRisk({required int sleepHours}) async {
    final now = DateTime.now();

    // 1. Risque lié au manque de sommeil (< 6h)
    if (sleepHours < 6) {
      bool notified = await _memoryService.hasReceivedAdviceRecently('sleep_craving_alert', thresholdHours: 12);
      if (!notified) {
        await _notificationService.showInstantNotification(
          id: 21,
          title: "Fatigue & Appétit ⚡",
          body: "Avec moins de 6h de sommeil, la ghréline (hormone de la faim) augmente de 20%. Privilégiez les protéines et fibres pour éviter les fringales aujourd'hui !",
        );
        await _memoryService.recordAdvice('sleep_craving_alert');
      }
    }

    // 2. Prévention du vendredi soir (17h00-19h00)
    if (now.weekday == DateTime.friday && now.hour >= 17 && now.hour <= 19) {
      bool alreadySent = await _memoryService.hasReceivedAdviceRecently('friday_craving_alert', thresholdHours: 24);
      if (!alreadySent) {
        await _notificationService.showInstantNotification(
          id: 22,
          title: "Anticipez votre soirée ! 🍕",
          body: "Le vendredi soir est propice aux excès. Découvrez nos recettes réconfortantes et saines dans l'onglet Menus & IA !",
        );
        await _memoryService.recordAdvice('friday_craving_alert');
      }
    }
  }
}
