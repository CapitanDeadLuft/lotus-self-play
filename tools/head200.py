f=r"C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.prev.log"
lines=open(f, encoding='utf-8', errors='replace').readlines()
for i in range(0, 200):
    l=lines[i].rstrip()
    print(i, l[:230])
