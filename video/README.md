# Aeterna demo video

The hackathon demo (under 3 minutes, footage from the in-game VR view), edited in Remotion.

## Make it
1. Record the footage (the bot plays the real game through the VR camera, 1920x1080, 30 fps, music muted so the
   edit can lay the score under continuously):
   `VRH_NOMUSIC=1 <godot console> --xr-mode off --write-movie <out>/run.avi --fixed-fps 30 --path godot -s res://tools/vr_play.gd -- <recording.bin.gz> <out> showcase`
   with a temporary `godot/override.cfg` setting the viewport to 1920x1080 (delete it afterwards), then
   `ffmpeg -i run.avi -c:v libx264 -crf 18 -c:a aac raw.mp4` and copy it to `video/public/footage/raw.mp4` (git-ignored).
2. `cd video && npm install && python copy_assets.py` (the game's fonts and music, copied into the git-ignored `public/`)
3. The storyboard is `cut_spec.json` (each clip = a game event + offset); `python make_cuts.py <run dir>` turns it into `src/cuts.json` using that take's `events.txt`.
4. Preview: `npm run studio`. Render: `npx remotion render src/index.ts AeternaDemo out/aeterna_demo.mp4`
   (and `AeternaDemoNoMusic` for the version without the score).

## Sources
- Footage, music (`docs/MUSIC_CREDITS.md`), fonts (Cinzel, EB Garamond, OFL 1.1) and colours (`art/palette.json`) are the game's own.
- Shot recipes (text-as-mask title, blur-slide captions, white-flash cut, grain-dissolve outro) and the easing helpers
  in `src/lib/ease.ts` are adapted from video-shotcraft by Wei Yihao, https://github.com/Vincentwei1021/video-shotcraft,
  Apache License 2.0. Changes: Aeterna's text, fonts, palette, timings and footage. Its bundled music and sound
  effects were not used.
