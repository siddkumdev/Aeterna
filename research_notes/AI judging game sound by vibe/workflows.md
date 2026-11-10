# Workflows for choosing and tuning game sound effects from a reference or a "vibe", calibrated with few human judgements (as of Nov 2026)

Scope note: research by one sub-researcher, 15 web tool calls. Where a source was a search-result summary rather than a page I opened, that is flagged. Training-data knowledge not confirmed by a source this session is kept out of Cited Findings.

## 1. Query-by-example and text-based SFX retrieval in practice (which can an agent call for free?)

### Takeaway
Freesound's API v2 is the one free, programmatic option: it has a `similar` endpoint over two similarity spaces (a 512-d LAION-CLAP space and a 100-d Essentia "classic" space), descriptor filters (pitch, loudness, bpm...), a full `analysis` endpoint, and a licence filter; downloading originals needs OAuth2, previews do not. Commercial tools (Soundly, Splice, Sononym) do similar-sound search but expose no public API found.

### Cited Findings
- Freesound API: `GET /apiv2/sounds/<sound_id>/similar/` returns a paginated list and takes `similarity_space`, `fields`, `page`, `page_size`; the search endpoint's `similar_to` parameter accepts a sound id OR a raw similarity vector — [Freesound API resources](https://freesound.org/docs/api/resources_apiv2.html)
- Similarity spaces: `laion_clap` (512 dims, LAION-CLAP embeddings capturing acoustic and semantic properties) and `freesound_classic` (100 dims, Essentia low-level features). A vector you supply must come from the same extractor; vectors are L2-normalised automatically — [Freesound API resources](https://freesound.org/docs/api/resources_apiv2.html)
- Inference: because `similar_to` takes a vector in the CLAP space, an agent can embed its own local reference clip (or possibly a text prompt, since CLAP is a joint text-audio space) with LAION-CLAP and query Freesound for neighbours. The docs do not say text embeddings are accepted; this is untested.
- Content descriptors such as `pitch`, `note_name`, `loudness`, `bpm` are filterable (range syntax e.g. `pitch:[435 TO 445]`); array descriptors (`mfcc`, `hpcp`, `onset_times`, `tristimulus`, `beat_times`) are not filterable but can be returned via `fields`; `GET /apiv2/sounds/<id>/analysis/` returns all descriptors — [Freesound API resources](https://freesound.org/docs/api/resources_apiv2.html)
- Licence field values are "Attribution", "Attribution NonCommercial", "Creative Commons 0" and it is filterable (so an agent can enforce the project's no-NC rule in the query). A separate `gen_ai_preference` field records the uploader's preference about generative-AI training use — [Freesound API resources](https://freesound.org/docs/api/resources_apiv2.html)
- Original-file download (`/sounds/<id>/download/`, `/packs/<id>/download/`) requires OAuth2 Bearer; MP3/OGG `previews` URLs do not — [Freesound API resources](https://freesound.org/docs/api/resources_apiv2.html)
- Token auth (API key as `token` param or Authorization header) works for most read-only resources; OAuth2 is needed for user-acting resources; OAuth2 access tokens expire after 24 h with refresh tokens — [Freesound authentication](https://freesound.org/docs/api/authentication.html)
- Rate limits are per user (shared across clients) and inspectable at `GET /apiv2/usage/` (burst = last minute, sustained = last 24 h); numeric limits not stated on that page — [Freesound API resources](https://freesound.org/docs/api/resources_apiv2.html)
- Soundly "Find Similar" analyses a source sound and searches local library plus Soundly cloud; can be launched from Explorer/Finder, Wwise, FMOD Studio; its Natural Language Search is in-house semantic search; local files are analysed on-device — [Soundly news](https://getsoundly.com/news/new-soundly-with-find-similar/) (via search summary)
- Splice "Similar Sounds" (ML sample discovery, launched 2019) and "Search with Sound" (analyses audio/MIDI in the DAW session, in the Splice Sounds plugin and Ableton Live 12.3) — [Splice blog](https://splice.com/blog/introducing-similar-sounds/), [Splice support](https://support.splice.com/en/articles/12066972-how-to-use-search-with-sound-in-ableton-live-12-3) (via search summary). No public API found.
- Sononym (desktop, ~$99 one-time, free trial per a listing): similarity search by dragging a file or recording audio, ranked on Overall / Spectrum / Timbre / Pitch / Amplitude with user-adjustable weights; auto-categorisation and duplicate detection — [MusicRadar review](https://www.musicradar.com/reviews/sononym-sononym), [KVR](https://www.kvraudio.com/product/sononym-by-sononym) (via search summary; not verified against official site)
- Research state: DCASE 2025 Task 6, language-based audio retrieval on Clotho v2, metric mAP@16; winner (AISTAT Lab, Chung-Ang Univ.) used a dual encoder + distillation + LLM-based caption augmentation + auxiliary classification; best single model mAP@16 46.62, 4-model ensemble 48.83 — [AISTAT arXiv 2509.16649](https://arxiv.org/html/2509.16649v1); AUDIAS (UAM) cross-modal attention ensemble mAP@16 46.864 — [AUDIAS tech report](https://dcase.community/documents/challenge2025/technical_reports/Calvet_AUDIAS_task6.technical_report.pdf); [DCASE2025](https://dcase.community/challenge2025/)
- LAION-CLAP is pip-installable (`laion_clap`), code repo listed CC0-1.0; checkpoints hosted on Hugging Face `lukewys/laion_clap` with no explicit licence found; the transformers port `laion/clap-htsat-fused` is listed Apache-2.0 — [GitHub LAION-AI/CLAP](https://github.com/LAION-AI/CLAP), [HF clap-htsat-fused](https://huggingface.co/laion/clap-htsat-fused)

### Inferences
- A free agent pipeline: (a) user gives a reference clip or adjectives; (b) agent embeds with local CLAP (Apache-2.0 HF port) and/or uses Freesound `similar`/`similar_to`; (c) filters `license:"Creative Commons 0" OR license:"Attribution"`; (d) pulls `analysis` descriptors to pre-screen on pitch/loudness/duration; (e) auditions previews before an OAuth download. CLAP is analysis-only (an encoder, not a generator), consistent with "no AI audio ships".
- Even DCASE winners reach under ~50% mAP@16, so text-to-audio retrieval is a shortlist generator, not a final judge: a human should still pick from a shortlist.

### Gaps
- Freesound numeric rate limits and Terms of Use details (e.g. any restriction on API use) were not retrieved.
- Whether Freesound `similar_to` accepts CLAP text embeddings was not confirmed.
- Licence of the `lukewys/laion_clap` checkpoints not found.

## 2. Reference-based mixing/mastering and audio style transfer, and what transfers to SFX with numpy/scipy

### Takeaway
Two families: (1) classic "match" processing (Matchering, match-EQ) that measures a reference's RMS, spectrum, peak and stereo width and applies the difference; (2) learned style transfer (DeepAFx-ST) where a network predicts parameters of a chain of real DSP effects from a reference. Both end in ordinary DSP, so the output is processed recorded audio, not generated audio; the "match" family is directly re-implementable in numpy/scipy.

### Cited Findings
- Matchering 2.0 (open-source Python, `pip install -U matchering`, Python 3.8+): matches the target's RMS level, frequency response, peak amplitude and stereo width to a reference; ships its own brickwall limiter ("Hyrax"); Docker, desktop app, CLI and ComfyUI node exist — [PyPI matchering](https://pypi.org/project/matchering/2.0.1/), [GitHub](https://github.com/wokashi-rg/Matchering), [mirror](https://gh.mise.run.place/sergree/matchering). Sources conflicted slightly on licence: check the repo.
- DeepAFx-ST (Steinmetz, Bryan, Reiss, 2022): an encoder analyses input and reference, a controller predicts control parameters for differentiable audio effects; trained self-supervised end-to-end with an audio-domain loss; evaluated on speech and music, generalises to unseen recordings and sample rates; code at adobe-research/DeepAFx-ST under a custom "other" licence — [arXiv 2207.08759](https://arxiv.org/pdf/2207.08759), [project page](https://csteinmetz1.github.io/DeepAFx-ST), [GitHub](https://www.GitHub.com/adobe-research/DeepAFx-ST)
- FxSearcher (Ki, Kim, Kwon, Kim; arXiv Nov 2025): gradient-free search for an audio-effects configuration matching a text prompt, using Bayesian Optimisation with a CLAP-based score and a "guiding prompt" to reduce artifacts; AI-based evaluation reported to align with human preferences; demos at hojoonki.github.io/FxSearcher — [arXiv 2511.14138](https://arxiv.org/abs/2511.14138). A search summary said its pairwise judge was Gemini; the abstract page I opened did not mention that (unconfirmed).

### Inferences
- numpy/scipy recipe for SFX (adapted from Matchering's measured quantities): compute the reference's long-term average spectrum (Welch PSD, smoothed in 1/3-octave bands), divide by the candidate's, clamp to e.g. +/-6 dB, fit a min-phase FIR or a few biquad shelves/peaks (`scipy.signal`), then match loudness (RMS or a K-weighted LUFS approximation) and peak. For short SFX add envelope features (attack time, decay/RT, transient-to-body ratio, spectral centroid, pitch) since spectrum alone misses "softness".
- FxSearcher's pattern (BO over a fixed, ordinary effect chain scored by CLAP-text similarity) is a no-generative-model way to tune "warmer / softer / more wooden" from words; the generated part is only parameters for EQ, pitch shift, filter, reverb, applied to recorded sounds.
- DeepAFx-ST is trained on speech/music; applicability to short one-shot SFX is not shown.

### Gaps
- No source found on match-EQ for one-shot SFX specifically; iZotope Ozone/Neutron match-EQ docs were not retrieved this session.
- Wider automatic-mixing / differentiable-mixing reviews were not retrieved.

## 3. How game audio teams define a sonic "vibe"; cozy/toy-like game examples

### Takeaway
Industry practice: a handful of "audio pillars" (high-level descriptors that act as filters / north star) plus an "audio target" or reference, set in pre-production. Published detail on specific cozy games' SFX is thin; the clearest documented principle is Dorfromantik's "the most frequent action must feel most satisfying, but nothing may break the calm".

### Cited Findings
- Audio pillars = high-level "filters" distilling the whole audio aesthetic into a handful of descriptors, used as a "north star" through pre-production and production; followed by an "Audio Target" step — [A Sound Effect, game audio design document](https://asoundeffect.com/game-audio-design-document/)
- Style pillars as "commandments of your style bible" (e.g. "Cyberpunk", "Gothic") — [Designing Sound, Wrangling Aesthetic](https://designingsound.org/2012/02/07/wrangling-aesthetic/)
- GDC: "Need for Speed: Hyperreal Sound Design" (2023) covers the audio pillars defining the game's core experience — [GDC Vault](https://gdcvault.com/play/1029249/-Need-for-Speed-Hyperreal); "Getting Buy-In: How to Give Your Game Audio Style" (2015) argues a defined audio style makes audio cohesive and unique — [GDC Vault](https://gdcvault.com/play/1022015/Getting-Buy-In-How-to). Slides paywalled; only descriptions seen.
- Counterpoint: a general game-design pillars write-up says pillars are "not adjectives" — [cumus/Game-Pillars](https://github.com/cumus/Game-Pillars) (different kind of pillar; tension not settled).
- Dorfromantik (Timo Falcke, Toukana): "the interaction the player does the most has to feel as satisfying as possible"; tiny animations and sound effects add weight; every sound/animation was checked so it did not disrupt the calm atmosphere — [Game Developer](https://www.gamedeveloper.com/disciplines/sparking-joy-through-tile-placement-in-idyllic-village-builder-i-dorfromantik-i-)
- Dorfromantik cites Townscaper among inspirations (not for audio) — [GOG interview](https://gog.com/news/binterview_toukana_interactive_tells_us_more_about_dorfromantikb)
- Animal Crossing: New Leaf sound director Kazumi Totaka described engine work to expand river and insect sounds and argued SFX and their code matter as much as music — [Animal Crossing World summary of Famitsu interview](https://animalcrossingworld.com/2012/11/highlights-from-an-interview-with-the-developers-of-animal-crossing-new-leaf/) (secondary source)
- Tiny Glade: a fan wiki claims the sound designer focused on tactile "click" and "thud" building sounds as haptic-style feedback with music in the background — [shapes.inc fandom page](https://shapes.inc/fandom/tiny-glade/author) — UNVERIFIED, fan-run.

### Inferences
- An agent can operationalise pillars as a short adjective list (e.g. "soft, wooden, toy-like, warm, never harsh") where each adjective is mapped to a measurable proxy (softness = slow attack / low centroid / low crest factor; toy-like = short decay, higher pitch, small-body resonance) and to CLAP text prompts; the "audio target" = 2-5 reference clips the user picks.
- Dorfromantik's rule suggests weighting the most frequent action sound (here: tower placement / pinch) highest in any judging budget and penalising loud transients against a calm bed.

### Gaps
- No primary source found on Townscaper, Pikmin or Captain Toad SFX choices; no Tiny Glade audio interview confirmed (an 80 Level interview exists but audio content unverified).
- No published adjective list from a GDC talk retrieved (paywalled).

## 4. Preference elicitation with few judgements

### Takeaway
Pairwise A/B with adaptive pair selection (sorting-based or Bayesian/GP preferential optimisation) is the standard; documented audio-adjacent cases (hearing-aid fitting) converge in roughly 25-28 comparisons over a small parameter space, about half of non-adaptive baselines. Level-match candidates before any comparison.

### Cited Findings
- Hearing-aid personalisation via multi-band Bayesian preference learning from pairwise comparisons: simulations recovered preferences with 28 paired comparisons (7 episodes of 4) — [arXiv 2406.09634](https://arxiv.org/pdf/2406.09634) (via search summary)
- OTC hearing-aid personalisation with pairwise comparisons: median 25 comparisons to find the best configuration, half the best baseline — [Univ. Iowa record](https://iro.uiowa.edu/esploro/outputs/journalArticle/Personalizing-over-the-counter-hearing-aids-using-pairwise/9984258850902771) (via search summary)
- Nielsen et al.: GP regression model of listener objective updated sequentially (sequential experimental design), demonstrated on a 5-band EQ — [Glasgow eprints / related record](https://eprints.gla.ac.uk/119560) (via search summary; attribution of URL to that paper not verified)
- qEUBO: decision-theoretic acquisition function for preferential BO with pairwise feedback (example application: animation design) — [arXiv 2303.15746](https://pdf.arxiv.org/pdf/2303.15746)
- Imperial College study of pairwise procedures for audio quality: MST-based pairing gave the strongest ranking with accuracy comparable to optimal Bayesian sampling — [Forum Acusticum 2025 paper](https://dael.euracoustics.org/confs/fa2025/data/articles/000660.pdf) (via search summary)
- Random pair choice needs almost all pairwise comparisons; active selection has a "tremendous impact" — [Jamieson & Nowak 2011](https://ar5iv.labs.arxiv.org/html/1109.3701); repeated Quicksort is a simple effective active strategy under Bradley-Terry — [Maystre & Grossglauser](https://infoscience.epfl.ch/record/229163/files/robustsort.pdf?version=1); count-based active ranking is near-optimal without BTL assumptions — [Heckel et al. 2019](https://projecteuclid.org/euclid.aos/1572487385)
- Comparative judgement with entropy-driven pair selection; authors note the ideal number of comparisons for a reliable rank is not known — [Gray et al. 2024](https://research-information.bris.ac.uk/en/publications/a-bayesian-active-learning-approach-to-comparative-judgement-with/)
- Loudness bias: louder is often judged better (equal-loudness reasoning), so level-match before objective comparison — [Microsoft blog "Louder Sounds Better"](https://learn.microsoft.com/en-us/archive/blogs/audiofool/louder-sounds-better) (argument, not experiment); forum practitioners report ~1 dB differences sway listeners, ~0.25 dB removes it — [WhatsBestForum](https://whatsbestforum.com/threads/in-double-blind-testing-is-louder-perceived-as-better.2640) (anecdotal). A 2025 peer-reviewed study (31 participants) found a level bias of about -8.9 dB when reproducing street sounds — [Acta Acustica 2025](https://acta-acustica.edpsciences.org/articles/aacus/abs/2025/01/aacus250028/aacus250028.html). No controlled study isolating "louder = preferred" was found.

### Inferences
- Practical protocol for the agent: shortlist 6-8 candidates per sound slot by retrieval + measured proxies; loudness-match (to within ~0.5 dB) and randomise A/B order and labels; run an adaptive sort (binary-insertion / Quicksort) or Bradley-Terry with entropy-driven pairs; expect on the order of 10-25 judgements per slot (inferred from the hearing-aid numbers; not measured for SFX). Fit a simple Bradley-Terry or linear preference model on the measured features across slots so later slots start from the learned taste (transfer).
- For tuning continuous parameters (pitch, low-pass, attack, reverb mix), a GP/preferential BO with 2-4 parameters is in the same size class as the hearing-aid problems.

### Gaps
- No paper applying preferential BO specifically to game SFX or synth presets was found.
- No study giving a judgement count for SFX selection.

## 5. Legal/ethical: analysing clips from gameplay videos

### Takeaway
Analysis-only use of copyrighted game audio sits within text-and-data-mining concepts in the EU (TDM explicitly covers sound per commentary), but the general Article 4 exception allows rightholder opt-outs and requires lawful access; keep such clips private, never ship or redistribute them, and prefer extracting only derived features (spectra, envelopes, embeddings).

### Cited Findings
- EU DSM Directive (2019/790) Art. 2(2) defines TDM as "any automated analytical technique aimed at analysing text and data in digital form in order to generate information"; commentary says this encompasses images and sound — [Kluwer Copyright Blog](https://legalblogs.wolterskluwer.com/copyright-blog/the-new-copyright-directive-text-and-data-mining-articles-3-and-4/), [Bird & Bird](https://mediawrites.twobirds.com/post/102j3s6/the-eu-copyright-directive-new-exception-for-text-and-data-mining)
- Art. 3: mandatory for research organisations and cultural heritage institutions with lawful access, no authorisation or compensation needed — [Arthur Cox](https://www.arthurcox.com/wp-content/uploads/2020/05/DSM-Series-Article-1-26-May-2020.pdf), [Communia](https://communia.notion.site/Articles-3-4-Text-and-data-mining-9be17090ebc545b88ed9ac7d39e4e25a)
- Art. 4: general exception for anyone with lawful access, but rightholders can opt out (e.g. machine-readable robots.txt-type metadata) — [Bird & Bird](https://mediawrites.twobirds.com/post/102j3s6/the-eu-copyright-directive-new-exception-for-text-and-data-mining)

### Inferences
- A hackathon team is not a research organisation, so Art. 3 likely does not apply; Art. 4 depends on lawful access and no opt-out. YouTube downloading is a separate ToS question (not researched). Safest: user records short references themselves for private analysis, store them git-ignored (e.g. `_work/`), keep only derived feature files, and never ship or publish them.
- Cleaner reference alternatives: CC0/CC-BY Freesound clips chosen to resemble the target vibe, or the team's own recordings.

### Gaps
- US fair use for analysis-only audio, UK TDM law, and YouTube ToS on downloading were not researched this session. Not legal advice.
