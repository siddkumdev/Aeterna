// Shot recipes adapted from video-shotcraft (Apache-2.0, github.com/Vincentwei1021/video-shotcraft):
// text-as-mask (opening), blur-slide (captions), white-flash cut (rewind), grain-dissolve (outro).
// The tuning (curves, staggers, beats) is the original's; the content, fonts and colours are Aeterna's.
import React, { useId } from 'react';
import { AbsoluteFill, Video, interpolate, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { EASE, E, bezier, ramp, rand, seg } from './lib/ease';
import { C, FONTS } from './theme';

export const FOOTAGE = 'footage/raw.mp4';

// ---- footage ------------------------------------------------------------------------------------------
// A clip of the bot's run through the in-game VR camera. `from` is the second in raw.mp4 the clip starts at.
export const Clip: React.FC<{ src: string; muted?: boolean; volume?: number; zoom?: [number, number] }> = ({ src, muted, volume = 1, zoom }) => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  // a very slow push-in (no handheld shake: the VR head already moves)
  const z = zoom ? zoom[0] + (zoom[1] - zoom[0]) * ramp(f, 0, durationInFrames, EASE.smooth) : 1;
  return (
    <AbsoluteFill style={{ background: C.inkDeep, overflow: 'hidden' }}>
      <Video
        src={staticFile(src)}
        muted={muted}
        volume={volume}
        style={{ width: '100%', height: '100%', objectFit: 'cover', transform: `scale(${z.toFixed(4)})` }}
      />
    </AbsoluteFill>
  );
};

// ---- blur-slide caption -------------------------------------------------------------------------------
// Word by word: opacity, rise and blur all ride ONE ease-out (the card's core rule), 4 f stagger.
type Word = { text: string; start: number; dur: number; style?: React.CSSProperties };
const Words: React.FC<{ words: Word[]; frame: number; dy: number; blur: number; style: React.CSSProperties }> = ({ words, frame, dy, blur, style }) => (
  <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', alignItems: 'baseline', columnGap: '0.28em', ...style }}>
    {words.map((w, i) => {
      const p = ramp(frame, w.start, w.dur, EASE.out);
      return (
        <span key={i} style={{ display: 'inline-block', opacity: p, transform: `translateY(${((1 - p) * dy).toFixed(2)}px)`, filter: p >= 0.999 ? undefined : `blur(${((1 - p) * blur).toFixed(2)}px)`, ...w.style }}>
          {w.text}
        </span>
      );
    })}
  </div>
);

// A lower-third chapter caption over footage: a small kicker, then the line. Holds, then leaves together.
export const Caption: React.FC<{ kicker?: string; line: string; accent?: string; start?: number; hold: number; pos?: 'low' | 'mid' }> = ({ kicker, line, accent, start = 6, hold, pos = 'low' }) => {
  const f = useCurrentFrame();
  const words: Word[] = line.split(' ').map((t, i) => ({
    text: t, start: start + 6 + i * 4, dur: 22,
    style: accent && t.replace(/[.,!]/g, '') === accent ? { color: C.glow, fontStyle: 'italic' } : undefined,
  }));
  const end = start + hold;
  const out = 1 - ramp(f, end, 12, EASE.exit);
  const rule = ramp(f, start, 24, EASE.snappy);
  const k = ramp(f, start, 18, EASE.out);
  return (
    <AbsoluteFill style={{ justifyContent: pos === 'low' ? 'flex-end' : 'center', alignItems: 'center', paddingBottom: pos === 'low' ? 120 : 0, opacity: out, pointerEvents: 'none' }}>
      {/* a soft dark band so the words read on bright day footage */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: pos === 'low' ? 420 : 1080, background: pos === 'low' ? 'linear-gradient(0deg, rgba(7,11,20,0.78) 0%, rgba(7,11,20,0.45) 45%, rgba(7,11,20,0) 100%)' : 'rgba(7,11,20,0.35)' }} />
      <div style={{ position: 'relative', textAlign: 'center' }}>
        {kicker && (
          <div style={{ fontFamily: FONTS.title, fontSize: 32, letterSpacing: `${(0.32 - 0.12 * k).toFixed(3)}em`, color: C.glow, opacity: k, marginBottom: 14, textTransform: 'uppercase' }}>
            {kicker}
          </div>
        )}
        <div style={{ width: `${(rule * 220).toFixed(1)}px`, height: 2, margin: '0 auto 22px', background: `linear-gradient(90deg, transparent, ${C.glow}, transparent)` }} />
        <Words words={words} frame={f} dy={34} blur={14} style={{ fontFamily: FONTS.body, fontSize: 76, fontWeight: 500, color: C.parchment, textShadow: '0 2px 18px rgba(0,0,0,0.6)', maxWidth: 1500 }} />
      </div>
    </AbsoluteFill>
  );
};

