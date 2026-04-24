import re

path = 'lib/onboarding_flow_screen.dart'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Dark mode fixes
    content = content.replace('color: isSelected ? Theme.of(context).primaryColor : (isDisabled ? Colors.grey.shade500 : Colors.black87)', 'color: isSelected ? Theme.of(context).primaryColor : (isDisabled ? Colors.grey.shade500 : Theme.of(context).colorScheme.onSurface)')
    content = content.replace('color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : (isDisabled ? Colors.grey.shade200 : Colors.white)', 'color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : (isDisabled ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surface)')
    content = content.replace('labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w500),', 'labelStyle: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),')

    # Unfocus
    content = content.replace('void _nextPage(List<Widget> pages) {', 'void _nextPage(List<Widget> pages) {\n    FocusScope.of(context).unfocus();')

    # Data
    if \"'availableEquipment'\" not in content:
        content = re.sub(
            r'(\'healthConditions\': <String>\[\],)',
            r\"\1\n    'availableEquipment': <String>['none'],\n    'gymMode': false,\",
            content
        )

        content = re.sub(
            r'(_buildMultiSelectChipPage\(context: context, title: \"Avez-vous des conditions)',
            r'_buildQuestionPage(context: context, title: \"Voulez-vous activer le mode Salle de Sport ?\", child: _buildChoiceSelector(key: \'gymMode\', options: {\"Oui !\": true, \"A la maison\": false})),\n      _buildMultiSelectChipPage(context: context, title: \"Quels équipements avez-vous ?\", options: [\'none\', \'dumbbells\', \'pull-up bar\', \'resistance bands\'], selected: _onboardingData[\'availableEquipment\'], onSelectionChanged: (selected) => setState(() => _onboardingData[\'availableEquipment\'] = selected)),\n      \1',
            content
        )

        content = re.sub(
            r'(healthConditions: List<String>\.from\(widget\.onboardingData\[\'healthConditions\'\]\),)',
            r'\1\n          availableEquipment: List<String>.from(widget.onboardingData[\'availableEquipment\'] ?? []),\n          gymMode: widget.onboardingData[\'gymMode\'] ?? false,',
            content
        )

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Updated onboarding successfully')
except Exception as e:
    print(e)
