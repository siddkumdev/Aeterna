// The video's look comes from the game (video-shotcraft rule: the film grows out of the product's own design):
// Aeterna's title font Cinzel, body font EB Garamond (both OFL, godot/assets/fonts) and art/palette.json colours.
// Magic and glow are warm (lantern / fire), never blue (CLAUDE.md).
import { continueRender, delayRender, staticFile } from 'remotion';

export const C = {
  ink: '#111C30', // palette "ink": the night sky round the island
  inkDeep: '#070b14',
  glow: '#F6A45D', // lantern_glow
  fire: '#E8452C', // fire_red
  gold: '#FFD45A', // fire_yellow
  parchment: '#F4E9D2',
  parchment2: 'rgba(244,233,210,0.72)',
};

export const FONTS = {
  title: '"Cinzel", "Times New Roman", serif',
  body: '"EB Garamond", Georgia, serif',
};

const faces: [string, string, FontFaceDescriptors][] = [
  ['Cinzel', 'fonts/Cinzel.ttf', { weight: '400 900' }],
  ['EB Garamond', 'fonts/EBGaramond.ttf', { weight: '400 800' }],
  ['EB Garamond', 'fonts/EBGaramond-Italic.ttf', { weight: '400 800', style: 'italic' }],
];

let started = false;
export const loadFonts = () => {
  if (started || typeof document === 'undefined') return;
  started = true;
  const h = delayRender('fonts');
  Promise.all(
    faces.map(([family, file, desc]) => {
      const f = new FontFace(family, `url(${staticFile(file)})`, desc);
      return f.load().then((loaded) => document.fonts.add(loaded));
    }),
  )
    .then(() => continueRender(h))
    .catch((e) => {
      console.error(e);
      continueRender(h);
    });
};
