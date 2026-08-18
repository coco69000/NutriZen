import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Make it use kDebugMode
# We can replace HttpOverrides.global = MyHttpOverrides(); with:
# if (kDebugMode) { HttpOverrides.global = MyHttpOverrides(); }
text = re.sub(r'  HttpOverrides\.global = MyHttpOverrides\(\);', r'  if (kDebugMode) { HttpOverrides.global = MyHttpOverrides(); }', text)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
