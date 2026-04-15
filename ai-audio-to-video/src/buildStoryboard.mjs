import path from "node:path";
import { fileURLToPath } from "node:url";
import { InputError } from "./utils/errors.mjs";
import { assertFileExists, readJson, writeJson } from "./utils/io.mjs";
import { logStage } from "./utils/logger.mjs";
import { CHARACTER_DEFINITIONS, EMOTIONS } from "./utils/prompts.mjs";
import { roundToMs } from "./utils/time.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, "..");

function toAbs(targetPath) {
  return path.isAbsolute(targetPath) ? targetPath : path.resolve(ROOT_DIR, targetPath);
}

function normalizeLabel(rawLabel) {
  if (typeof rawLabel !== "string" || rawLabel.trim().length === 0) {
    return "unknown";
  }
  return rawLabel.trim().toLowerCase();
}

function normalizeSpeakers(segments) {
  const counts = new Map();
  for (const segment of segments) {
    const label = normalizeLabel(segment.speaker);
    counts.set(label, (counts.get(label) ?? 0) + 1);
  }

  const topTwo = [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 2)
    .map(([label]) => label);

  const fallback = ["speaker_1", "speaker_2"];
  const chosen = [topTwo[0] || fallback[0], topTwo[1] || fallback[1]];

  return segments.map((segment, index) => {
    const label = normalizeLabel(segment.speaker);
    const speaker = label === chosen[0] ? "speaker_1" : label === chosen[1] ? "speaker_2" : `speaker_${(index % 2) + 1}`;
    return {
      ...segment,
      speaker
    };
  });
}

function summarizeSubtitle(text, maxChars = 90) {
  const clean = String(text || "").replace(/\s+/g, " ").trim();
  if (clean.length <= maxChars) {
    return clean;
  }
  return `${clean.slice(0, maxChars - 1).trimEnd()}...`;
}

function pickEmotion(text) {
  const lower = text.toLowerCase();
  if (lower.includes("?") || lower.includes("wonder")) {
    return "thinking";
  }
  if (lower.includes("!") || lower.includes("great") || lower.includes("awesome")) {
    return "happy";
  }
  if (lower.includes("wow") || lower.includes("surprise")) {
    return "surprised";
  }
  return "neutral";
}

function pickBackground(sceneIndex) {
  const options = ["podcast_studio", "simple_gradient", "living_room"];
  return options[sceneIndex % options.length];
}

function buildScenePrompt({ onScreenCharacter, emotion, background, subtitle }) {
  const characterPrompt = CHARACTER_DEFINITIONS[onScreenCharacter].visualPrompt;
  return [
    "Simple, clean 2D conversation scene.",
    characterPrompt,
    `Active character emotion: ${emotion}.`,
    `Background style: ${background}.`,
    `Context: ${subtitle}`,
    "No text, no logos, safe generic style."
  ].join(" ");
}

function mergeToBeats(segments, minDuration = 3, maxDuration = 8) {
  const beats = [];
  let current = null;

  for (const segment of segments) {
    if (!current) {
      current = { ...segment, textParts: [segment.text] };
      continue;
    }

    const candidateDuration = segment.end - current.start;
    const sameSpeaker = segment.speaker === current.speaker;

    if ((candidateDuration <= maxDuration && sameSpeaker) || current.end - current.start < minDuration) {
      current.end = Math.max(current.end, segment.end);
      current.textParts.push(segment.text);
      continue;
    }

    beats.push({
      start: current.start,
      end: current.end,
      speaker: current.speaker,
      text: current.textParts.join(" ")
    });

    current = { ...segment, textParts: [segment.text] };
  }

  if (current) {
    beats.push({
      start: current.start,
      end: current.end,
      speaker: current.speaker,
      text: current.textParts.join(" ")
    });
  }

  return beats;
}

export async function buildStoryboard({
  transcriptPath = "output/transcript.json",
  outputPath = "output/storyboard.json"
} = {}) {
  const sourcePath = toAbs(transcriptPath);
  const targetPath = toAbs(outputPath);

  await assertFileExists(sourcePath, InputError, `Transcript not found: ${sourcePath}`);
  const transcript = await readJson(sourcePath);

  const rawSegments = Array.isArray(transcript?.segments) ? transcript.segments : [];
  if (rawSegments.length === 0) {
    throw new InputError("Transcript has no segments.");
  }

  const normalized = normalizeSpeakers(rawSegments).map((segment) => ({
    start: roundToMs(segment.start),
    end: roundToMs(segment.end),
    speaker: segment.speaker,
    text: String(segment.text || "").trim()
  }));

  const beats = mergeToBeats(normalized);

  const scenes = beats.map((beat, index) => {
    const onScreenCharacter = beat.speaker === "speaker_1" ? "speaker_a" : "speaker_b";
    const reactionCharacter = onScreenCharacter === "speaker_a" ? "speaker_b" : "speaker_a";
    const subtitle = summarizeSubtitle(beat.text);
    const emotion = EMOTIONS.includes(pickEmotion(beat.text)) ? pickEmotion(beat.text) : "neutral";
    const background = pickBackground(index);

    return {
      id: `scene_${String(index + 1).padStart(3, "0")}`,
      start: beat.start,
      end: beat.end,
      duration: roundToMs(Math.max(0.5, beat.end - beat.start)),
      speaker: beat.speaker,
      subtitle,
      onScreenCharacter,
      reactionCharacter,
      emotion,
      background,
      imagePrompt: buildScenePrompt({ onScreenCharacter, emotion, background, subtitle })
    };
  });

  const storyboard = {
    characters: CHARACTER_DEFINITIONS,
    scenes
  };

  await writeJson(targetPath, storyboard);
  logStage("storyboard", `Storyboard saved to ${targetPath}`);
  return storyboard;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  buildStoryboard().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

