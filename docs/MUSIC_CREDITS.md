# Music credits

The day music and the night bed are original: composed from Siddharth's own voice-memo draft (a 55 s recording of his own melody, 2026-11-10), transcribed and arranged as MIDI with free tools, then rendered to audio.

| what | tool / source | licence |
|---|---|---|
| Arrangement and MIDI | `mido`, `pretty_midi` (Python), `librosa` for the transcription | MIT / MIT / ISC |
| Rendering | FluidSynth 2.6.2, https://github.com/FluidSynth/fluidsynth | LGPL-2.1 (a tool; its output carries no licence) |
| Instrument sounds | GeneralUser GS 2.0.3 soundfont by S. Christian Collins, https://github.com/mrbumpy409/GeneralUser-GS | GeneralUser GS License v2.0: free for commercial use, no credit required. The author says the origin of some contained samples is not 100% certain, though no complaint has ever been received. Credit anyway on the credits screen or store page. |

Files: `godot/assets/audio/music/day_music.wav` (day loop, 36.9 s, 104 BPM, Bb major with a G minor and Eb middle, piano, plucked bass, soft harp) and `night_music.wav` (night bed, 20 s loop, 48 BPM, music box and celesta). Sources and build scripts: `assets/audio_src/music/` (`build5.py` = day, `build.py` night() = night; the final mix steps were low-pass, gentle compression, loudness -28 / -38 LUFS, loop tail folded to the start).

Reference only: the Animal Crossing music mix on YouTube was analysed (brightness, tempo, note density) to steer the feel. Nothing was copied from it; the audio stays in the git-ignored `_work/refs` and is not shipped.

Status: awaiting Siddharth's approval (he has approved the sound of day v7 and night v3 by ear in chat on 2026-11-18, but has not signed off the track as final in the game).

2026-11-18 (second round): `story_music.ogg` is the 170 s score for the opening (cello and music box from the same voice-memo melody, day-music motif for the happy parts, a new hopeful theme for 143-170 s), built by `assets/audio_src/music/build_story.py` with FluidSynth and the GeneralUser GS soundfont. `night_music.wav` was replaced by the upbeat night loop (`build_night_action.py`, same night theme at 120 BPM). Status: awaiting Siddharth's approval.
