# Aeterna audio direction

Owner: Siddharth (with Claude), since 2026-11-07. This page is the source of truth for how the game sounds; the
`game-audio-principles` skill is general background and loses to this page.

**Sources (Siddharth, 2026-11-08): real recordings, minimal code.** Every sound is built from free recordings: Freesound
CC0 / CC BY and the Sonniss GDC 2026 bundle (royalty-free), never AI-generated, never NC. `tools/audio_grains.py` cuts
them into kits in `assets/audio_src/grains/` (credits in `docs/AUDIO_CREDITS.md`); `assets/generators/make_audio.py`
only processes them (cut, pitch onto the key, filter, layer, small room) and refuses to build if a recipe calls a
synthesis function. Tuned stings use one real recorded note (marimba, xylophone, kalimba, music box, church bell)
shifted to each note of the melody. Voices (barks, villagers) are chopped real gibberish speech, kept near the
speaker's own pitch.

## Mood (Siddharth, 2026-11-08)
- **Day: peaceful and cozy.** A small toy village on a table: warm wood, soft bells, glass plinks, gentle wind, birds.
- **Nightfall: a little tense, without changing the vibe.** Same instruments and same world, just lower, sparser
  and slower: a low hum under the crickets, a distant owl, the odd branch creak. Never a horror or action score.
- Magic is airy shimmer and fire crackle, never electronic zaps (matches the black / orange / red magic rule).

## Sound palette
| use | sounds like | avoid |
|---|---|---|
| hands, menus (ui bus) | small wooden ticks, marimba plinks, glass pips | clicks with hard highs, beeps |
| building, coins | woody stone thunk, dust puff, coins | metal clangs |
| towers, spells | soft fwoomp and crackle, bowstring, airy wind | lasers, zaps, distortion |
| enemies | bloops, poofs, rustles, soft cries | gore, screams |
| village | bells, doors, shutters, chimes | alarms |
| ambience | wind, leaves, birds by day; crickets, owl, low hum by night | constant loud beds |

Every sound is soft-edged: highs above about 10 kHz are rolled off, and big hits are boomy rather than sharp.

## Mix (buses in `godot/scripts/audio/audio_bank.gd`)
Player feedback sits on top; there is no voice acting, so the ui bus is the reference.

| bus | level | holds |
|---|---|---|
| ui | -3 dB | hands, menus, trust and card stings |
| sfx | -5 dB | the world: towers, enemies, spells, village |
| music | -10 dB | later (A01-A07) |
| ambience | -15 dB | day / night beds, rain, fog |

- **Ducking:** a big story beat (dawn bell, night falls, a card's rarity, the rewind, the boss) lowers ambience and
  music by 6 dB while it plays (manifest `duck`).
- **Priority:** at most 28 sounds at once; each sound has its own cooldown so crowds do not stack into noise.
- **Variation:** sounds heard many times (pinch, grab, place, hits, shots) have 4-8 takes (different seed, a small
  pitch offset and, for layered sounds, a different recorded grain), plus a random pitch change at play time.
- **Combo:** quick kills (enemy_death within 1.2 s) climb the key's pentatonic (C D E G A), then fall back to C.
- **3D:** the world bus is spatial (enemies, towers, houses, spells); ui, beds and stings are flat.

## Key (Claude's default, 2026-11-08, Siddharth asked for chimes in the music's key)
**C major by day; night sounds may borrow from C minor (Eb, Ab, Bb).** The music (A01-A07) follows this key.
`make_audio.py` prints a key check for every build; barks are tuned (`tuned=True`: no take detune, no play-time vary).

## Voices and the living board
- **Tower barks (A49):** each crew member has a gibberish voice (no words): "hup-hup-hah" when the tower lands, a quick
  cheer on some of its kills. Wizard old and warm, archer young and quick, pilot cheery, Guard Tower captain gruff.
  Voices (barks and villagers) stay at the speaker's own recorded pitch, nudged only a few semitones for contour,
  never shifted onto the key's notes (Siddharth 2026-11-08: shifting made them chipmunky).
- **No background beds (Siddharth 2026-11-08):** day_bed and night_bed are not played; the one-shots below and the
  dawn / nightfall bells carry the time of day.
- **Ambience one-shots (A50, A51):** the game scatters short sounds at things
  you can see (`AudioBank.set_scatter`, pools in `game.gd`): by day birds and leaves in the forest ring and a villager at
  work by a house, every few seconds; by night, sparser: an owl, a branch creak, something in the undergrowth.

## Accessibility (from the Claude-Code-Game-Studios review, 2026-11-08)
Any sound that carries game information also needs something to see, because many VR players turn the sound down:
an enemy spawning off-view, a house being hit, a spell coming off cooldown. Check this whenever a sound is hooked up.

## How to change a sound
1. Tell Claude in plain words what is wrong ("too harsh", "too long", "too cartoony", "too quiet").
2. Claude edits the recipe, regenerates (`python assets/generators/make_audio.py <name> --godot`), checks it
   (`python tools/validate_audio.py`) and sends the new file.
3. Only your ears approve a sound; log approvals in `assets/ASSETS.md`.

## Restart brief, batch 1 (Siddharth, 2026-11-10; SFX restarted from scratch)
Answers to the first taste questions, kept in his words. Nothing here is a technical spec; the agent translates it.
- Loved reference: Bloons tower defense (no particular dislike named).
- Feeling: cosy, cute, calm. He says none of these are present in the old sounds.
- Placing a tower: a soft wooden tap.
- Fighting: weighty and impactful while the game still feels cosy. The hit sound depends on the TOWER, not the enemy.
- Rewards and coins: soft and round.
- Hated: buzzy, metallic or sharp sounds, and bit-crushed sounds.
- Listening: headphones only for now (Quest speakers later).
- Style: stylised, not realistic.
- Open: hackathon eligibility of synthesised sound; Quest speaker testing; later batches (per-sound feel, pitch/chain ideas).
