import json,random
import pretty_midi as pm
from build import CH,ROOT,snap,grid
random.seed(11)
BPM=104; e=60/BPM/2
# 16 bars: 1-4 mellow upbeat (all major), 5-8 slow turn, 9-12 the ominous v2 colour (kept), 13-16 eased back
prog=['Bb','F','Eb' if False else 'Ebmaj7','Bb',  'Bb','F','Gm','Ebmaj7',  'Gm','Ebmaj7','Bb','Gm',  'Ebmaj7','Bb','F','Bb']
dark=[0,0,0,0.05, 0.15,0.3,0.5,0.7, 1,1,0.9,0.8, 0.5,0.3,0.2,0.1]
def build(path):
    m=pm.PrettyMIDI(initial_tempo=BPM)
    piano=pm.Instrument(0);bass=pm.Instrument(32);box=pm.Instrument(46);mar=pm.Instrument(12);pno=pm.Instrument(24)
    for b,ch in enumerate(prog):
        t0=b*8*e;d=dark[b]
        for s in range(0,8,2):
            n=grid[(b*8+s)%len(grid)]
            n=snap(n,ch) if n else snap(55+random.choice([0,3,7]),ch)
            n=n+12 if n<62 else n; n=max(62,min(n,81)) if d<0.5 else max(60,min(n,76))
            v=int(46+6*(s%4==0)-8*d+random.randint(-3,3))   # lighter touch at the start, softer when dark
            piano.notes.append(pm.Note(v,n,t0+s*e+random.uniform(-0.008,0.008),t0+s*e+e*(3.6+d)))
            if s%4==0 and False: pno.notes.append(pm.Note(int(54-10*d),n-12,t0+s*e,t0+s*e+e*3))
        oct_=12 if d<0.5 else 0   # bass sits an octave lower in the ominous middle
        for q in (0,4):
            bass.notes.append(pm.Note(int(74-8*d),ROOT[ch]+oct_,t0+q*e,t0+q*e+e*1.5))
            bass.notes.append(pm.Note(int(54-6*d),ROOT[ch]+oct_+7,t0+(q+2)*e,t0+(q+2)*e+e*1.2))
        # sparkle: lots when bright, fading to the odd note when dark
        base=CH[ch]
        slots=[3,7] if d<0.2 else ([6] if d<0.6 else [5])
        for k,pos in enumerate(slots):
            pc=base[(b+k)%len(base)]
            box.notes.append(pm.Note(int(40-12*d),60+((pc-60)%12),t0+pos*e,t0+pos*e+e*4))
        # light marimba bounce on the bright bars (upbeat)
        if False:
            for pos in (0,4):
                mar.notes.append(pm.Note(66,72+((base[0]-72)%12),t0+pos*e,t0+pos*e+e*1.5))
    for i in (piano,bass,box,mar,pno): m.instruments.append(i)
    m.write(path)
    return 16*8*e
if __name__=='__main__':
    print(build('day2.mid'))
