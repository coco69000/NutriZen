import 'notification_service.dart';
import 'long_term_memory_service.dart';
import 'expert_system_service.dart';
import 'activity_service.dart';
import 'habit_service.dart';
import 'exercise_library_service.dart';
import 'ai_service.dart';
import 'usda_nlp_service.dart';

class SL {
  static final NotificationService notificationService = NotificationService();
  static final LongTermMemoryService memoryService = LongTermMemoryService();
  static final ExpertSystemService expertSystem = ExpertSystemService(notificationService, memoryService);
  static final ActivityService activityService = ActivityService();
  static final HabitService habitService = HabitService();
  static final ExerciseLibraryService exerciseLibrary = ExerciseLibraryService();
  
  static final AIService aiService = AIService();
  static AIService get mealVision => aiService; 

  static final UsdaNlpService usdaNlp = UsdaNlpService(
    apiKey: const String.fromEnvironment('USDA_API_KEY'),
  );

  static Future<void> initAll() async {
    await notificationService.init();
  }
}
