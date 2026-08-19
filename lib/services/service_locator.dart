import 'notification_service.dart';
import 'long_term_memory_service.dart';
import 'expert_system_service.dart';
import 'hybrid_food_database_service.dart';
import 'activity_service.dart';
import 'habit_service.dart';
import 'exercise_library_service.dart';
import 'ai_service.dart'; // NOUVEAU : Remplace deepseek_service et meal_vision_service
import 'usda_nlp_service.dart';

class SL {
  static final NotificationService notificationService = NotificationService();
  static final LongTermMemoryService memoryService = LongTermMemoryService();
  static final ExpertSystemService expertSystem = ExpertSystemService(notificationService, memoryService);
  static final HybridFoodDatabaseService hybridDb = HybridFoodDatabaseService();
  static final ActivityService activityService = ActivityService();
  static final HabitService habitService = HabitService();
  static final ExerciseLibraryService exerciseLibrary = ExerciseLibraryService();
  
  // 🧠 NOUVEAU SERVICE UNIFIÉ (Texte + Image via Qwen)
  static final AIService aiService = AIService();
  
  // 🔄 ALIAS pour ne pas casser le code existant de main.dart qui appelle SL.mealVision
  static AIService get mealVision => aiService; 

  static final UsdaNlpService usdaNlp = UsdaNlpService(
    apiKey: const String.fromEnvironment('USDA_API_KEY'),
  );

  static Future<void> initAll() async {
    await notificationService.init();
    await hybridDb.initDatabase();
  }
}
