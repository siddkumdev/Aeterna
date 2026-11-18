// Aeterna demo video, under 3:00, best material first (hackathon rule 2).
// Every footage clip is the bot playing the real game, captured through the in-game VR camera (vr_play.gd showcase).
import React from 'react';
import { AbsoluteFill, Audio, Sequence, interpolate, staticFile, useVideoConfig } from 'remotion';
import { Caption, Clip, Flash, OUTRO_DURATION, Outro, TITLE_DURATION, TitleMask, VrTag } from './shots';
import { loadFonts } from './theme';

export const FPS = 30;

// The edit, in order. `from` = second in raw.mp4, `len` = seconds on screen. Filled from the footage log.
type Cut = { from: number; src: string; len: number; caption?: { kicker?: string; line: string; accent?: string; hold?: number } };
import cutsJson from './cuts.json';
export const CUTS = cutsJson as unknown as Record<string, Cut[]>;

const sec = (s: number) => Math.round(s * FPS);
const total = (cs: Cut[]) => cs.reduce((a, c) => a + sec(c.len), 0);

const Run: React.FC<{ cuts: Cut[] }> = ({ cuts }) => {
  let at = 0;
  return (
    <>
      {cuts.map((c, i) => {
        const start = at;
        at += sec(c.len);
        return (
          <Sequence key={i} from={start} durationInFrames={sec(c.len)}>
            <Clip src={c.src} zoom={[1.0, 1.04]} />
            {c.caption && <Caption {...c.caption} hold={sec(c.caption.hold ?? Math.min(c.len - 1, 4))} />}
          </Sequence>
        );
      })}
    </>
  );
};

// music bed: the game's own score (docs/MUSIC_CREDITS.md), faded per section
const Bed: React.FC<{ file: string; from: number; dur: number; vol: number; fadeIn?: number; fadeOut?: number; loop?: boolean }> = ({ file, from, dur, vol, fadeIn = 20, fadeOut = 30, loop }) => (
  <Sequence from={from} durationInFrames={dur}>
    <Audio src={staticFile(file)} loop={loop} volume={(f) => vol * interpolate(f, [0, fadeIn, dur - fadeOut, dur], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })} />
  </Sequence>
);

export const layout = () => {
  const hook = total(CUTS.hook), day = total(CUTS.day), night = total(CUTS.night), fall = total(CUTS.fall), rewind = total(CUTS.rewind), loop2 = total(CUTS.loop2);
  const t = { hook: 0, title: hook, day: hook + TITLE_DURATION } as Record<string, number>;
  t.night = t.day + day;
  t.fall = t.night + night;
  t.rewind = t.fall + fall;
  t.loop2 = t.rewind + rewind;
  t.outro = t.loop2 + loop2;
  t.end = t.outro + OUTRO_DURATION;
  return t;
};

export const Demo: React.FC<{ music: boolean }> = ({ music }) => {
  loadFonts();
  const t = layout();
  const span = (a: string, b: string) => t[b] - t[a];
  return (
    <AbsoluteFill style={{ background: '#070b14' }}>
      <Sequence from={t.hook} durationInFrames={span('hook', 'title')}><Run cuts={CUTS.hook} /></Sequence>
      <Sequence from={t.title} durationInFrames={TITLE_DURATION}><TitleMask src={CUTS.titlePlate[0].src} /></Sequence>
      <Sequence from={t.day} durationInFrames={span('day', 'night')}><Run cuts={CUTS.day} /></Sequence>
      <Sequence from={t.night} durationInFrames={span('night', 'fall')}><Run cuts={CUTS.night} /></Sequence>
      <Sequence from={t.fall} durationInFrames={span('fall', 'rewind')}><Run cuts={CUTS.fall} /></Sequence>
      <Sequence from={t.rewind} durationInFrames={span('rewind', 'loop2')}><Run cuts={CUTS.rewind} /></Sequence>
      <Sequence from={t.loop2} durationInFrames={span('loop2', 'outro')}><Run cuts={CUTS.loop2} /></Sequence>
      <Sequence from={t.outro} durationInFrames={OUTRO_DURATION}><Outro /></Sequence>
      {/* the hourglass turn: loop 2 lands under a warm white flash */}
      <Sequence from={t.loop2 - 6} durationInFrames={30}><Flash at={6} /></Sequence>
      {/* the capture tag on every footage section (not the title or outro cards) */}
      <Sequence from={t.hook} durationInFrames={span('hook', 'title')}><VrTag /></Sequence>
      <Sequence from={t.day} durationInFrames={span('day', 'outro')}><VrTag /></Sequence>
      {music && (
        <>
          <Bed file="music/night_music.wav" from={t.hook} dur={span('hook', 'day') + 15} vol={0.55} loop fadeIn={10} />
          <Bed file="music/day_music.wav" from={t.day} dur={span('day', 'night') + 20} vol={0.4} loop />
          <Bed file="music/night_music.wav" from={t.night} dur={span('night', 'rewind')} vol={0.5} loop />
          <Bed file="music/story_music.ogg" from={t.rewind} dur={span('rewind', 'end')} vol={0.5} fadeOut={45} />
        </>
      )}
    </AbsoluteFill>
  );
};
