import sys

def check(file):
    with open(file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    b = 0
    in_class = False
    for i, line in enumerate(lines):
        if 'class _MenuPlanningTabState' in line:
            in_class = True
            print("Found class at", i+1)
        if in_class:
            b += line.count('{')
            b -= line.count('}')
            if b <= 0 and in_class:
                print(f"Class _MenuPlanningTabState ends at {i+1} after reading {line.strip()}")
                return

check('lib/screens/menu_planning_tab.dart')
