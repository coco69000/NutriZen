import re

with open('lib/onboarding_flow_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

old_profile = '''        final UserProfile finalProfile = UserProfile(
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
          // NOUVEAU
          likesCooking: widget.onboardingData['likesCooking'],
          cookingFrequency: widget.onboardingData['cookingFrequency'],
          targetMuscleGain: targetMuscleGain,
          targetWater: targetWater, // On sauvegarde l'objectif d'eau
        );'''

new_profile = '''        final initialGoalEntry = GoalHistoryEntry(
          id: uuid.v4(),
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
          likedSports: widget.onboardingData['likedSports'] ?? '',
          dislikedSports: widget.onboardingData['dislikedSports'] ?? '',
          bodyFatPercentage: widget.onboardingData['bodyFatPercentage'],
          targetMuscleGain: targetMuscleGain,
          targetWater: targetWater,
          goalHistory: [initialGoalEntry],
        );'''

text = text.replace(old_profile, new_profile)

# Need to import uuid if not there
if "import 'package:uuid/uuid.dart';" not in text:
    text = "import 'package:uuid/uuid.dart';\n" + text

# Need to define uuid
if "final uuid = const Uuid();" not in text:
    text = text.replace('class _OnboardingAuthScreenState extends State<OnboardingAuthScreen> {', 'class _OnboardingAuthScreenState extends State<OnboardingAuthScreen> {\n  final uuid = const Uuid();')

with open('lib/onboarding_flow_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
