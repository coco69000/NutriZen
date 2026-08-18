import re

with open('lib/screens/activities/exercise_library_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Update constructor
text = text.replace('final Function(String description, double caloriesBurned, int durationMinutes, String activityType) onAddActivity;',
                    'final Function(String description, double caloriesBurned, int durationMinutes, String activityType) onAddActivity;\n  final double userWeight;')

text = text.replace('const ExerciseLibraryScreen({super.key, required this.onAddActivity});',
                    'const ExerciseLibraryScreen({super.key, required this.onAddActivity, required this.userWeight});')

text = text.replace('const double userWeight = 70.0;',
                    'final double userWeight = widget.userWeight;')

with open('lib/screens/activities/exercise_library_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    main_text = f.read()

# Pass weight to constructor
old_builder = '''                              (context) => ExerciseLibraryScreen(
                                onAddActivity: (desc, cal, dur, type) {'''

new_builder = '''                              (context) => ExerciseLibraryScreen(
                                userWeight: widget.userProfile?.weight ?? 70.0,
                                onAddActivity: (desc, cal, dur, type) {'''

main_text = main_text.replace(old_builder, new_builder)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(main_text)
