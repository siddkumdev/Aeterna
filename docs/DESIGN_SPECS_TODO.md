# Game design specs to decide (Siddharth owns these)

Answer in rough bullets. Claude turns answers into `docs/GAME_SPEC.md` and builds from it. Anything marked "default?" has a suggestion Claude can propose if you say "you propose".

## A. Needed first (blocks the first playable)
1. **Board:** table-top size (about 0.6 m?), grid snapping or free placement, flat or elevated island, how many enemy paths, how many forest spawn points.
2. **What enemies attack:** houses, villagers, a village core, or towers? What does "losing a night" mean (houses lost, core HP)?
3. **Night rules:** length, how a night is won, what happens when the player does nothing.
4. **Tower placement rules:** cost model, max count, can towers be moved, sold or upgraded?
5. **Economy (trust):** starting amount, how it is earned in the day, what each building costs, how many numbers per night.
6. **Loop structure for the competition build:** number of nights before the boss, day length, is the day skippable.

## B. Rosters (after A)
7. **Towers (about 4):** role, range, damage, cost for each (e.g. archer, barricade, area light, healing shrine).
8. **Hut and troops:** troop types, spawn rate, how the rally point works.
9. **Enemies (about 5 + boss):** behaviour, speed, HP, which Foresight tier reveals each, and the boss phases.
10. **Flyers:** how many types, entry point (wall portals?), height, speed, and how hands defeat them (swat, throw or spell) plus how forgiving the hit area is.

## C. Hand interactions (after A)
11. **Spells and potions (3-4):** effect, limit or cooldown, gesture (pour, throw, rune).
12. **Drop-spell rule:** exactly how release height changes timing or impact.
13. **Foresight gesture:** spyglass, lens or something else, and what is visible at each tier.
14. **Menus:** palm-up build menu, rally point, title, pause, quit, all hands-only. Do you want pan, zoom or rotate of the island at all?

## D. Progression (after B and C)
15. **Time loop:** what resets, what persists, the 3-ability choice (list the 5-6 abilities for the competition), the 1-ability choice after a loss.
16. **Loop 2 difficulty:** more enemies, new mechanics, or both? What must be visibly different for the demo video?
17. **Fate Coin:** the outcome table (e.g. 6 outcomes) and effects.
18. **Villagers:** 3-4 kinds of help request, trust rewards, and the memory dialogue per loop.

## E. Story and presentation (last)
19. **Boss and reveal:** who is it, why did the forest turn, and the title.
20. **First 5 minutes:** wordless tutorial steps in order.
21. **Demo-video beats:** what the 3 minutes must show (twist, wall portal, hands).
22. **Audio mood words:** a few words per time of day and for the boss.

## F. Comfort and safety
23. **Seated rules:** reach zones, keeping active content below eye level, flyer height limits.
