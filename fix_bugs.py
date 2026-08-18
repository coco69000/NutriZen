import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

old_func_pattern = re.compile(r'  Map<String, dynamic> _getGoalAdherence\(\) \{.*?    \};\n  \}', re.DOTALL)

new_func = '''  Map<String, dynamic> _getGoalAdherence() {
    double percentage = 0.0;
    String message = "Commencez à suivre vos données pour voir votre progression !";
    bool goalReached = false;

    if (widget.userProfile != null && widget.userProfile!.goalHistory.isNotEmpty) {
      final currentGoal = widget.userProfile!.goalHistory.lastWhereOrNull(
        (g) => g.status == GoalStatus.inProgress,
      );

      if (currentGoal != null) {
        double currentWeight = widget.userProfile!.weight;
        
        if (widget.allWeightEntries.isNotEmpty) {
          final sortedEntries = List<WeightEntry>.from(widget.allWeightEntries)
            ..sort((a, b) => a.date.compareTo(b.date));
          currentWeight = sortedEntries.last.weight;
        }

        final startWeight = currentGoal.startWeight;
        final targetWeight = currentGoal.targetWeight;

        if (currentGoal.goalType == 'lose') {
          if (startWeight > targetWeight) {
            percentage = ((startWeight - currentWeight) / (startWeight - targetWeight) * 100).clamp(0, 100).toDouble();
          }
          if (currentWeight <= targetWeight) goalReached = true;
        } else if (currentGoal.goalType == 'gain') {
          if (targetWeight > startWeight) {
            percentage = ((currentWeight - startWeight) / (targetWeight - startWeight) * 100).clamp(0, 100).toDouble();
          }
          if (currentWeight >= targetWeight) goalReached = true;
        } else {
          final diff = (currentWeight - targetWeight).abs();
          percentage = (100 - (diff * 10)).clamp(0, 100).toDouble(); // 1kg d'écart = 90%
          
          if (percentage >= 90) {
            message = "Équilibre parfait ! Vous maintenez votre poids idéal.";
          } else {
            message = "Attention, vous vous éloignez de votre zone de maintien.";
          }
          goalReached = false; 
        }

        if (goalReached && currentGoal.goalType != 'maintain') {
          message = "🎉 Félicitations ! Objectif atteint !";
          percentage = 100.0;
        } else if (currentGoal.goalType != 'maintain') {
          if (percentage >= 85) {
            message = "Excellent ! Vous êtes très proche de votre objectif final.";
          } else if (percentage >= 50) {
            message = "Vous avez fait plus de la moitié du chemin. Continuez !";
          } else if (percentage > 0) {
            message = "Vous êtes sur la bonne voie. Restez motivé !";
          }
        }
      }
    }

    return {
      'percentage': percentage,
      'delayDays': 0,
      'message': message,
      'goalReached': goalReached,
    };
  }'''

new_text = old_func_pattern.sub(new_func, text)

# Replace UserProfile finalProfile in onboarding_flow_screen.dart
with open('lib/onboarding_flow_screen.dart', 'r', encoding='utf-8') as f:
    onboarding_text = f.read()

old_profile_pattern = re.compile(r'(          final UserProfile finalProfile = UserProfile\([\s\S]*?\n          \);)', re.MULTILINE)

new_profile = '''          final initialGoalEntry = GoalHistoryEntry(
            goalType: widget.onboardingData['weightGoalType'],
            startWeight: widget.onboardingData['weight'],
            targetWeight: widget.onboardingData['targetWeight'] ?? widget.onboardingData['weight'],
            startDate: DateTime.now(),
            status: GoalStatus.inProgress,
          );

          final UserProfile finalProfile = UserProfile(
            firstName: _firstName,
            lastName: _lastName,
            email: _email,
            age: widget.onboardingData['age'],
            weight: widget.onboardingData['weight'],
            height: widget.onboardingData['height'],
            gender: widget.onboardingData['gender'],
            activityLevel: widget.onboardingData['activityLevel'],
            physicalCondition: widget.onboardingData['physicalCondition'],
            fastingExperience: widget.onboardingData['fastingExperience'],
            dietaryPreferences: List<String>.from(widget.onboardingData['dietaryPreferences']),
            healthConditions: List<String>.from(widget.onboardingData['healthConditions']),
            sleepHours: widget.onboardingData['sleepHours'],
            stressLevel: widget.onboardingData['stressLevel'],
            mainMotivation: widget.onboardingData['mainMotivation'],
            dietQuality: widget.onboardingData['dietQuality'],
            planStrictness: initialStrictness,
            likesCooking: widget.onboardingData['likesCooking'],
            cookingFrequency: widget.onboardingData['cookingFrequency'],
            targetMuscleGain: targetMuscleGain,
            targetWater: targetWater,
            goalHistory: [initialGoalEntry],
          );'''

new_onboarding_text = old_profile_pattern.sub(new_profile.replace('\\', '\\\\'), onboarding_text)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(new_text)

with open('lib/onboarding_flow_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_onboarding_text)

print("Done")
