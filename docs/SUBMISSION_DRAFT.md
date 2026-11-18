# Aeterna: submission draft (NOTHING PUBLISHED)

This is a draft for Siddharth and Durva to edit, last rewritten 2026-11-18 evening. It has one section for each field on the submission form, in the form's order. Every line marked TODO needs your input. Nothing here has been posted, uploaded or sent.

Deadline: 2026-11-18 12:00 PM PT = 2026-11-19 01:30 IST.

## Checklist (the last job)
1. Export the final Quest build and install it on the headset once (`quest_build.bat`, skill `quest-build`). TODO: tonight's fixes (stress-test fixes, auto-save, tray, tutorial, big hourglass) pass the self-test and the VR bot, but nobody has tried them on a headset yet.
2. Upload the APK to the Competition channel. TODO: you do this.
3. Record the video (capture list at the end). TODO.
4. Paste the form fields below into Devpost.
5. Licence proof: we made every model ourselves, and the sounds are free-licence recordings credited in `docs/AUDIO_CREDITS.md` and `docs/MUSIC_CREDITS.md`. CC BY rows must also appear on a credits screen or the store page. TODO: confirm the credits screen exists, or paste the credits on Devpost.
6. Do not push `art/moodboard/skotos/` (third-party references; the repo stays private).

---

## 1. Submission name
**Aeterna**

## 2. Submission tagline (140 characters max)
> A tiny god, a floating island, a village that falls every few nights. Defend it with your bare hands, then turn back time.

(122 characters.) Alternative, if you prefer:
> Guard a tiny floating village on your real table with your bare hands. When it falls, turn the hourglass and try again. (119 characters)

## 3. Track
**Gaming.** (Recommended. It is a tower-defence game with a story; it doesn't fit Entertainment or Productivity better.)

## 4. Division
**New Experience.** The project started on 2026-10-18 (first commit) and everything in it was built during the competition window. TODO: confirm.

## 5. Description: inspiration, how we built it, future plans (aim for 500 words or less)

> **Inspiration**
>
> We wanted a game you play the way you play a board game: sitting at a table, leaning in, using your hands. Tower defence fit, but we didn't want soldiers and a score. We wanted a village you get to know.
>
> So in Aeterna you are a very small god. Your whole world is one floating island the size of a tabletop: twelve villagers, a well, a statue and a dome of warm light called the Veil, woven from their Faith. Skotos, a forgotten god of the Dark Wood whose own people stopped praying, has cursed the Veil so it fails at night. The last night of every loop always falls. When it does, you turn an hourglass and time rewinds. The villagers don't remember, at first. Then, loop by loop, they start to.
>
> By day you help them with small kindnesses: a lost lamb, a kite in a tree, laundry blown off the line. Every kindness raises Faith, and Faith builds defences. By night, creatures come out of the forest, your towers fight on their own, and you throw fire, drop boulders and call storms with your own hands. From the third loop on, the statue offers you an ending each dawn. You can take it, or keep looping.
>
> **How we built it**
>
> Aeterna is made in Godot 4.7.2 with OpenXR for the Meta Quest 3, using hand tracking and passthrough so the island sits on your real table.
>
> Every 3D model is ours, built from scratch as a Blender Python script: towers, villagers, enemies, Skotos, trees and props. There are no AI-generated or store-bought models. All of them share one hand-made palette texture, so the whole game uses two materials and stays cheap to draw on a standalone headset. Characters are separate parts animated in Godot rather than skinned rigs. Magic is drawn as effects in the engine, always in black, orange and red. Sound effects are real recordings under free licences, cut and layered and credited.
>
> Keeping a full village, a lit dome and a night battle at headset frame rate was the hardest part. We built an adaptive quality governor, merged static meshes, used a cheap fake bloom for lit windows and cut shadow casters. To test without a headset every time, we recorded real play sessions on the Quest and built a replay driver and a scripted "VR player" bot. The bot plays the tutorial, the tray and the rewind with human-like hand movements, alongside a self-test of about 870 checks.
>
> TODO (keep or cut): Code was written with Claude Code under our direction, while game design, story, art direction and every approval came from us.
>
> **What's next**
>
> We want to tune the balance on real players, give each villager more lines as the loops go on, and add more quest kinds and the full set of Skotos's late phases. We also want proper comfort and accessibility options (one-handed play, seated height presets) and a store release. TODO: your own plans.

Word count of the quoted text: 497 (counted 2026-11-18), including the two TODO sentences. Trim something if you add more.

## 6. Adapted / Significantly Updated: new features in the window
**Not applicable** (New Experience). If you pick Adapted instead, TODO.

## 7. Hand interactions and the future of VR (optional)

> Aeterna is played with bare hands only, no controllers.
>
> - **Pinch to pick up.** Towers and spells are physical cards on a small wooden tray in front of you. Pinch a card, carry it over the island and let go on a cell to build. A short hold (0.2 s) and a settle guard make it forgiving of tracking jitter. The grab point is where your fingers actually meet, not a ray.
> - **Spells as objects.** At night each spell is something you hold. You throw a Fire Orb. You let go of a Boulder above the board: the higher you drop it, the harder and wider it hits, and the later it lands, so you lead a moving enemy. You release a Storm Cloud and it hangs where you left it. You drop a Root Ward potion onto a house.
> - **The tray and the island.** Move the tray by its brass handle. Spin the island by its rim like a lazy Susan.
> - **Tap a villager** to hear what they're thinking, or to accept their request. Quest items (a lamb, a kite, a bell) are carried by hand to where they belong.
> - **The Crystal Lens.** Hold it up and look through it to read hidden lore and see what's coming.
> - **The hourglass.** When the village falls, a big hourglass appears in front of you. Pinch it, and it turns and rewinds time.
>
> What excites us about VR is this kind of closeness. A tabletop game in mixed reality lives on your real table, at arm's length, and your hands are the whole interface. We think small, cozy, hand-made worlds you can lean into are where VR gets personal, and hand tracking is finally good enough to build a whole game on.

## 8. Target launch date
TODO: your date (Devpost asks for one if the game isn't published yet).

## 9. Team: name, email, role
| Name | Email | Role |
|---|---|---|
| Siddharth Kumar | TODO | Game design and rules, gameplay, environment and towers, VFX, Quest build and performance |
| Durva | TODO | Story and lore, world and narrative design, characters (villagers, enemies, Skotos), audio, UI |

Sources for the roles: `art/decisions.md` 2026-10-22 (the team-roles row), Durva's character and boss rounds from 2026-11-01, and her story, ledger and opening decisions from 2026-11-14. "Story and lore, world and narrative design" for Durva is my reading of the brief; TODO: correct the wording.

---

## Video capture list (suggested order)
1. The opening story: the Dark Wood, Skotos, the Wake.
2. The island on a real table in passthrough; pinch a tower card and place it.
3. Tap a waving villager, carry the quest item, Faith goes up.
4. A night wave: towers firing, a Boulder dropped from high, a Storm Cloud.
5. The Veil cracking, Skotos's phases, the Grove strangling a tower.
6. The fall, the big hourglass, the pinch, the rewind.
7. Credits.

## Known rough spots (be honest if asked)
- Tonight's fixes haven't been tried on a headset. They pass the self-test and the VR bot only. The bot can't judge blur, shimmer, comfort or frame rate.
- Waving villagers shift a few centimetres while you reach for them. The quest slip can look large over the village.
- Skotos v02 and the quest props are awaiting approval.
- Some balance numbers are stand-ins.
