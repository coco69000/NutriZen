b=0
lines=open('lib/main.dart', 'r', encoding='utf-8').readlines()
for i,l in enumerate(lines):
    if 'RecipeDetailPage' in l:
        print(f"Line {i}: {l.strip()} - Depth {b}")
    b += l.count('{') - l.count('}')
