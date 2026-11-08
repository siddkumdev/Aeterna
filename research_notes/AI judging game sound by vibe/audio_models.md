# Audio-understanding models that let a non-hearing AI agent judge game sound effects (as of 2026-11-09)

Scope: models that LISTEN (describe, score, embed). Generators are out of scope (project forbids AI-generated audio). Research done 2026-11-09 with ~18 web lookups; items marked "prior knowledge, unverified" were not checked against a source in this session.

## 1. Audio-language / captioning models and cloud APIs: licence, size, hardware, cost, timbre ability

### Takeaway
The strongest open model for describing sound is Qwen3-Omni (and its audio-only Captioner, Apache-2.0), but it is a 30B MoE that needs a ~20 GB+ GPU even quantized; the cheapest practical "ears" for a Windows laptop agent is a cloud call to Gemini (Flash-Lite tiers at $0.30/1M input tokens, 25 tokens per second of audio, so a 3 s SFX costs a tiny fraction of a cent, free tier available). The only direct psychophysical test found (SonicBench, Jan 2026) shows all audio LLMs are well below humans on timbre (best ~0.73 vs human ~0.97), and GPT-4o-Audio scored near chance (~0.46) on timbre, so LLM words like "warm" or "crunchy" should be treated as noisy and cross-checked with measured features.

### Cited Findings

