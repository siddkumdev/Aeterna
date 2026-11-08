# Aeterna audio direction

Owner: Siddharth (with Claude), since 2026-11-07. This page is the source of truth for how the game sounds; the
`game-audio-principles` skill is general background and loses to this page. Every sound is made from code
(`assets/generators/make_audio.py` with `tools/audio_synth.py`); no recordings, samples or soundfonts.

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
- **Variation:** sounds heard many times (pinch, grab, place, hits, shots) have 4 takes (different seed and a small
  pitch offset), plus a random pitch change at play time.
- **3D:** the world bus is spatial (enemies, towers, houses, spells); ui, beds and stings are flat.

## Accessibility (from the Claude-Code-Game-Studios review, 2026-11-08)
Any sound that carries game information also needs something to see, because many VR players turn the sound down:
an enemy spawning off-view, a house being hit, a spell coming off cooldown. Check this whenever a sound is hooked up.

## How to change a sound
1. Tell Claude in plain words what is wrong ("too harsh", "too long", "too cartoony", "too quiet").
2. Claude edits the recipe, regenerates (`python assets/generators/make_audio.py <name> --godot`), checks it
   (`python tools/validate_audio.py`) and sends the new file.
3. Only your ears approve a sound; log approvals in `assets/ASSETS.md`.
