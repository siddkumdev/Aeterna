import librosa,numpy as np,json
y,sr=librosa.load('draft.wav',sr=22050)
f0,vf,vp=librosa.pyin(y,fmin=librosa.note_to_hz('C2'),fmax=librosa.note_to_hz('C6'),sr=sr,hop_length=256)
t=librosa.times_like(f0,sr=sr,hop_length=256)
midi=np.where(np.isnan(f0),np.nan,librosa.hz_to_midi(f0))
BPM=76.0; step=60/BPM/2  # eighth
n=int(len(y)/sr/step)
grid=[]
for i in range(n):
    m=midi[(t>=i*step+0.05)&(t<(i+1)*step)]
    m=m[~np.isnan(m)]
    grid.append(int(round(np.median(m))) if len(m)>=3 else None)
# fold octave errors up into the main range
vals=[g for g in grid if g]
lo=int(np.percentile(vals,15))
out=[]
for g in grid:
    if g is not None:
        while g<lo-2: g+=12
    out.append(g)
names=[librosa.midi_to_note(g,unicode=False) if g else '-' for g in out]
print(len(out),'slots, lo',lo)
print(' '.join(names))
json.dump(out,open('grid.json','w'))