// ---- the "captured from the in-game VR view" tag -------------------------------------------------------
export const VrTag: React.FC = () => (
  <div style={{ position: 'absolute', right: 48, top: 40, fontFamily: FONTS.body, fontSize: 32, color: C.parchment2, letterSpacing: '0.02em', textShadow: '0 1px 8px rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', gap: 12 }}>
    <span style={{ width: 10, height: 10, borderRadius: 5, background: C.fire, boxShadow: `0 0 10px ${C.fire}` }} />
    Captured from the in-game VR view
  </div>
);

// ---- text-as-mask title ---------------------------------------------------------------------------------
// The game seen through the letters of AETERNA; the letters breathe in, then rush x46 into the footage.
// Beats are the original card's (165 f): in 0-18, drift 18-96, breath 96-104, rush 104-128, land 132.
export const TITLE_DURATION = 165;
const WORD = 'AETERNA';
const FS = 300;
const BASE_Y = 650;
const TEXT_ATTRS = `x="960" y="${BASE_Y}" font-family="Cinzel" font-size="${FS}" font-weight="800" letter-spacing="6" text-anchor="middle"`;

export const TitleMask: React.FC<{ src: string }> = ({ src }) => {
  const f = useCurrentFrame();
  const uid = useId().replace(/[^a-zA-Z0-9]/g, '');
  const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;
  // the zoom origin sits inside the T's stem (3rd letter); measured on a rendered still
  const OX = TITLE_ORIGIN[0], OY = TITLE_ORIGIN[1], MAX_S = 46;
  const intro = ramp(f, 0, 18, EASE.snappy);
  const wipe = ramp(f, 0, 16, EASE.out);
  const introS = 1.04 - 0.04 * intro;
  const breath = ramp(f, 96, 8, EASE.swift);
  const rush = Math.pow(ramp(f, 104, 24, EASE.linear), 1.8);
  const s0 = introS * (1 - 0.035 * breath);
  const S = s0 * Math.pow(MAX_S / s0, rush);
  const cdx = (960 - OX) * rush, cdy = (540 - OY) * rush;
  const wrapT = `translate(${cdx.toFixed(2)}px, ${cdy.toFixed(2)}px) scale(${S})`;
  const innerT = `scale(${1 / S}) translate(${(-cdx).toFixed(2)}px, ${(-cdy).toFixed(2)}px)`;
  const drift = ramp(f, 18, 78, bezier(0.3, 0, 0.7, 1));
  const land = ramp(f, 104, 28, EASE.snappy);
  const dx = (90 - 180 * drift) * (1 - land);
  const plateS = 1.22 + (1 - 1.22) * land;
  const cover = interpolate(rush, [0.86, 0.95], [0, 1], clamp);
  const glowA = 1 - interpolate(rush, [0, 0.25], [0, 1], clamp);
  const eyebrow = ramp(f, 6, 20, EASE.out);
  const sub = ramp(f, 14, 18, EASE.out);
  const out = 1 - ramp(f, 96, 10, EASE.exit);
  const mask = `url("data:image/svg+xml,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080"><text ${TEXT_ATTRS} fill="white">${WORD}</text></svg>`)}")`;
  const glowSvg = `data:image/svg+xml,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080"><text ${TEXT_ATTRS} fill="${C.glow}">${WORD}</text></svg>`)}`;
  const clipBottom = `inset(0 0 ${((1 - wipe) * (1080 - BASE_Y + FS * 0.72)).toFixed(1)}px 0)`;
  const plate = (
    <div style={{ position: 'absolute', inset: 0, transform: `translateX(${dx.toFixed(2)}px) scale(${plateS.toFixed(4)})` }}>
      <Clip src={src} muted />
    </div>
  );
  return (
    <AbsoluteFill key={uid} style={{ background: C.inkDeep, overflow: 'hidden' }}>
      {/* a warm night stage: lantern light from above, dark edges */}
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 70% 60% at 50% 38%, #1d2740 0%, ${C.ink} 45%, ${C.inkDeep} 100%)` }} />
      {/* lantern glow behind the letters (warm, never blue) */}
      <img src={glowSvg} style={{ position: 'absolute', left: 0, top: 0, width: 1920, height: 1080, opacity: 0.55 * glowA * intro, filter: 'blur(26px)', transform: wrapT, transformOrigin: `${OX}px ${OY}px`, clipPath: clipBottom }} />
      <div style={{ position: 'absolute', inset: 0, transform: wrapT, transformOrigin: `${OX}px ${OY}px`, clipPath: clipBottom, WebkitMaskImage: mask, maskImage: mask, WebkitMaskRepeat: 'no-repeat', maskRepeat: 'no-repeat', WebkitMaskSize: '1920px 1080px', maskSize: '1920px 1080px' }}>
        <div style={{ position: 'absolute', inset: 0, transform: innerT, transformOrigin: `${OX}px ${OY}px` }}>{plate}</div>
      </div>
      {cover > 0 && <div style={{ position: 'absolute', inset: 0, opacity: cover }}>{plate}</div>}
      <div style={{ position: 'absolute', top: 250, width: '100%', textAlign: 'center', opacity: eyebrow * out, fontFamily: FONTS.title, fontSize: 32, color: C.glow, letterSpacing: `${(0.3 + (1 - eyebrow) * 0.3).toFixed(3)}em` }}>
        A SEATED VR TOWER DEFENCE
      </div>
      <div style={{ position: 'absolute', top: BASE_Y + 70, width: '100%', textAlign: 'center', fontFamily: FONTS.body, fontStyle: 'italic', fontSize: 48, color: C.parchment, opacity: sub * out, transform: `translateY(${((1 - sub) * 16).toFixed(2)}px)` }}>
        Every night the village falls. <span style={{ color: C.glow }}>Time remembers.</span>
      </div>
    </AbsoluteFill>
  );
};
export const TITLE_ORIGIN: [number, number] = [700, 545]; // re-measured after the first still

