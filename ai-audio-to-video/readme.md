# AI Audio to Video Pipeline

Turn one conversational audio file into a simple visual MP4 using OpenAI APIs + FFmpeg.

## What this does

- Keeps your original audio unchanged.
- Transcribes audio into timed segments with diarization-friendly normalization.
- Builds a short-scene storyboard (roughly 3 to 8 second visual beats).
- Maps two speakers to recurring characters (`speaker_a`, `speaker_b`).
- Generates reusable character/background images.
- Renders a 1280x720 H.264/AAC MP4 with subtitles and speaker switching.

## Project structure

```text
ai-audio-to-video/
  input/
    audio.mp3
  output/
  scripts/
    smoke-test.mjs
  src/
    index.mjs
    transcribe.mjs
    buildStoryboard.mjs
    generateCharacters.mjs
    renderVideo.mjs
    utils/
      errors.mjs
      exec.mjs
      io.mjs
      logger.mjs
      openai.mjs
      prompts.mjs
      time.mjs
  .env.example
  package.json
  readme.md
```

## Requirements

- Node.js 20+
- FFmpeg available in your `PATH`
- OpenAI API key (for non-mock runs)

## Setup

```bash
cd /Users/philipvella/work/scripts/ai-audio-to-video
npm install
cp .env.example .env
```

Set env variables (in your shell or `.env` loader):

```bash
export OPENAI_API_KEY="your_api_key"
export OPENAI_TRANSCRIBE_MODEL="gpt-4o-transcribe"
export OPENAI_IMAGE_MODEL="gpt-image-1"
```

## FFmpeg install examples

macOS (Homebrew):

```bash
brew install ffmpeg
```

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install ffmpeg
```

## Run

Put your source audio at `input/audio.mp3` (or pass any path explicitly):

```bash
npm start -- input/audio.mp3
```

Or call directly:

```bash
node src/index.mjs input/audio.mp3
```

## Mock mode (no OpenAI calls)

Useful for local render validation:

```bash
node src/index.mjs input/audio.mp3 --mock
npm run smoke
```

`npm run smoke` generates a short synthetic fixture at `output/.smoke/audio-smoke.mp3` and does not overwrite `input/audio.mp3`.

## Pipeline stages

1. `src/transcribe.mjs`
   - Reads audio and calls OpenAI Transcriptions API.
   - Uses compatibility fallback modes: `verbose_json` -> `json` -> `text`.
   - Writes `output/transcript.json` in normalized form:

```json
{
  "segments": [
    {
      "start": 0,
      "end": 4.2,
      "speaker": "speaker_1",
      "text": "Welcome back to the show."
    }
  ]
}
```

2. `src/buildStoryboard.mjs`
   - Merges transcript fragments into 3-8s scenes.
   - Maps speakers to `speaker_a` and `speaker_b`.
   - Writes `output/storyboard.json`:

```json
{
  "characters": {
    "speaker_a": {
      "displayName": "Speaker A",
      "visualPrompt": "Friendly podcast host..."
    },
    "speaker_b": {
      "displayName": "Speaker B",
      "visualPrompt": "Friendly podcast co-host..."
    }
  },
  "scenes": [
    {
      "id": "scene_001",
      "start": 0,
      "end": 4.2,
      "duration": 4.2,
      "speaker": "speaker_1",
      "subtitle": "Welcome back to the show.",
      "onScreenCharacter": "speaker_a",
      "reactionCharacter": "speaker_b",
      "emotion": "neutral",
      "background": "podcast_studio",
      "imagePrompt": "Simple, clean 2D conversation scene..."
    }
  ]
}
```

3. `src/generateCharacters.mjs`
   - Generates reusable images for character states + backgrounds.
   - Writes `output/assets-manifest.json`.

4. `src/renderVideo.mjs`
   - Creates scene clips, subtitles (`output/subtitles.srt`), final MP4 (`output/final.mp4`).

5. `src/index.mjs`
   - Orchestrates all stages.

## Output files

- `output/transcript.json`
- `output/storyboard.json`
- `output/assets-manifest.json`
- `output/subtitles.srt`
- `output/final.mp4`

## Limitations

- No lip sync.
- Visual storytelling only (image-based scenes, not continuous generated video).
- Best suited for podcast / conversational audio.
- If diarization labels are noisy, normalization collapses to two main speakers.
