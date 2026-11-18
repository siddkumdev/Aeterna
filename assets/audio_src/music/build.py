import json,random,subprocess,sys,os
import pretty_midi as pm
random.seed(7)
d=json.load(open('chords.json'));grid=d['grid']
BPM=92; beat=60/BPM; eighth=beat/2
CH={'Gm':[7,10,2],'Ebmaj7':[3,7,10,2],'Cm':[0,3,7],'F':[5,9,0],'Bb':[10,2,5]}
prog=['Bb','Bb','Gm','Ebmaj7','Bb','F','Gm','Ebmaj7','Bb','Bb','Gm','Ebmaj7','Bb','F','Ebmaj7','F']
ROOT={'Gm':43,'Ebmaj7':39,'Cm':36,'F':41,'Bb':46}  # bass octave
def snap(n,ch):
    cands=[p+12*o for o in range(3,6) for p in CH[ch]]
    return min(cands,key=lambda c:abs(c-n))
def day(path,tempo=BPM):
    m=pm.PrettyMIDI(initial_tempo=tempo)
    piano=pm.Instrument(0,name='piano'); bass=pm.Instrument(45,name='pizz')
    pad=pm.Instrument(89,name='pad'); box=pm.Instrument(9,name='glock')
    e=60/tempo/2
    for b,ch in enumerate(prog):
        t0=b*8*e
        for s in range(8):
            n=grid[(b*8+s)%len(grid)]
            n=snap(n,ch) if n else snap(55+random.choice([0,3,7]),ch)
            n=max(50,min(n,67))
            v=int(52+8*(s%4==0)+random.randint(-4,4))
            piano.notes.append(pm.Note(v,n,t0+s*e+random.uniform(-0.008,0.008),t0+s*e+e*1.9))
        for q in (0,4):
            bass.notes.append(pm.Note(66,ROOT[ch]+12,t0+q*e,t0+q*e+e*1.5))
            bass.notes.append(pm.Note(52,ROOT[ch]+19 if ch!='F' else ROOT[ch]+19,t0+(q+2)*e,t0+(q+2)*e+e*1.2))
        if b%2==1:
            base=CH[ch]
            for k,(pos,pc) in enumerate([(2,base[2]),(5,base[0])]):
                box.notes.append(pm.Note(46,72+((pc-72)%12),t0+pos*e,t0+pos*e+e*3))
    for i in (piano,bass,box): m.instruments.append(i)
    m.write(path)
    return 16*8*e
def night(path):
    # slow, low, sparse: Gm / Eb minor-ish colours with a flat 2nd (Ab) for unease
    m=pm.PrettyMIDI(initial_tempo=48)
    box=pm.Instrument(10); pad=pm.Instrument(8); low=pm.Instrument(10)
    e=60/48/2
    seq=[(67,0),(62,2),(58,4),(68,7),(67,10),(62,12),(55,14),(65,17),(63,19),(62,22)]
    for n,pos in seq:
        box.notes.append(pm.Note(34,n+12,pos*e,pos*e+e*5))
    for b,(root,tri) in enumerate([(43,[55,58,62]),(39,[51,55,58]),(36,[48,51,55]),(43,[55,58,62])]):
        t0=b*8*e
        low.notes.append(pm.Note(28,root+12,t0,t0+4*e))
        for k,p in enumerate(tri): pad.notes.append(pm.Note(22,p+12,t0+k*2*e,t0+k*2*e+e*4))
    for i in (box,pad,low): m.instruments.append(i)
    m.write(path)
    return 4*8*e
if __name__=='__main__':
    print('day len',day('day.mid'))
    print('night len',night('night.mid'))
