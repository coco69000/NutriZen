b=0
lines=open('lib/main.dart', 'r', encoding='utf-8').readlines()
classes = []
for i,l in enumerate(lines):
    if 'class ' in l:
        classes.append((i, l.strip(), b))
    b += l.count('{') - l.count('}')
for i, l, b in classes:
    if b > 0:
        print(f"Line {i}: {l} (Depth {b})")