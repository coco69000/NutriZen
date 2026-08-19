class GoalHistoryEntry {
  final String id;
  final String goalType;
  final double startWeight;
  final double targetWeight;
  final DateTime startDate;
  final DateTime? endDate;
  final GoalStatus status;

  GoalHistoryEntry({
    required this.id,
    required this.goalType,
    required this.startWeight,
    required this.targetWeight,
    required this.startDate,
    this.endDate,
    this.status = GoalStatus.inProgress,
  });
}

enum GoalStatus { inProgress, achieved, failed }

class DailyGoal {
  int targetCalories;
  double targetProteins;
  double targetCarbs;
  double targetFats;
  double targetWeight;
  String weightGoalType;
  double targetWater;
  Duration? targetFastingDuration;
  double? targetMuscleGain;
  double? weeklyEnergyExpenditureGoal;

  DailyGoal({
    this.targetCalories = 2000,
    this.targetProteins = 100.0,
    this.targetCarbs = 200.0,
    this.targetFats = 60.0,
    this.targetWeight = 70.0,
    this.weightGoalType = 'maintain',
    this.targetWater = 2.0,
    this.targetFastingDuration = const Duration(hours: 16),
    this.targetMuscleGain,
    this.weeklyEnergyExpenditureGoal,
  });
}

class UserProfile {
  String id;
  String? firstName;
  String? lastName;
  String? email;
  int age;
  double weight;
  double height;
  String gender;
  String activityLevel;
  String physicalCondition;
  String fastingExperience;
  List<String> dietaryPreferences;
  List<String> healthConditions;
  int mealsPerDay;
  String dietQuality;
  bool tendsToEatSugary;
  bool tendsToEatSalty;
  int sleepHours;
  String stressLevel;
  String mainMotivation;
  int planStrictness;
  String? likesCooking;
  String? cookingFrequency;
  String likedSports;
  String dislikedSports;
  double? bodyFatPercentage;

  double? get leanBodyMass {
    if (bodyFatPercentage == null) return null;
    return weight * (1 - (bodyFatPercentage! / 100));
  }

  List<String> availableEquipment;
  bool gymMode;
  List<GoalHistoryEntry> goalHistory;
  String countryCode;
  bool friendsRankingVisible;
  bool worldRankingVisible;

  UserProfile({
    this.id = '',
    this.firstName,
    this.lastName,
    this.email,
    this.age = 30,
    this.weight = 70.0,
    this.height = 170.0,
    this.gender = 'other',
    this.activityLevel = 'moderate',
    this.physicalCondition = 'good',
    this.fastingExperience = 'beginner',
    this.dietaryPreferences = const [],
    this.healthConditions = const [],
    this.mealsPerDay = 3,
    this.dietQuality = 'moyenne',
    this.tendsToEatSugary = false,
    this.tendsToEatSalty = false,
    this.sleepHours = 8,
    this.stressLevel = 'medium',
    this.mainMotivation = '',
    this.planStrictness = 3,
    this.likesCooking,
    this.cookingFrequency,
    this.likedSports = '',
    this.dislikedSports = '',
    this.bodyFatPercentage,
    this.availableEquipment = const [],
    this.gymMode = false,
    this.goalHistory = const [],
    this.countryCode = 'FR',
    this.friendsRankingVisible = false,
    this.worldRankingVisible = false,
  });

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'age': age,
        'weight': weight,
        'height': height,
        'gender': gender,
        'activityLevel': activityLevel,
        'physicalCondition': physicalCondition,
        'fastingExperience': fastingExperience,
        'dietaryPreferences': dietaryPreferences,
        'healthConditions': healthConditions,
        'mealsPerDay': mealsPerDay,
        'dietQuality': dietQuality,
        'tendsToEatSugary': tendsToEatSugary,
        'tendsToEatSalty': tendsToEatSalty,
        'sleepHours': sleepHours,
        'stressLevel': stressLevel,
        'mainMotivation': mainMotivation,
        'planStrictness': planStrictness,
        'likesCooking': likesCooking,
        'cookingFrequency': cookingFrequency,
        'likedSports': likedSports,
        'dislikedSports': dislikedSports,
        'bodyFatPercentage': bodyFatPercentage,
        'availableEquipment': availableEquipment,
        'gymMode': gymMode,
        'countryCode': countryCode,
        'privacyFriends': friendsRankingVisible,
        'privacyWorld': worldRankingVisible,
      };
}
