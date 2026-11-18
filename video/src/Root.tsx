import React from 'react';
import { Composition } from 'remotion';
import { Demo, FPS, layout } from './Demo';

export const Root: React.FC = () => {
  const end = layout().end;
  return (
    <>
      <Composition id="AeternaDemo" component={Demo} durationInFrames={end} fps={FPS} width={1920} height={1080} defaultProps={{ music: true }} />
      <Composition id="AeternaDemoNoMusic" component={Demo} durationInFrames={end} fps={FPS} width={1920} height={1080} defaultProps={{ music: false }} />
    </>
  );
};
