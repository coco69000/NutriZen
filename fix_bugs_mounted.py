import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Fix ScaffoldMessenger.of(context) after await
text = re.sub(r'(\s*)(ScaffoldMessenger\.of\(context\)\.showSnackBar\()',
              r'\1if (mounted) \2', text)

# Fix Navigator.pop(context) after await
text = re.sub(r'(\s+)(Navigator\.pop\(context\);)',
              r'\1if (mounted) \2', text)

# Remove things like "if (mounted) if (mounted)" if accidents happen
text = re.sub(r'if \(mounted\) if \(mounted\)', r'if (mounted)', text)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