// ---- white-flash cut (the rewind) -------------------------------------------------------------------------
// One of the film's few full-frame impacts: the frame blows out to warm white and cuts under it.
export const Flash: React.FC<{ at: number; up?: number; down?: number }> = ({ at, up = 4, down = 18 }) => {
  const f = useCurrentFrame();
  const a = f < at ? ramp(f, at - up, up, EASE.linear) : 1 - ramp(f, at, down, EASE.out);
  if (a <= 0.001) return null;
  return <AbsoluteFill style={{ background: '#FFF4E2', opacity: a, pointerEvents: 'none' }} />;
};

// ---- grain-dissolve outro ---------------------------------------------------------------------------------
// The tagline breaks into sand and the grains settle into the AETERNA wordmark (turbulence + displacement).
export const OUTRO_DURATION = 165;
export const Outro: React.FC = () => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const t = Math.min(1, f / Math.max(1, durationInFrames - 1));
  const uid = useId().replace(/[^a-zA-Z0-9]/g, '');
  // the tagline reads for ~1 s before it breaks; the wordmark then holds ~1.5 s (shotcraft: brand >= 1 s)
  const tagIn = seg(t, 0.0, 0.08, E.outCubic);
  const burst = seg(t, 0.3, 0.42, E.outCubic);
  const cond = seg(t, 0.47, 0.6, E.inOutCubic);
  const lock = seg(t, 0.56, 0.72, E.outCubic);
  const settle = seg(t, 0.7, 0.82, E.outCubic);
  const glow = Math.max(0, burst * 0.3 + cond * 0.7 - settle * 0.45);
  const boil = Math.floor(t * 46);
  const tagA = tagIn * (1 - cond); // the tagline is the sand's source
  const markA = cond;
  const markScale = 1 + 0.06 * (1 - lock);
  const credits = ramp(f, Math.round(0.74 * durationInFrames), 24, EASE.out);
  const SAND = Array.from({ length: 160 }, (_, i) => {
    const r = (k: number) => rand(i * 13.7 + k * 101.3);
    const ang = r(3) * Math.PI * 2;
    return { hx: 360 + r(1) * 1200, hy: 470 + r(2) * 70, dx: Math.cos(ang) * (30 + r(4) * 90), dy: Math.sin(ang) * (20 + r(5) * 50), tx: 600 + r(6) * 720, ty: 470 + r(7) * 110, size: 1.2 + r(8) * 2.4, alpha: 0.25 + r(9) * 0.6, lag: r(10) * 0.05 };
  });
  return (
    <AbsoluteFill style={{ background: C.inkDeep }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 60% 50% at 50% 48%, #1a2238 0%, ${C.inkDeep} 75%)` }} />
      <svg width={1920} height={1080} style={{ position: 'absolute', inset: 0 }}>
        <defs>
          <filter id={`g${uid}`} x="-20%" y="-150%" width="140%" height="400%" colorInterpolationFilters="sRGB">
            <feTurbulence type="fractalNoise" baseFrequency={0.9 + burst * 0.4} numOctaves={2} seed={boil} result="n" />
            <feDisplacementMap in="SourceGraphic" in2="n" scale={burst * 150 * (1 - lock)} xChannelSelector="R" yChannelSelector="G" result="d" />
            <feGaussianBlur in="d" stdDeviation={burst * 3 * (1 - lock)} result="core" />
            <feGaussianBlur in="core" stdDeviation={3 + glow * 5} result="g1" />
            <feColorMatrix in="g1" type="matrix" result="g1c" values={`0 0 0 0 0.96  0 0 0 0 0.64  0 0 0 0 0.36  0 0 0 ${(0.15 + glow * 0.95).toFixed(3)} 0`} />
            <feGaussianBlur in="core" stdDeviation={15 + glow * 18} result="g2" />
            <feColorMatrix in="g2" type="matrix" result="g2c" values={`0 0 0 0 0.91  0 0 0 0 0.27  0 0 0 0 0.17  0 0 0 ${(glow * 0.6).toFixed(3)} 0`} />
            <feMerge><feMergeNode in="g2c" /><feMergeNode in="g1c" /><feMergeNode in="core" /></feMerge>
          </filter>
        </defs>
        <g filter={`url(#g${uid})`}>
          {tagA > 0.01 && (
            <text x={960} y={530} textAnchor="middle" fontFamily="EB Garamond" fontStyle="italic" fontSize={72} fill={C.parchment} opacity={tagA}>
              Fall. Rewind. Remember.
            </text>
          )}
          {markA > 0.01 && (
            <text x={960} y={575} textAnchor="middle" fontFamily="Cinzel" fontWeight={800} fontSize={150} letterSpacing={10} fill={C.parchment} opacity={markA} transform={`translate(960 530) scale(${markScale}) translate(-960 -530)`}>
              AETERNA
            </text>
          )}
        </g>
        {/* free grains: blown out of the tagline, drawn into the wordmark */}
        {SAND.map((s, i) => {
          const away = burst * (1 - cond);
          const pull = seg(cond, s.lag, 1, E.inOutCubic);
          const x = (s.hx + s.dx * away) * (1 - pull) + s.tx * pull;
          const y = (s.hy + s.dy * away) * (1 - pull) + s.ty * pull;
          const a = s.alpha * Math.min(1, burst * 2) * (1 - lock);
          return a > 0.01 ? <circle key={i} cx={x} cy={y} r={s.size} fill={i % 3 ? C.glow : C.gold} opacity={a} /> : null;
        })}
      </svg>
      <div style={{ position: 'absolute', top: 690, width: '100%', textAlign: 'center', opacity: credits, transform: `translateY(${((1 - credits) * 16).toFixed(1)}px)` }}>
        <div style={{ fontFamily: FONTS.body, fontSize: 40, color: C.parchment2 }}>For Meta Quest · Made in Godot</div>
        <div style={{ fontFamily: FONTS.body, fontSize: 32, color: C.parchment2, marginTop: 14, opacity: 0.8 }}>Captured from the in-game VR view</div>
      </div>
    </AbsoluteFill>
  );
};
