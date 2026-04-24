import 'notification_service.dart';
import 'long_term_memory_service.dart';
import 'expert_system_service.dart';
import 'hybrid_food_database_service.dart';
import 'activity_service.dart';
import 'habit_service.dart';
import 'exercise_library_service.dart';
import 'deepseek_service.dart';

class SL {
  static final NotificationService notificationService = NotificationService();
  static final LongTermMemoryService memoryService = LongTermMemoryService();
  static final ExpertSystemService expertSystem = ExpertSystemService(notificationService, memoryService);
  static final HybridFoodDatabaseService hybridDb = HybridFoodDatabaseService();
  static final ActivityService activityService = ActivityService();
  static final HabitService habitService = HabitService();
  static final ExerciseLibraryService exerciseLibrary = ExerciseLibraryService();
  static final DeepSeekService aiService = DeepSeekService(apiKey: 'HA2RvSG1u7aE7u78yXd1UqnBuMY6VV70');

  static Future<void> initAll() async {
    await notificationService.init();
    await hybridDb.initDatabase();
  }
}
