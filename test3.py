b=0
lines=open('lib/main.dart', 'r', encoding='utf-8').readlines()
for i,l in enumerate(lines):
    b+=l.count('{')-l.count('}')
    if b<0: 
        print('Negative at', i)
        break
print('Total', b)