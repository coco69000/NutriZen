import sys
content = open('lib/main.dart', 'r', encoding='utf-8').read()
start = content.index('class _MenuPlanningTabState')
lines = content[start:].split('\n')
b = 0
for i, line in enumerate(lines):
    b += line.count('{')
    b -= line.count('}')
    # if class closed
    if b <= 0 and i > 0:
        print("Ends at local line", i)
        break
