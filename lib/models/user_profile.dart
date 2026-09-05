import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum GoalStatus { inProgress, achieved, failed }

class GoalHistoryEntry {
  final String id;
  final String goalType;
  final double startWeight;
  final double targetWeight;
  final DateTime startDate;
  final DateTime? endDate;
  final GoalStatus status;

  GoalHistoryEntry({
    String? id,
    required this.goalType,
    required this.startWeight,
    required this.targetWeight,
    required this.startDate,
    this.endDate,
    this.status = GoalStatus.inProgress,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'goalType': goalType,
    'startWeight': startWeight,
    'targetWeight': targetWeight,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'status': status.name,
  };

  factory GoalHistoryEntry.fromMap(Map<String, dynamic> map) => GoalHistoryEntry(
    id: map['id'],
    goalType: map['goalType'] ?? 'maintain',
    startWeight: (map['startWeight'] as num?)?.toDouble() ?? 70.0,
    targetWeight: (map['targetWeight'] as num?)?.toDouble() ?? 70.0,
    startDate: (map['startDate'] as Timestamp).toDate(),
    endDate: map['endDate'] != null ? (map['endDate'] as Timestamp).toDate() : null,
    status: GoalStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => GoalStatus.inProgress,
    ),
  );
}

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

  DailyGoal copyWith({
    int? targetCalories,
    double? targetProteins,
    double? targetCarbs,
    double? targetFats,
    double? targetWeight,
    String? weightGoalType,
    double? targetWater,
    Duration? targetFastingDuration,
    double? targetMuscleGain,
    double? weeklyEnergyExpenditureGoal,
  }) {
    return DailyGoal(
      targetCalories: targetCalories ?? this.targetCalories,
      targetProteins: targetProteins ?? this.targetProteins,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFats: targetFats ?? this.targetFats,
      targetWeight: targetWeight ?? this.targetWeight,
      weightGoalType: weightGoalType ?? this.weightGoalType,
      targetWater: targetWater ?? this.targetWater,
      targetFastingDuration: targetFastingDuration ?? this.targetFastingDuration,
      targetMuscleGain: targetMuscleGain ?? this.targetMuscleGain,
      weeklyEnergyExpenditureGoal: weeklyEnergyExpenditureGoal ?? this.weeklyEnergyExpenditureGoal,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'targetCalories': targetCalories,
    'targetProteins': targetProteins,
    'targetCarbs': targetCarbs,
    'targetFats': targetFats,
    'targetWeight': targetWeight,
    'weightGoalType': weightGoalType,
    'targetWater': targetWater,
    'targetFastingDurationSeconds': targetFastingDuration?.inSeconds,
    'targetMuscleGain': targetMuscleGain,
    'weeklyEnergyExpenditureGoal': weeklyEnergyExpenditureGoal,
  };

  factory DailyGoal.fromFirestore(Map<String, dynamic> json, String docId) => DailyGoal(
    targetCalories: json['targetCalories'] ?? 2000,
    targetProteins: (json['targetProteins'] as num?)?.toDouble() ?? 100.0,
    targetCarbs: (json['targetCarbs'] as num?)?.toDouble() ?? 200.0,
    targetFats: (json['targetFats'] ?? json['fats'] as num?)?.toDouble() ?? 60.0,
    targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 70.0,
    weightGoalType: json['weightGoalType'] ?? 'maintain',
    targetWater: (json['targetWater'] as num?)?.toDouble() ?? 2.0,
    targetFastingDuration: json['targetFastingDurationSeconds'] != null
        ? Duration(seconds: json['targetFastingDurationSeconds'])
        : const Duration(hours: 16),
    targetMuscleGain: (json['targetMuscleGain'] as num?)?.toDouble(),
    weeklyEnergyExpenditureGoal: (json['weeklyEnergyExpenditureGoal'] as num?)?.toDouble(),
  );
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
  List<String> availableEquipment;
  bool gymMode;
  List<GoalHistoryEntry> goalHistory;
  String countryCode;
  bool friendsRankingVisible;
  bool worldRankingVisible;

  UserProfile({
    String? id,
    this.firstName,
    this.lastName,
    this.email,
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.activityLevel,
    this.physicalCondition = 'mince',
    this.fastingExperience = 'beginner',
    this.dietaryPreferences = const [],
    this.healthConditions = const [],
    this.mealsPerDay = 3,
    this.dietQuality = 'moyenne',
    this.tendsToEatSugary = false,
    this.tendsToEatSalty = false,
    this.sleepHours = 7,
    this.stressLevel = 'moderate',
    this.mainMotivation = 'health',
    this.planStrictness = 3,
    this.likesCooking = 'likes',
    this.cookingFrequency = 'few_times_week',
    this.likedSports = '',
    this.dislikedSports = '',
    this.bodyFatPercentage,
    this.availableEquipment = const [],
    this.gymMode = false,
    this.goalHistory = const [],
    this.countryCode = 'FR',
    this.friendsRankingVisible = false,
    this.worldRankingVisible = false,
  }) : id = id ?? const Uuid().v4();

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  double get bmi {
    if (height <= 0) return 0;
    return weight / ((height / 100) * (height / 100));
  }

  double? get ffmi {
    if (bodyFatPercentage == null || height <= 0) return null;
    double leanMass = weight * (1 - (bodyFatPercentage! / 100));
    return leanMass / ((height / 100) * (height / 100));
  }

  double? get leanBodyMass {
    if (bodyFatPercentage == null) return null;
    return weight * (1 - (bodyFatPercentage! / 100));
  }

  String get bmiCategory {
    final imcValue = bmi;
    if (imcValue <= 0) return "Données invalides";
    if (imcValue < 18.5) return "Maigreur";
    if (imcValue < 25) return "Poids normal";
    if (imcValue < 30) return "Surpoids";
    if (imcValue < 35) return "Obésité modérée (Classe I)";
    if (imcValue < 40) return "Obésité sévère (Classe II)";
    return "Obésité morbide (Classe III)";
  }

  bool get isUnderweight => bmi < 18.5;
  bool get isOverweight => bmi >= 25;
  bool get isObese => bmi >= 30;

  double get minNormalWeight => height <= 0 ? 0 : 18.5 * (height / 100) * (height / 100);
  double get maxNormalWeight => height <= 0 ? 0 : 24.9 * (height / 100) * (height / 100);

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    int? age,
    double? weight,
    double? height,
    String? gender,
    String? activityLevel,
    String? physicalCondition,
    String? fastingExperience,
    List<String>? dietaryPreferences,
    List<String>? healthConditions,
    int? mealsPerDay,
    String? dietQuality,
    bool? tendsToEatSugary,
    bool? tendsToEatSalty,
    int? sleepHours,
    String? stressLevel,
    String? mainMotivation,
    int? planStrictness,
    String? likesCooking,
    String? cookingFrequency,
    String? likedSports,
    String? dislikedSports,
    double? bodyFatPercentage,
    List<String>? availableEquipment,
    bool? gymMode,
    List<GoalHistoryEntry>? goalHistory,
    String? countryCode,
    bool? friendsRankingVisible,
    bool? worldRankingVisible,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      physicalCondition: physicalCondition ?? this.physicalCondition,
      fastingExperience: fastingExperience ?? this.fastingExperience,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      healthConditions: healthConditions ?? this.healthConditions,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      dietQuality: dietQuality ?? this.dietQuality,
      tendsToEatSugary: tendsToEatSugary ?? this.tendsToEatSugary,
      tendsToEatSalty: tendsToEatSalty ?? this.tendsToEatSalty,
      sleepHours: sleepHours ?? this.sleepHours,
      stressLevel: stressLevel ?? this.stressLevel,
      mainMotivation: mainMotivation ?? this.mainMotivation,
      planStrictness: planStrictness ?? this.planStrictness,
      likesCooking: likesCooking ?? this.likesCooking,
      cookingFrequency: cookingFrequency ?? this.cookingFrequency,
      likedSports: likedSports ?? this.likedSports,
      dislikedSports: dislikedSports ?? this.dislikedSports,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      gymMode: gymMode ?? this.gymMode,
      goalHistory: goalHistory ?? this.goalHistory,
      countryCode: countryCode ?? this.countryCode,
      friendsRankingVisible: friendsRankingVisible ?? this.friendsRankingVisible,
      worldRankingVisible: worldRankingVisible ?? this.worldRankingVisible,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'firstName': firstName,
    'lastName': lastName,
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
    if (bodyFatPercentage != null) 'bodyFatPercentage': bodyFatPercentage,
    'availableEquipment': availableEquipment,
    'gymMode': gymMode,
    'goalHistory': goalHistory.map((e) => e.toMap()).toList(),
    'countryCode': countryCode,
    'privacyFriends': friendsRankingVisible,
    'privacyWorld': worldRankingVisible,
    'displayName': fullName,
  };

  factory UserProfile.fromFirestore(Map<String, dynamic> json, String docId) =>
      UserProfile(
        id: json['id'] ?? docId,
        firstName: json['firstName'],
        lastName: json['lastName'],
        age: json['age'] ?? 25,
        weight: (json['weight'] as num?)?.toDouble() ?? 70.0,
        height: (json['height'] as num?)?.toDouble() ?? 170.0,
        gender: json['gender'] ?? 'male',
        activityLevel: json['activityLevel'] ?? 'moderate',
        physicalCondition: json['physicalCondition'] ?? 'mince',
        fastingExperience: json['fastingExperience'] ?? 'beginner',
        dietaryPreferences: List<String>.from(json['dietaryPreferences'] ?? []),
        healthConditions: List<String>.from(json['healthConditions'] ?? []),
        availableEquipment: List<String>.from(json['availableEquipment'] ?? []),
        gymMode: json['gymMode'] ?? false,
        mealsPerDay: json['mealsPerDay'] ?? 3,
        dietQuality: json['dietQuality'] ?? 'moyenne',
        tendsToEatSugary: json['tendsToEatSugary'] ?? false,
        tendsToEatSalty: json['tendsToEatSalty'] ?? false,
        sleepHours: json['sleepHours'] ?? 7,
        stressLevel: json['stressLevel'] ?? 'moderate',
        mainMotivation: json['mainMotivation'] ?? 'health',
        planStrictness: json['planStrictness'] ?? 3,
        likesCooking: json['likesCooking'] ?? 'likes',
        cookingFrequency: json['cookingFrequency'] ?? 'few_times_week',
        likedSports: json['likedSports'] ?? '',
        dislikedSports: json['dislikedSports'] ?? '',
        bodyFatPercentage: (json['bodyFatPercentage'] as num?)?.toDouble(),
        goalHistory: (json['goalHistory'] as List<dynamic>?)
                ?.map((e) => GoalHistoryEntry.fromMap(e))
                .toList() ?? [],
        countryCode: json['countryCode'] ?? 'FR',
        friendsRankingVisible: json['privacyFriends'] ?? false,
        worldRankingVisible: json['privacyWorld'] ?? false,
      );
}