**Perceptual / timbre evidence (most relevant to "vibe" judging)**
- SonicBench (arXiv 2601.11039, Jan 2026) tests 36 systems on 12 physical attributes in five dimensions: Spectral & Amplitude (pitch, brightness, loudness, velocity), Temporal (duration, tempo), Spatial (direction, distance, reverberation), Timbre (timbre, texture), Scene (counting). — [SonicBench](https://arxiv.org/html/2601.11039v1)
- SonicBench overall: humans 91%, best model Qwen3-Omni 72%, about half of models near the 50% random baseline. — [SonicBench](https://arxiv.org/html/2601.11039v1)
- SonicBench timbre (comparison+recognition averaged, as extracted from tables): human ~0.97 (texture 1.00); Qwen3-Omni ~0.73 (texture 0.99); Kimi-Audio, best "LALM", ~0.59 (texture 0.97); GPT-4o-Audio ~0.46 (texture 0.92). Gemini-2.5-Flash was also evaluated (its timbre number was not extracted). — [SonicBench](https://arxiv.org/html/2601.11039v1)
- SonicBench: models often do worse at relational comparison ("which of A/B is brighter") than at recognition, unlike humans. — [SonicBench](https://arxiv.org/html/2601.11039v1)
- SonicBench: linear probes on frozen audio encoders reach >=0.60 and beat most end-to-end LLMs (~0.50), so the cues exist in encoders and the bottleneck is alignment/decoding; Qwen2.5-Omni and Qwen3-Omni are exceptions that match or beat their probes. Timbre is a partial exception where even probes often fall below 0.60. — [SonicBench](https://arxiv.org/html/2601.11039v1)
- Models covered by SonicBench include Kimi-Audio, Qwen2-Audio, Audio Flamingo 2, Audio Flamingo 3 (think), SALMONN, Qwen2.5-Omni, Qwen3-Omni, Voxtral, Step-Audio-2, MiDashengLM, Mellow, GAMA, GPT-4o-Audio, Gemini-2.5-Flash. — [SonicBench](https://arxiv.org/html/2601.11039v1)

**Qwen family**
- Qwen3-Omni-30B-A3B-Captioner: Apache-2.0; ~32B params BF16 (30B total, 3B active MoE); audio-only input, no text prompt, text output, single clip per call; recommended <=30 s; captions cover environmental sounds, music, cinematic sound effects, emotions, ambient atmosphere (timbre not explicitly named). Needs transformers from GitHub source, `qwen-omni-utils` (needs ffmpeg), FlashAttention 2 recommended; vLLM recommended via a specific fork built from source. — [HF model card](https://huggingface.co/Qwen/Qwen3-Omni-30B-A3B-Captioner)
- Qwen3-Omni Instruct/Thinking/Captioner released under Apache 2.0 per the technical report summary. — [EmergentMind summary of arXiv 2509.17765](https://www.emergentmind.com/papers/2509.17765)
- Third-party estimate: ~19 GB VRAM to run Qwen3-Omni 30B-A3B at Q4 (base model, not the Captioner; unofficial). Hosted Captioner listed at $3.81 / 1M input tokens on one provider. — [cloudprice.net](https://cloudprice.net/models/alibaba-qwen3-omni-30b-a3b-captioner)
- Qwen2.5-Omni-3B: licence "qwen-research" (not Apache). BF16 theoretical minimum GPU memory 18.38 GB (15 s video), 22.43 GB (30 s), 28.22 GB (60 s), real use >=1.2x; audio-only use supported with `return_audio=False`; `model.disable_talker()` saves ~2 GB. MMAU: Sound 70.27, Music 60.48, Speech 59.16, avg 63.30. — [HF model card](https://huggingface.co/Qwen/Qwen2.5-Omni-3B)
- Qwen2-Audio-7B-Instruct: Apache-2.0. — [HF model card](https://huggingface.co/Qwen/Qwen2-Audio-7B-Instruct)
- Third-party GPU-cloud guides for a newer Qwen3.5-Omni exist (deployment only; not verified as official). — [Spheron](https://www.spheron.network/blog/deploy-qwen3-5-omni-gpu-cloud)

**NVIDIA Audio Flamingo**
- Audio Flamingo 3 (chat): NVIDIA OneWay Noncommercial Licence, "non-commercial research purposes only"; Qwen2.5-7B backbone + AF-Whisper encoder; designed for A100/H100, tested on A100 80 GB; Linux only; up to 10 min audio. — [HF model card](https://huggingface.co/nvidia/audio-flamingo-3-chat)
- Audio Flamingo 2: 3B decoder LM + 203M audio encoder. — [AF2 paper](https://arxiv.org/pdf/2503.03983)
- Original Audio Flamingo zero-shot AudioCaps CIDEr 50.2 (listing). — [Papers with Code mirror](https://astro.paperswithcode.com/paper/audio-flamingo-a-novel-audio-language-model)

**Others**
- SALMONN (ByteDance): repo Apache-2.0 (weights licence not stated separately); 13B (2023-10) and 7B (2023-11) checkpoints; a SALMONN branch for speech quality assessment (ICASSP/ACL 2025); newer video-SALMONN 2 and ELLSA (ICLR 2026). No VRAM figure given. — [GitHub](https://github.com/bytedance/SALMONN)
- Kimi-Audio: code, checkpoints and eval toolkit released; claims to beat Qwen2-Audio-base and Qwen2.5-Omni on several audio benchmarks; licence shown only as "other" on a mirror. — [Kimi-Audio report](https://arxiv.org/pdf/2504.18425); [HyperAI](https://beta.hyper.ai/en/notebooks/39599)
- MMAU benchmark: 10k curated clips with human-annotated QA across speech, environmental sound, music. — [benchmarklist](https://benchmarklist.com/benchmarks/mmau/)

**Cloud APIs**
- Gemini (AI Studio pricing page fetched 2026-11-09): audio input per 1M tokens, paid Standard tier: Gemini 3.5 Flash-Lite $0.30 (free tier yes); 3.1 Flash-Lite $0.50 (free yes); 3 Flash Preview $1.00 (free yes); 3.6 / 3.8 Flash $0.75 input (single rate, through 2026-12-31, then $1.50; free yes); 3.1 Pro Preview $2.00 (no free tier); 2.5 Flash $1.00 and 2.5 Flash-Lite $0.30. 2.5 Flash and 2.5 Pro are deprecated; from 2026-12-01 2.5 Flash requests route to 3.5 Flash-Lite. Page states "25 tokens per second of audio". — [Gemini API pricing](https://aistudio.google.com/docs/pricing)
- Conflict: Gemini token docs elsewhere state 32 tokens per second; current pricing page says 25. — [Gemini token docs](https://ai.google.dev/gemini-api/docs/tokens?lang=go); [Gemini pricing](https://aistudio.google.com/docs/pricing)
- OpenAI gpt-audio / gpt-audio-1.5 (Chat Completions; replaces deprecated gpt-4o-audio-preview): audio input $32 / 1M tokens, audio output $64 / 1M; text input $2.50. — [OpenAI gpt-audio-1.5](https://developers.openai.com/api/docs/models/gpt-audio-1.5); [OpenAI gpt-audio](https://developers.openai.com/api/docs/models/gpt-audio)
- Claude: no official evidence of raw audio input in the Messages API; open feature requests dated 2026-02-24 and 2026-07-02 ask for it; consumer voice input is speech-to-text before Claude. Some content-farm blogs claim otherwise (discounted). — [GitHub SDK issue](https://github.com/anthropics/anthropic-sdk-python/actions/runs/22354407550); [Claude issue](https://claudeissues.com/issue/73566-feature-allow-claude-to-hear-and-process-audio); [Anthropic privacy page](https://privacy.anthropic.com/zh-CN/articles/10067984-在claude移动应用程序上使用语音输入功能时会收集哪些个人数据)

### Inferences
- Cost: a 3 s SFX = ~75 audio tokens at 25 tok/s; at $0.30/1M (3.5 Flash-Lite) that is ~$0.00002 per clip plus prompt/output tokens, so hundreds of judgments cost cents. GPT-audio is ~100x dearer per audio token ($32 vs $0.30) and scored worst on SonicBench timbre, so it is the weakest pick.
- On Windows 11 without a 24 GB+ NVIDIA GPU, Qwen3-Omni and AF3 are effectively not runnable locally (AF3 is also Linux-only and non-commercial, a poor fit for a game shipped at a hackathon). Qwen2.5-Omni-3B and Qwen2-Audio-7B may fit a 24 GB card; CPU inference of 3-7B audio LLMs is likely impractically slow (not measured).
- Best LLM practice for vibe judging (from SonicBench's comparison weakness): ask for absolute descriptions/scores of single clips and anchor them with measured numbers, rather than trusting A-vs-B comparative judgments.
- Very short clips (0.1-0.5 s) are under-represented in captioning datasets (AudioCaps/Clotho are ~10-30 s); expect weaker descriptions on tiny transients (inference, not tested).

### Gaps
- No AudioCaps/Clotho CIDEr or MMAU numbers verified for Qwen3-Omni, AF3, Kimi-Audio, Gemini 3.x in this session (AF3 card has charts only).
- No study found that tests audio LLMs specifically on SFX production words ("distorted/crunchy", "low-passed/muffled", "punchy transient", "lo-fi"). SonicBench brightness/timbre/texture is the closest proxy; AIR-Bench / AudioBench numbers not retrieved.
- Licences of LTU / LTU-AS / Pengi not found; Kimi-Audio licence text not confirmed.
- Gemini 3.x per-model timbre accuracy not measured anywhere found.

## 2. Text-audio embedding models (CLAP family) for scoring a clip against adjectives

### Takeaway
LAION-CLAP (CC0-1.0, pip `laion-clap`, also in HF transformers) is the best-documented free option and, in the only timbre-specific study found (Deng, Pardo, Pappas, Oct 2025), aligned best with human timbre semantics (brightness, roughness, warmth) among MS-CLAP, LAION-CLAP, MuQ-MuLan and OpenFLAM, but alignment was only "partial", and EQ-induced timbre changes (exactly "muffled/bright") are encoded less consistently than reverb.

### Cited Findings
- LAION-CLAP: CC0-1.0; checkpoints 630k-audioset-best (clips <10 s, pip default non-fusion), 630k-audioset-fusion-best (variable length), music, music+speech, music+speech+audioset (HTSAT-base); load at 48 kHz; `pip install laion-clap`; supported in HF Transformers; examples use CUDA, no CPU notes. — [GitHub LAION-AI/CLAP](https://github.com/LAION-AI/CLAP)
- "Do joint language-audio embeddings encode perceptual timbre semantics?" (arXiv 2510.14249, Deng/Pardo/Pappas): tests MS-CLAP, LAION-CLAP, MuQ-MuLan, OpenFLAM on instrument sounds and descriptor-conditioned audio effects (reverb, EQ); LAION-CLAP shows "relatively strong and consistent alignment"; overall alignment limited; reverb semantics encoded more consistently than EQ. — [arXiv 2510.14249](https://arxiv.org/abs/2510.14249)
- Microsoft CLAP (`pip install msclap`, Python 3.8+, 3.11 recommended): 2022 and 2023 weights (`version='2023'`), plus `clapcap` captioner using the 2023 encoders; HF card tagged MS-PL licence. — [HF microsoft/msclap](https://huggingface.co/microsoft/msclap/raw/main/README.md); [PyPI msclap](https://pypi.org/project/msclap/1.3.2.post1); [Zenodo weights](https://zenodo.org/record/8378278)
- M2D-CLAP (NTT, Interspeech 2024; IEEE Access 2025 version arXiv 2503.22104): code and weights at github.com/nttcslab/m2d; licence not confirmed. — [arXiv 2406.02032](https://arxiv.org/abs/2406.02032v1); [arXiv 2503.22104](https://arxiv.org/abs/2503.22104v2)
- CLAP audio encoders are commonly PANNs (CNN) or HTSAT; CLAP retrieval is cosine similarity in a shared space and needs no human annotations. — [Sound-search UX study, arXiv 2504.15575](https://arxiv.org/pdf/2504.15575)

### Inferences
- Zero-shot "vibe" scoring recipe: embed the clip, embed contrasting prompt pairs ("a warm, soft sound" vs "a harsh, thin sound"), use the softmax/difference of cosine similarities as a relative score; use pairs rather than single adjectives because absolute CLAP similarities are poorly calibrated (prior knowledge, unverified).
- Clips of 0.1-3 s get zero-padded/repeated to the model's 10 s window; very short transients may embed poorly (unverified; no source found on short-clip behaviour).
- CLAP-size models (~150-200M params, prior knowledge) are CPU-feasible for a few clips per call on a laptop; not benchmarked here.
- Given the EQ finding, "muffled / low-passed / bright" should be measured directly (spectral centroid, rolloff, band balance) rather than trusted to CLAP.

### Gaps
- No numeric scores extracted from arXiv 2510.14249 (abstract only).
- No source on CLAP behaviour for sub-second clips, or on adjectives like "punchy", "crunchy", "lo-fi", "cozy".
- MS-CLAP licence text (MS-PL) not read directly; M2D-CLAP licence unknown.

## 3. General audio embeddings for query-by-example similarity to a reference clip

### Takeaway
No source found that benchmarks PANNs vs BEATs vs VGGish vs OpenL3 vs CLAP specifically for SFX query-by-example; the evidence is indirect (PANNs used in SFX retrieval studies, BEATs strong under attentive probing in bioacoustics). For similarity to a reference, the practical choice is the CLAP audio encoder (same model also gives text scores) plus a timbre-focused feature set; licences below for non-CLAP models are from prior knowledge and must be checked.

### Cited Findings
- A visual-query SFX retrieval study used PANNs as an audio encoder and compared with Wav2CLIP and AudioCLIP (P@10 across three test sets; numbers not extracted). — [arXiv 2308.09089](https://arxiv.org/pdf/2308.09089)
- BEATs (self-supervised on AudioSet) beat bird-specific models in a bioacoustics benchmark but needed attentive probing to show its full performance. — [arXiv 2508.10230](https://arxiv.deeppaper.ai/papers/2508.10230v1)
- Fx-Encoder++ (2025) extracts audio-effects representations (an embedding aimed at effect/processing similarity rather than sound class). — [arXiv 2507.02273](https://arxiv.org/pdf/2507.02273)
- SonicBench: frozen-encoder linear probes capture physical cues better than LLM decoders, but timbre recognition is hard even for encoders. — [SonicBench](https://arxiv.org/html/2601.11039v1)

### Inferences
- Prior knowledge, unverified, check before use: PANNs code MIT; VGGish Apache-2.0; OpenL3 MIT (library, CPU-friendly); BEATs MIT (Microsoft unilm); EnCodec code MIT; MERT and AudioMAE weights likely CC-BY-NC (non-commercial), which would make them a poor fit.
- Class-trained embeddings (PANNs, VGGish, BEATs) cluster by "what made the sound" (sword vs door), not by "how it sounds" (warm vs harsh) — good for "is this still a fire whoosh like the reference", weak for timbre tuning. Effect-aware embeddings (Fx-Encoder++) or simple DSP features (MFCC distance, spectral centroid/rolloff, envelope attack time, crest factor) better track processing changes such as low-pass or distortion.
- All of PANNs-CNN14, VGGish, OpenL3, CLAP run on CPU for short clips (unbenchmarked).

### Gaps
- No direct comparison found of embeddings for SFX query-by-example; DCASE language-based retrieval results not retrieved.
- Licences for PANNs, BEATs, VGGish, OpenL3, EnCodec, AudioMAE, MERT not verified this session; CPU speeds not measured.

## 4. Existing tools / MCP servers that give an LLM agent "ears"

### Takeaway
`music-perception-mcp` (AnqiPinku) is the closest ready-made fit: deterministic librosa/pyloudnorm measurements (LUFS, true peak, 6-band spectral balance, centroid, rolloff, clipping) plus an optional Gemini-backed `listen_subjective` tool returning 0-100 scores for muddy/harsh/sibilant/bright and a mood word; it is music-oriented, Python, local, Windows path in its example config. No CLAP-based MCP server was found.

### Cited Findings
- music-perception-mcp tools: `analyze_audio` (integrated LUFS, loudness range, true/sample peak, BPM, key, 6-band relative spectral balance, spectral centroid and rolloff, clipping count with timestamps), `measure_loudness`, `listen_subjective` (0-100 muddy/harsh/sibilant/bright, valence/arousal -10..10, mood word, timestamped issues; non-deterministic). Backed by `gemini-2.5-flash` by default (configurable, e.g. flash-lite), needs `GEMINI_API_KEY`; audio downsampled to 16 kHz mono and capped at 20 s before sending. Deps numpy, soundfile, pyloudnorm, librosa, scipy (permissive, pure pip, no ffmpeg); avoids madmom (NC weights) and Essentia (AGPL). Server's own licence not stated; WAV expected. — [Glama listing](https://glama.ai/mcp/servers/AnqiPinku/music-perception-mcp)
- MCP Music Analysis (hugohow): librosa server with tempo, MFCC, chroma CQT, beat tracking. — [mcpservers.org](https://mcpservers.org/de/servers/hugohow/mcp-audio-analysis)
- Audio MCP Server (GongRzhe) exists (README on jsDelivr; content not examined, appears to be record/playback). — [README](https://cdn.jsdelivr.net/gh/GongRzhe/Audio-MCP-Server@main/README.md)

### Inferences
- Note: music-perception-mcp downsamples to 16 kHz before Gemini, which removes content above 8 kHz; "bright/harsh/sibilant" judgments of SFX would be distorted by that. Sending 44.1/48 kHz WAV directly may be better (unverified whether Gemini itself resamples internally).
- A project-specific tool is simple to assemble from the pieces: (a) DSP metrics (librosa/pyloudnorm) for objective words (muffled = low centroid/rolloff; punchy = fast attack, high crest factor; crunchy/distorted = clipping, high flatness/odd harmonics; lo-fi = band-limited + bit/sample-rate artefacts), (b) LAION-CLAP for adjective-pair scores and reference similarity, (c) optional Gemini Flash-Lite for a free-text description.
- Third-party MCP servers must be read before install (project rule) and their audio may leave the machine (Gemini), so the user should OK that.

### Gaps
- No existing Claude skill specifically for SFX listening found.
- No evaluation of any of these tools on game SFX.
