import re

path = 'lib/screens/activities/exercise_library_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'import "dart:async";' not in content and "import 'dart:async';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:async';")

# Fix TextField dark mode
content = content.replace('fillColor: Colors.white,', 'fillColor: Theme.of(context).colorScheme.surfaceBright,')

# Replace image code
old_image_code = '''                if (imageUrl1.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl1,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const SizedBox(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],'''

new_image_code = '''                if (imageUrl1.isNotEmpty || imageUrl0.isNotEmpty) ...[
                  AnimatedExerciseImage(imageUrl0: imageUrl0, imageUrl1: imageUrl1),
                  const SizedBox(height: 16),
                ],'''

content = content.replace(old_image_code, new_image_code)

new_widget = '''
class AnimatedExerciseImage extends StatefulWidget {
  final String imageUrl0;
  final String imageUrl1;

  const AnimatedExerciseImage({super.key, required this.imageUrl0, required this.imageUrl1});

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
      return const SizedBox();
    }
    List<String> images = [];
    if (widget.imageUrl0.isNotEmpty) images.add(widget.imageUrl0);
    if (widget.imageUrl1.isNotEmpty) images.add(widget.imageUrl1);

    int idx = images.length > 1 ? _currentIndex : 0;
    String currentUrl = images[idx];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Image.network(
          currentUrl,
          key: ValueKey<String>(currentUrl),
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const SizedBox(height: 150, child: Center(child: Icon(Icons.image_not_supported))),
        ),
      ),
    );
  }
}
'''

if 'class AnimatedExerciseImage' not in content:
    content += new_widget

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated exercise library successfully')