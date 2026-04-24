import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/service_locator.dart';
import '../../services/exercise_library_service.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final Function(String description, double caloriesBurned, int durationMinutes, String activityType) onAddActivity;

  const ExerciseLibraryScreen({super.key, required this.onAddActivity});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ExerciseItem> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    await SL.exerciseLibrary.fetchExercises();
    _updateSearch('');
    setState(() => _isLoading = false);
  }

  void _updateSearch(String query) {
    setState(() {
      _exercises = SL.exerciseLibrary.search(query);
    });
  }

  Future<void> _showAddActivityDialog(BuildContext context, ExerciseItem exercise) async {
    final durationController = TextEditingController(text: '10');
    final intensityController = TextEditingController(text: 'Moyenne');
    final kcalController = TextEditingController();

    // Default weight
    const double userWeight = 70.0;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return AlertDialog(
              title: Text('Ajouter ${exercise.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: durationController,
                      decoration: const InputDecoration(labelText: 'Durée (minutes)'),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButtonFormField<String>(
                      value: intensityController.text,
                      items: ['Faible', 'Moyenne', 'Élevée'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) setStateBuilder(() => intensityController.text = val);
                      },
                      decoration: const InputDecoration(labelText: 'Intensité'),
                    ),
                    TextField(
                      controller: kcalController,
                      decoration: const InputDecoration(labelText: 'Kcal brulées (optionnel)'),
                      keyboardType: TextInputType.number,
                      autofocus: false,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final duration = int.tryParse(durationController.text) ?? 10;
                    double? kcal = double.tryParse(kcalController.text);
                    
                    if (kcal == null) {
                      double met = 5.0; // Moyenne
                      if (intensityController.text == 'Faible') met = 3.5;
                      else if (intensityController.text == 'Élevée') met = 6.0;
                      kcal = met * userWeight * (duration / 60.0);
                    }

                    widget.onAddActivity(exercise.name, kcal, duration, 'Musculation');
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${exercise.name} ajouté ! (${kcal.toStringAsFixed(0)} kcal)')),
                    );
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque d\'exercices'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, muscle, matériel)...',
                fillColor: Theme.of(context).colorScheme.surfaceBright,
                filled: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _updateSearch,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return ExerciseCard(
                  exercise: exercise,
                  onAdd: () => _showAddActivityDialog(context, exercise),
                );
              },
            ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  final ExerciseItem exercise;
  final VoidCallback? onAdd;

  const ExerciseCard({super.key, required this.exercise, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final imageUrl0 = exercise.getImageUrl(0);
    final imageUrl1 = exercise.getImageUrl(1);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: imageUrl0.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl0,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.fitness_center),
                ),
              )
            : const Icon(Icons.fitness_center, size: 50),
        title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${exercise.primaryMuscles.join(', ')} • ${exercise.level}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl1.isNotEmpty || imageUrl0.isNotEmpty) ...[
                  AnimatedExerciseImage(imageUrl0: imageUrl0, imageUrl1: imageUrl1),
                  const SizedBox(height: 16),
                ],
                if (exercise.force != null) ...[
                  Text('Force: ${exercise.force}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                ],
                if (exercise.mechanic != null) ...[
                  Text('Mécanique: ${exercise.mechanic}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                ],
                if (exercise.equipment != null) ...[
                  Text('Matériel: ${exercise.equipment}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                ],
                const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...exercise.instructions.map((i) => Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('• $i', style: const TextStyle(fontSize: 14)),
                    )),
                const SizedBox(height: 16),
                if (onAdd != null)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.check),
                      label: const Text("J'ai terminé"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedExerciseImage extends StatefulWidget {
  final String imageUrl0;
  final String imageUrl1;
  final double? width;
  final double? height;

  const AnimatedExerciseImage({
    super.key, 
    required this.imageUrl0, 
    required this.imageUrl1,
    this.width,
    this.height,
  });

  @override
  State<AnimatedExerciseImage> createState() => _AnimatedExerciseImageState();
}

class _AnimatedExerciseImageState extends State<AnimatedExerciseImage> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = _currentIndex == 0 ? 1 : 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl0.isEmpty && widget.imageUrl1.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
      );
    }
    List<String> images = [];
    if (widget.imageUrl0.isNotEmpty) images.add(widget.imageUrl0);
    if (widget.imageUrl1.isNotEmpty) images.add(widget.imageUrl1);

    int idx = images.length > 1 ? _currentIndex : 0;
    String currentUrl = images[idx];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800), // Transition douce
        child: Image.network(
          currentUrl,
          key: ValueKey<String>(currentUrl),
          height: widget.height ?? 150,
          width: widget.width ?? double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => SizedBox(
            height: widget.height ?? 150, 
            width: widget.width ?? double.infinity,
            child: const Center(child: Icon(Icons.image_not_supported))
          ),
        ),
      ),
    );
  }
}