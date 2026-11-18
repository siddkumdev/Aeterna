# VR stress test, 2026-11-18 (flags, and what was fixed)

A scripted player (`godot/tools/vr_play.gd`) drove the game through the real XR hand trackers, recorded with Godot Movie Maker (headset view 960x1024, 30 fps, with sound). Nothing in the game was changed; the team decides what to fix.

Runs (videos are local, in `_work/`, git-ignored):
| run | what | video |
|---|---|---|
| baseline | clumsy first-time player, the whole first loop: tutorial, nights 1-3, card, cutscene, loop 2 start (8.5 min) | `_work/baseline/baseline_small.mp4` (16 MB), full size `baseline.mp4` |
| abuse2 | spam pinches at night, two hands, hand lost mid-grab | `_work/abuse2/abuse_small.mp4` |
| abuse4 | night 1 played normally, then day abuse on loop 2 day 1: spam, two hands, tray + card, hand lost, ledger + card, leaning, cutscene spam | `_work/abuse4/abuse_small.mp4` (11 MB) |

No crash, no script error, nothing left stuck in a hand after any abuse case, two hands on one card never built two towers, spam on the big hourglass rewound exactly once, pinching during the story did not skip it.

## Flags (seen in the frames unless marked)

### Gameplay / interaction
1. **A quick tap on a card uses it.** Pinch-and-release on a tower card without dragging builds that tower just in front of the tray (4 taps = 4 towers, 356 -> 136 faith in 3 s, abuse4 0:211-214). Same on spell cards: a tap casts the spell and puts it on cooldown (abuse2 0:91-95). A newcomer's fumbles or a double pinch spend faith and spells.
2. **Night 1 of the first loop is often lost by a newcomer.** Baseline survived it (1 tower + spells); in 2 of 2 other runs the same bot lost night 1 in about 60-70 s (abuse3, abuse4), which ends the loop straight away (card, cutscene, loop 2). Spam-casting all spells at once also lost it (abuse2). Inference: enemy randomness differs per run.
3. **Root Ward fails silently for newcomers.** It only works over a house; 8 of 10 drops on enemies did nothing except the line "Drop the root potion over a house." (baseline).
4. **A tower card dropped on a spot under the tray goes back to the tray** with no message and no sound (baseline 6:26). The tray covers the near rows of the island.
5. **"First shade felled! +15 faith" during day 1 of the tutorial** (baseline 0:10), with an enemy spawn sound. Question: intended practice shade?

### Placement / readability (player-critic agreed, CONFIRMED in frames)
6. **Day clock drawn over the message line** at dawn ("Dawn. 5 houses stood"), loop 2 start ("faith carried") and day messages ("Wizard Tower built").
7. **"Hold to hurry the day" lies over other text:** the tutorial hourglass hint (baseline 2:14) and villager dialogue (abuse4 3:35).
8. **Villager speech notes sit on top of the tray cards**, hiding card text (baseline 0:03, 1:39, 4:00, 4:12, nightfall).
9. **The quest sign is a big paper hanging in front of the tray**, covering the near island most of each day; the tray handle covers its title ("LOST L", "WASHIN", "FESTIV"); steeply tilted when the head turns.
10. **Cutscene captions are big, very close and tilted**; "Grab the hourglass to turn back time" covers half the view and part of the big hourglass, and is cut off when the player looks a little sideways.
11. **Continue plaque** partly behind the tray handle ("ontinue"), tilted (critic).
12. **Tutorial hint text is small and thin and placed high**; the same "Well done! Take your time, then tap Continue" line repeats for about 8 steps (critic; size CONFIRMED, edge clipping partly the bot's head angle).
13. Night: tray and cards very dark, faith counter small (critic, PLAUSIBLE, may be the intended mood).

### Sound (measured with `tools/vr_audio_check.py`, clips in `_work/<run>/clips/`)
14. No clipping anywhere; loudest moment -2.5 dBFS; at most 9 sounds at once.
15. Pile-ups (5+ sounds within 0.5 s): 7 in the baseline, mostly night 3 (crossbow shot + pierce, wizard launch, enemy death, house hit together) and the very first build of the tutorial (build pop + enemy spawn + chime + wizard launch).
16. Single loud peaks around -2.5 to -5 dBFS, about 9 dB over their usual level: enemy death, house hit, a wizard cheer bark, an owl (night 3, 7:25-7:27 in the baseline).

### Not game bugs (the bot or the tool)
- The bot's "pinch the air" mistake often landed on the Boulder card, so FAILs on the Boulder card come from the bot.
- The bot carried only one item on multi-item quests (washing, festival lanterns).
- "Dome 0 m from the eye" is a rough bounding-box test, not seen in the frames. Leaning 45 cm into the island puts the head inside houses and trees (normal for VR, no protection).

## Fixed the same day (the user's calls)
| # | fix |
|---|---|
| 1 | A card pinched and let go within 4 cm of where it was picked (`CARD_TAP_MOVE`) goes back: no build, no cast. Self-test covers it. |
| 2 | Night-1 balance: left as is (the user). |
| 3 | A failed spell (Root Ward off a house) plays the invalid sound; line "Root Ward shields a house: drop it on one." |
| 4 | A card let go off the island plays the invalid sound with a line ("Drop the card on the island to build." / "Drop the spell over the island."). |
| 5 | Tutorial practice shade: intended (`spawn_tutorial_shade`), unchanged. |
| 6 | The day clock hides while a message is up. |
| 7 | "Hold to hurry the day" only shows when no tutorial hint, speech note or message is up. |
| 8 | Speech notes hide while the tray or a card is between them and the eye (`CardTray.blocks_view`). |
| 9 | Quest slip moved beside the middle handle (x -0.205), so the handle no longer hides its name. |
| 10 | Cutscene caption band shown at 0.55 scale. |
| 11 | Continue plaque at the island's near-left corner. |
| 12 | Tutorial hints a third bigger and lower; the done line is just "Well done!". |
| 13 | Night tray: left dark (the user). |
| 15-16 | At most 2 copies of one sound at once (combo sounds exempt); enemy death, house hit, wizard cheer and owl 4 dB quieter. |
| tray | Start pose: 8 cm inside the near edge (as before), 15 cm up (was 25); the no-sink limit over the island lowered to 12 cm to match. Trying 6 cm outside the edge put it 0.25 m from the eye with huge messages, so it was undone. |

Also added: auto-save at the start of every day (`user://save.json`); the title shows Continue / New game / Skip story and never starts by itself.
