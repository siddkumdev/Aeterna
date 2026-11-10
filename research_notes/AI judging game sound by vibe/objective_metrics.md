# Objective audio metrics and Python libraries for matching game SFX to a reference and detecting defects (as of 2026-11)

Scope: what an agent that cannot hear can measure to judge short sound effects (brightness, warmth, punch, muffled, crunchy/lo-fi, harsh, boomy, loudness), how to turn a reference clip into target numbers, and how to catch defects. Free tools, Python, Windows 11, analysis only.

## Features and their perceptual meaning (how well they predict listener ratings)

### Takeaway
The best-validated single descriptors for SFX are the Audio Commons timbral models (trained/validated on listener ratings of mostly non-musical, Freesound-style sounds): hardness, depth, brightness r of about 0.86 to 0.93, warmth and sharpness about 0.78 to 0.79, roughness 0.56 to 0.70, boominess the weakest at 0.67. Spectral centroid alone is only a moderate brightness predictor (r about 0.51); "punch" has its own validated model (Fenton, r about 0.85) that beats crest factor and PLR.

### Cited Findings
- Audio Commons `timbral_models` predicts hardness, depth, brightness, roughness, warmth, sharpness, booming and reverberation. Seven are regression models trained on 0 to 100 listener ratings (outputs can go outside that range; `clip_output=True` clamps); reverb is a binary classifier — [GitHub AudioCommons/timbral_models](https://github.com/AudioCommons/timbral_models)
- Licence Apache-2.0; `pip install timbral_models`; deps numpy, soundfile, librosa, scikit-learn, scipy, six, pyloudnorm; v0.4 removed the essentia dependency; latest v0.4.1 (2024-05-24) fixed a scikit-learn issue; the repo says it "is no longer maintained" — [GitHub AudioCommons/timbral_models](https://github.com/AudioCommons/timbral_models)
- D5.7 evaluation (v0.3 models), against listener ratings on the new datasets: hardness r=0.87 / rho=0.84; depth r=0.89 / rho=0.86; brightness r=0.86 / rho=0.83 (and r=0.93 / rho=0.91 in a validation set referenced in the report); warmth r=0.79 / rho=0.79; sharpness r=0.78 / rho=0.83 (possibly nonlinear, scale bounds unknown); boominess r=0.67 / rho=0.67 (worst); roughness r=0.70 / rho=0.71 on new data but r=0.56 / rho=0.53 on the older D5.3 data; reverb classifier 75.25 % accuracy — [Audio Commons D5.7 report (PDF)](https://audiocommons.github.io/assets/files/AC-WP5-Surrey-D5.7%20Evaluation%20report%20on%20the%20second%20prototypes%20of%20the%20timbral%20characterisation%20tools.pdf)
- Datasets: e.g. warmth 185 files over 32 source types, brightness 210 stimuli over 33 source types, rated by 13 trained undergraduate listeners (Surrey Music and Sound Recording); boominess only 102 files / 6 listeners with very large confidence intervals — [D5.7](https://audiocommons.github.io/assets/files/AC-WP5-Surrey-D5.7%20Evaluation%20report%20on%20the%20second%20prototypes%20of%20the%20timbral%20characterisation%20tools.pdf)
- What the models are made of: brightness = ratio of high-frequency energy to total energy plus spectral centroid above a cut-off (6th-order filters, crossovers tuned for correlation); warmth = multilinear regression on selected features; sharpness = direct implementation of the Fastl and Zwicker sharpness model (Klippel implementation); boominess = Hatano and Hashimoto boominess index, designed for in-car road noise, so it "may require some modifications" for other uses — [D5.7](https://audiocommons.github.io/assets/files/AC-WP5-Surrey-D5.7%20Evaluation%20report%20on%20the%20second%20prototypes%20of%20the%20timbral%20characterisation%20tools.pdf)
- Earlier D5.3 evaluation: depth, brightness, roughness Spearman rho 0.78, 0.74, 0.84 — [search summary of D5.3](https://audiocommons.github.io/assets/files/AC-WP5-Surrey-D5.3%20Evaluation%20report%20on%20the%20first%20prototypes%20of%20the%20timbral%20characterisation%20tools.pdf) (figures from a search snippet, PDF not opened)
- Independent check (DAGA 2025, Czedik-Eysenberg and Reuter): brightness correlations with the AudioCommons sharpness model show strong pitch dependency — [DAGA 2025 paper](https://homepage.univie.ac.at/christoph.reuter/unterwegs/DAGA2025_Czedik-Eysenberg_Reuter_PAPER.pdf) (from search snippet)
- Spectral centroid and brightness: Schubert and Wolfe (2006) found centroid alone predicted brightness at r=0.513, versus r=0.030 for centroid relative to the fundamental — [Schubert & Wolfe 2006 (PDF)](https://www.phys.unsw.edu.au/jw/reprints/SchubertWolfe06.pdf) (via search summary). Later work: brightness is not purely spectral; faster attacks can make sounds seem brighter at similar centroid — [QMUL / Saitis et al. (PDF)](https://comma.eecs.qmul.ac.uk/assets/pdf/s13414-024-02934-2.pdf) (via search summary)
- Punch (Fenton, Lee, Wakefield, Huddersfield): punch score is a weighted sum of onset-time and octave-band transient-loudness parameters, weights from listening tests with noise bursts; PM95 output had Pearson r=0.849, Spearman rho=0.833 with punch ratings (JAES 2019, vol. 67 no. 6); compared against crest factor, inter-band ratio, peak-to-loudness ratio (PLR) and loudness dynamic range; a real-time metering plug-in exists (Perceptual Punch Tool, VST/AU, Zenodo 2021) — [Huddersfield: evaluation with music material](https://pure.hud.ac.uk/en/publications/evaluation-of-a-perceptually-based-model-of-punch-with-music-mate/); [weighted transient loudness](https://pure.hud.ac.uk/en/publications/a-perceptual-model-of-punch-based-on-weighted-transient-loudness/); [real-time system](https://pure.hud.ac.uk/en/publications/real-time-system-for-the-measurement-of-perceived-punch/)
- Loudness: pyloudnorm implements ITU-R BS.1770 (`Meter(rate)`, `integrated_loudness`, `loudness_range`), default gating block 400 ms, configurable `block_size` (e.g. 0.200) and filter classes ("DeMan", "Fenton/Lee 1/2", "Dash et al.", custom); helpers `normalize.peak` and `normalize.loudness`; MIT — [GitHub csteinmetz1/pyloudnorm](https://github.com/csteinmetz1/pyloudnorm)

### Inferences
- Practical mapping (inference, built from the sources above plus standard DSP): bright / harsh = high timbral brightness and sharpness, high centroid and rolloff, more 2 to 8 kHz energy; muffled = the opposite (low rolloff, steep negative spectral tilt); warm = timbral warmth, energy in roughly 100 Hz to 1 kHz relative to highs; boomy = boominess plus low-band (<200 Hz) energy ratio, but trust it least (r=0.67); crunchy / distorted = roughness, high spectral flatness in highs, inharmonic partials; punch = Fenton PM95 if implementable, otherwise attack time plus crest factor / PLR as weaker proxies (Fenton shows those were beaten by the model).
- Clips shorter than the 400 ms BS.1770 block are a real risk for SFX (many hits are 100 to 300 ms). Using pyloudnorm's `block_size` (e.g. 0.1 or 0.2) or zero-padding and also reporting momentary/short-term peak and plain RMS is the safe approach. Not verified what pyloudnorm returns for sub-block clips (likely -inf or an error); test it.
- The Audio Commons models were rated by trained listeners on mixed source types, which is closer to game SFX than music-trained metrics. Use them as relative comparisons (ours vs reference), not as absolute truths.
- Use rank comparisons (is ours brighter or darker than the reference, by how much relative to the reference set's spread) rather than absolute thresholds.

### Gaps
- No primary source fetched for Timbre Toolbox (Peeters et al. 2011) descriptor list or for MFCC-based perceptual studies; not covered here.
- No study found that validates any metric specifically on game SFX ratings.
- No Python implementation of the Fenton punch model was found (only the VST/AU plug-in); reproducing it needs the JAES paper's coefficients.
- Zwicker roughness/sharpness in Python beyond timbral_models (e.g. MoSQITo) was not researched in this pass.

## Defect detection and quality metrics (do they apply to SFX?)

### Takeaway
Defects like clipping are best caught by simple signal checks (amplitude-histogram tails, runs of samples at the peak); learned quality scorers are mostly built for speech. Meta's Audiobox Aesthetics is the one non-intrusive scorer trained on sound effects too, but its correlation with human ratings on sound is moderate (r about 0.57 to 0.65). ViSQOL audio mode is intrusive (needs a clean reference of the same sound), so it fits "did my processing damage this?", not "is this good?".

### Cited Findings
- Clipping detection via amplitude histogram: clipped signals show "outbursts" on the histogram tails while clean ones decay smoothly (Aleinik, Matveev, Sholokhov 2014) — [Vestnik ITMO (PDF)](https://openbooks.itmo.ru/read_ntv/10379/10379.pdf); Laguna and Lerch (AES 141, 2016) use histogram plus time-domain shape, detection f-measure 0.92, robust to clipping level — [researchr: Laguna 2016](https://researchr.org/publication/lagunaefficient2016); Google patent US9426592 uses a histogram local maximum near the top bins and also detects soft clipping — [US9426592B2](https://patents.google.com/patent/US9426592) (all via search summaries, full texts not opened)
- Audiobox Aesthetics (Meta, 2025): four axes on a 1 to 10 scale: Production Quality (clarity, fidelity, dynamics, frequency balance, spatialization), Production Complexity (number of components), Content Enjoyment, Content Usefulness (as source material for creation). Trained on about 500 hours / 97k clips split evenly over speech, sound and music, 158 raters; the "sound" domain includes sound events and ambience — [arXiv 2502.05139](https://arxiv.org/html/2502.05139v1)
- Audiobox Aesthetics on sound (PAM-sound, utterance-level Pearson r): PQ 0.617, PC 0.654, CE 0.638, CU 0.573; natural-sound subset higher (PQ 0.728, CE 0.763). On PAM-sound the PAM baseline correlates better with overall quality (0.650) than its CE (0.464). Limitations: no synthetic audio in training, small sound evaluation sets, CU overlaps with CE/PC for sound — [arXiv 2502.05139](https://arxiv.org/html/2502.05139v1)
- Audiobox Aesthetics install: `pip install audiobox_aesthetics`, Python 3.9+, PyTorch 2.2+; CLI `audio-aes input.jsonl --batch-size 100`; Python `initialize_predictor().forward(...)`; licence mostly CC-BY 4.0, parts MIT; weights licence not stated separately — [GitHub facebookresearch/audiobox-aesthetics](https://github.com/facebookresearch/audiobox-aesthetics)
- ViSQOL audio mode expects 48 kHz input (resample both files); speech mode is 16 kHz. Pure-Python port `pip install visqol-python` needs no C++ build (numpy, scipy, soundfile, libsvm-official); API `VisqolApi().create(mode="audio").measure(ref, deg)`; CLI `python -m visqol -r ref.wav -d deg.wav`. The official C++ ViSQOL has no Windows binary and needs Bazel to build — [PyPI visqol-python](https://pypi.org/project/visqol-python/); [DEV: building ViSQOL on Windows](https://dev.to/peterleif/visqol-how-to-build-and-use-on-windows-1e88) (via search summaries)
- DNSMOS was built to score speech noise suppressors; NISQA predicts quality of transmitted super-wideband speech; UTMOS targets synthesized speech; summaries report saturation at high quality — [DNSMOS arXiv 2010.15258](https://arxiv.org/pdf/2010.15258); [Emergent Mind summary (secondary)](https://www.emergentmind.com/topics/objective-audio-quality-metrics)

### Inferences
- For SFX, the reliable defect checks are hand-written signal tests (inference, standard DSP; thresholds are suggestions to tune):
  - Clipping: count runs of 3+ consecutive samples within about 0.1 dB of the file peak, sample peak at or above -0.1 dBFS, plus histogram tail spike; true-peak by 4x oversampling.
  - DC offset: |mean| > about 0.001 (-60 dBFS) of full scale.
  - Clicks / discontinuities: large outliers in the first difference (or high-pass residual) relative to its median; non-zero first/last sample (missing fades) causes clicks at start/stop.
  - Bit-crush / quantisation: count distinct sample values (a 16-bit-looking file with few hundred levels is crushed); raised flat noise floor in quiet tail.
  - Aliasing / sample-rate reduction / codec: spectral rolloff or a hard brick-wall cut well below Nyquist (e.g. 11 or 16 kHz shelf) indicates low-rate or lossy source; inharmonic mirror components after distortion.
  - Distortion / THD: only measurable cleanly with a test tone through the same chain; for arbitrary SFX use roughness and high-band spectral flatness as proxies.
- Audiobox Aesthetics PQ is a reasonable coarse "is this obviously bad?" screen for SFX, trained on 10 to 30 s clips; behaviour on 0.1 to 1 s game hits is untested (possible padding or tiling needed). Treat its numbers as relative between our versions, not as approval.
- ViSQOL is useful after processing a clip (EQ match, loudness change) to confirm the processed version has not degraded vs the original; it cannot say whether ours matches a different reference sound.
- DNSMOS / NISQA / UTMOS / PESQ are speech metrics and should not be used on SFX.

### Gaps
- PEAQ (ITU-R BS.1387): no maintained free Python implementation on Windows was found in this pass.
- No source evaluating Audiobox Aesthetics on very short clips (<1 s).
- Full texts of the clipping papers were not opened; detection thresholds not taken from them.

## Distribution metrics (FAD, KID) for comparing a small set of our sounds with a game reference set

### Takeaway
FAD is biased by sample size and depends heavily on the embedding; with a handful of SFX it is unreliable as a single number. Use fadtk's per-sample FAD or simple embedding distances (e.g. CLAP cosine to the reference set) for ranking our sounds, and report sample counts.

### Cited Findings
- Gui et al. (Microsoft, ICASSP 2024) "Adapting Frechet Audio Distance for Generative Music Evaluation": FAD scores shift with number of samples; they propose extrapolating to infinite sample size (FAD-inf, fit FAD(N) = FAD-inf + beta/N); embedding choice matters; reference set must be diverse and high quality; per-song FAD helps find outliers and predicts perceptual quality — [arXiv 2311.01616](https://arxiv.org/abs/2311.01616v2)
- fadtk (MIT, `pip install fadtk` after installing torch; test `python -m fadtk.test`): embeddings CLAP (clap-2023, LAION audio/music), EnCodec, MERT, VGGish, DAC, CDPAM, wav2vec2, HuBERT, WavLM, Whisper; `--indiv` gives per-sample scores; `--inf` FAD-inf; tested on Python 3.12 Linux, "should work" on Windows; warns VGGish is optimised for classification and may not suit quality; no minimum sample count given, advises reporting counts and durations — [GitHub microsoft/fadtk](https://github.com/microsoft/fadtk)
- `frechet_audio_distance` (gudgud96, MIT, `pip install frechet_audio_distance`): VGGish and PANN at 16 kHz, CLAP and EnCodec at 48 kHz (EnCodec stereo); also a CLAP text-audio score; does not discuss small-sample bias — [GitHub gudgud96/frechet-audio-distance](https://github.com/gudgud96/frechet-audio-distance)

### Inferences
- FAD fits a Gaussian (mean + covariance) to embeddings of size 128 to 2048; with 5 to 20 of our clips the covariance is degenerate, so set-level FAD is not meaningful. Better for small sets (inference): mean embedding cosine similarity to the reference set, nearest-neighbour distance, or per-sample FAD against a larger reference set; KID (kernel, unbiased) is the usual small-sample alternative but no SFX-specific implementation was checked.
- Embeddings like CLAP capture "what sound is this" more than "is the EQ right"; combine them with the handcrafted timbral numbers above.
- Reference SFX from a commercial game can only be used for analysis (numbers), which fits the project's no-third-party-assets rule if the clips are never shipped; this is a licensing judgment for the team, not researched here.

### Gaps
- No study of FAD/KID on game SFX or on sets under 50 clips.
- Which embedding best tracks SFX quality (CLAP vs PANNs vs EnCodec) is not established in the sources found.

## Libraries: licences, Windows install, speed

### Takeaway
On Windows, the low-friction stack is librosa + scipy/numpy + soundfile + pyloudnorm + timbral_models (all pip, permissive licences) plus visqol-python and audiobox_aesthetics/fadtk if PyTorch is acceptable. Essentia has no Windows wheels and is AGPL-3.0, so avoid it on this machine (WSL would be the route if needed).

### Cited Findings
- essentia on PyPI: latest 2.1b6.dev1438 (2026-05-19, pre-release); wheels only for Linux x86-64, macOS 15 x86-64/ARM64, CPython 3.14; no Windows wheel, no sdist; AGPL-3.0-only — [PyPI essentia](https://pypi.org/project/essentia/)
- timbral_models: Apache-2.0, pip, no longer maintained, last release 2024-05-24 — [GitHub](https://github.com/AudioCommons/timbral_models)
- pyloudnorm: MIT, pip — [GitHub](https://github.com/csteinmetz1/pyloudnorm)
- fadtk: MIT, needs torch, "should work" on Windows — [GitHub](https://github.com/microsoft/fadtk); frechet_audio_distance: MIT — [GitHub](https://github.com/gudgud96/frechet-audio-distance)
- audiobox_aesthetics: CC-BY 4.0 / MIT, Python 3.9+, torch 2.2+ — [GitHub](https://github.com/facebookresearch/audiobox-aesthetics)
- visqol-python: pure Python, no compilation — [PyPI](https://pypi.org/project/visqol-python/)

### Inferences
- librosa (ISC licence, pure Python wheels) provides centroid, rolloff, flatness, bandwidth, contrast, MFCC, onset strength, RMS; torchaudio is optional. Not fetched in this pass; licence and Windows status from general knowledge, verify on PyPI.
- timbral_models being unmaintained means pinning older librosa/scikit-learn may be needed; test in a venv.
- Speed: handcrafted features run in milliseconds per short clip on CPU; embedding models (CLAP, Audiobox) load hundreds of MB and are slower but fine on CPU for tens of clips (inference, not measured).

### Gaps
- No measured install test on Windows 11 for timbral_models, fadtk, audiobox_aesthetics in this pass.
- librosa / torchaudio pages not fetched.

## Reference matching techniques (EQ, loudness, transient)

### Takeaway
Match EQ = ratio of smoothed long-term average spectra (reference / ours), turned into a filter (often minimum phase). This is straightforward in numpy/scipy; loudness matching via pyloudnorm; transient matching via attack-time and crest-factor targets.

### Cited Findings
- EQ-match method from the Linux Audio Dev list (2023): average magnitude spectra of both tracks, bin-wise ratio, build a minimum-phase filter via complex log, IFFT, fold negative time onto positive, FFT, exponentiate, IFFT; reference implementation `eq_match.h` in the fps-plugins LV2 repo — [linux-audio-dev archive](https://lists.linuxaudio.org/hyperkitty/list/linux-audio-dev@lists.linuxaudio.org/2023/6)
- DeepAFX-ST baseline (Python/PyTorch): average magnitude spectrum via STFT over frames, Savitzky-Golay smoothing (window 1025, order 2), divide reference by input curve, design an inverse FIR from that response — [huggingface deepafx-st baselines.py](https://huggingface.co/spaces/mikeross/deepafx-st/blob/main/deepafx_st/models/baselines.py)
- LTAS-based equalisation is known but limited: louder sections skew the average, bandlimited material causes problems — [arXiv 2403.18636](https://arxiv.org/pdf/2403.18636)
- Minimum-phase filtering avoids pre-ringing on steep slopes (relevant for transients) — [Voxengo CurveEQ guide](https://www.voxengo.com/files/userguides/VoxengoCurveEQ_en.pdf/getbyname/Voxengo%20CurveEQ%20User%20Guide%20en.pdf)
- Commercial equivalents: Logic Match EQ, Ozone Match EQ — [Apple Match EQ overview](https://help.apple.com/logicpro-effects/mac/10.2/en.lproj/lgcef1edbfbe.html)
- Loudness normalisation: `pyln.normalize.loudness(data, measured, target)` — [pyloudnorm](https://github.com/csteinmetz1/pyloudnorm)

### Inferences
- Recipe (inference, standard DSP, to implement and verify):
  1. Load both at the same rate (e.g. 48 kHz, mono), trim silence, loudness-normalise both to the same LUFS (short block) first so the EQ curve only captures shape.
  2. STFT (n_fft 4096 to 8192), mean power per bin over frames above an energy gate (avoids silent tails dominating), convert to dB.
  3. Smooth in fractional octaves (1/3 to 1/6 octave) rather than linear bins; difference dB = ref - ours; clamp to about +/-12 dB and taper to 0 below ~30 Hz and above ~18 kHz (or where either has no energy) so noise is not boosted.
  4. Build a linear-phase FIR with `scipy.signal.firwin2` from the dB curve, then `scipy.signal.minimum_phase` for a transient-friendly version; apply with `scipy.signal.fftconvolve`; optionally apply only a fraction (e.g. 50 to 75 %) of the correction, as match-EQ plug-ins expose an amount control.
  5. Re-measure centroid, rolloff, band ratios, timbral brightness/warmth and ViSQOL(original, processed) to confirm the move went the right way without damage.
- Transient matching: compare attack time (10 % to 90 % of envelope peak), crest factor, PLR and onset-strength peak; adjust with a transient shaper or envelope gain curve rather than EQ.
- For short SFX, one STFT average per clip is noisy; averaging over a set of reference clips of the same category (all impacts, all whooshes) gives a steadier target curve, which also answers "turn a reference into target numbers": store per-category mean and spread of each feature, and flag ours when outside about 1 to 2 spreads.

### Gaps
- `eq_match.h` and the DeepAFX code were not opened beyond summaries; scipy function behaviour stated from general knowledge.
- No validated study on how closely LTAS matching makes short SFX "sound like" the reference.
