import re

path = 'lib/onboarding_flow_screen.dart'
content = open(path, 'r', encoding='utf-8').read()
content = content.replace('color: isSelected ? Theme.of(context).primaryColor : (isDisabled ? Colors.grey.shade500 : Colors.black87)', 'color: isSelected ? Theme.of(context).primaryColor : (isDisabled ? Colors.grey.shade500 : Theme.of(context).colorScheme.onSurface)')
content = content.replace('color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : (isDisabled ? Colors.grey.shade200 : Colors.white)', 'color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : (isDisabled ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surface)')
content = content.replace('labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w500),', 'labelStyle: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),')
content = content.replace('void _nextPage(List<Widget> pages) x', 'void _nextPage(List<Widget> pages) {\n    FocusScope.of(context).unfocus();')
content = re.sub(r'(\'healthConditions\': <String>[],)', r'\1\n    \'availableEquipment\': <String>[\'none\'],\n    \'gymMode\': false,', content)
content = re.sub(r'(_buildMultiSelectChipPage\(context: context, title: "Avez-vous des conditions)', r'_buildQuestionPage(context: context, title: "Salle de sport ou maison ?", child: _buildChoiceSelector(key: \'gymMode\', options: {"Je suis à la salle de sport": true, "Je m\'entraîne à la maison": false})),\n      _buildMultiSelectChipPage(context: context, title: "Quel matériel avez-vous chez vous ?", options: [\'none\', \'dumbbells\', \'pull-up bar\', \'resistance bands\'], selected: _onboardingData[\'availableEquipment\'] ?? ]], onSelectionChanged: (selected) => setState(() => _onboardingData[\'availableEquipment\'] = selected)),\n      \1', content)
content = re.sub(r'(healthConditions: List<String>\.from(widget\.onboardingData\[\'healthConditions\'\]\),)', r'1\n          availableEquipment: List<String>.from(widget.onboardingData[\'availableEquipment\'] ?? []),\n          gymMode: widget.onboardingData[\'gymMode\'] ?? false,', content)
open(path, 'w', encoding='/tf-8').write(content)
