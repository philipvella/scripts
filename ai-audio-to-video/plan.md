I want to build a Node.js pipeline that turns one input audio file into a simple engaging video using OpenAI APIs and FFmpeg.

Goal:
Take a 2 speaker audio file around 4 minutes 25 seconds long and produce an MP4 video.
The final video should:
1. keep the original audio unchanged
2. transcribe the audio with speaker diarization using the OpenAI Transcriptions API
3. group transcript segments into short visual beats of around 3 to 8 seconds
4. create two generic recurring characters, one for each speaker
5. generate simple visual assets using the OpenAI image API
6. assemble a video with basic motion, subtitles, speaker switching, and the original audio
7. avoid lip sync and avoid trying to generate one long AI video clip

Technical requirements:
- Use Node.js ESM
- Use the official OpenAI npm package
- Use environment variable OPENAI_API_KEY
- Use FFmpeg via child_process
- Output clean JSON files for each pipeline stage
- Make the code modular and production minded
- Add error handling and clear logging
- Keep functions small and well named

Project structure:
- src/transcribe.mjs
- src/buildStoryboard.mjs
- src/generateCharacters.mjs
- src/renderVideo.mjs
- src/index.mjs
- output/
- input/
- .env.example
- README.md

Detailed behaviour:

1. transcribe.mjs
- Read one input audio file from input/audio.mp3
- Call OpenAI transcription API with the diarization capable model
- Save a transcript JSON file to output/transcript.json
- Normalise the returned structure into:
  {
  segments: [
  {
  start: number,
  end: number,
  speaker: string,
  text: string
  }
  ]
  }

2. buildStoryboard.mjs
- Read output/transcript.json
- Merge tiny transcript fragments into visual beats of roughly 3 to 8 seconds
- Map speakers to two stable character ids:
  speaker_1 => speaker_a
  speaker_2 => speaker_b
- Produce output/storyboard.json with:
  {
  characters: {
  speaker_a: { displayName: "Speaker A", visualPrompt: "..." },
  speaker_b: { displayName: "Speaker B", visualPrompt: "..." }
  },
  scenes: [
  {
  id: string,
  start: number,
  end: number,
  duration: number,
  speaker: string,
  subtitle: string,
  onScreenCharacter: string,
  reactionCharacter: string,
  emotion: "neutral" | "happy" | "thinking" | "surprised",
  background: "podcast_studio" | "simple_gradient" | "living_room",
  imagePrompt: string
  }
  ]
  }
- Subtitle text should be concise and readable
- Keep scene prompts generic and safe
- If diarization labels are inconsistent, normalise to two main speakers

3. generateCharacters.mjs
- Read output/storyboard.json
- Use the OpenAI image API to generate:
    - speaker_a neutral portrait
    - speaker_a talking
    - speaker_a listening
    - speaker_b neutral portrait
    - speaker_b talking
    - speaker_b listening
    - 2 or 3 simple backgrounds
- Save assets into output/characters and output/backgrounds
- Reuse assets instead of generating one image per scene where possible
- Create a small manifest JSON describing saved asset paths

4. renderVideo.mjs
- Read storyboard and asset manifest
- Create subtitles.srt from scenes
- Build simple scene visuals using FFmpeg
- For each scene:
    - show active speaker larger
    - show other character smaller or dimmed
    - switch between talking and listening images depending on speaker
    - use a subtle zoom or pan effect if feasible
    - overlay subtitle text
- Concatenate all scenes
- Add the original audio as the final audio track
- Export output/final.mp4
- Use 1280x720 landscape
- Use H.264 and AAC for compatibility

5. index.mjs
- Orchestrate the whole pipeline:
    - transcribe
    - build storyboard
    - generate characters
    - render video
- Support a simple command:
  node src/index.mjs input/audio.mp3

6. README.md
- Explain setup
- Explain how to install FFmpeg
- Explain environment variables
- Explain expected input and output files
- Explain limitations:
    - no lip sync
    - visual storytelling only
    - better suited for podcast style or conversational audio than cinematic animation

Implementation notes:
- Prefer deterministic JSON outputs
- Add helper utilities for file IO and shell execution
- Keep prompts centralised in one file if useful
- Use async/await
- Validate required files and directories before processing
- Include example transcript and storyboard snippets in README

Please generate:
1. package.json
2. .env.example
3. all source files
4. README.md

Keep the first version simple, reliable, and easy to run locally.