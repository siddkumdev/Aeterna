import json,numpy as np
g=json.load(open('grid.json'))
g=[(x+12 if x and x<43 else x) for x in g]   # fold low octave errors
names='C Db D Eb E F Gb G Ab A Bb B'.split()
tri={'Gm':(7,10,2),'Bb':(10,2,5),'Eb':(3,7,10),'F':(5,9,0),'Cm':(0,3,7),'D':(2,6,9),'Dm':(2,5,9),'Gm7':(7,10,2,5),'Ebmaj7':(3,7,10,2)}
bars=[]
for b in range(len(g)//8):
    seg=[x%12 for x in g[b*8:(b+1)*8] if x]
    best=max(tri,key=lambda c:sum(1 for p in seg if p in tri[c])-0.1*len(tri[c]))
    bars.append(best)
print(len(bars),bars)
json.dump({'grid':g,'bars':bars},open('chords.json','w'))
