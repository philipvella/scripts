import { createReadStream } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ApiError, InputError } from "./utils/errors.mjs";
import { runCommand } from "./utils/exec.mjs";
import { assertFileExists, writeJson } from "./utils/io.mjs";
import { logStage } from "./utils/logger.mjs";
import { createOpenAIClient } from "./utils/openai.mjs";
import { roundToMs } from "./utils/time.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, "..");

function toAbs(inputPath) {
  return path.isAbsolute(inputPath) ? inputPath : path.resolve(ROOT_DIR, inputPath);
}

function normalizeSpeaker(rawSpeaker, index) {
  if (typeof rawSpeaker !== "string" || rawSpeaker.trim().length === 0) {
    return index % 2 === 0 ? "speaker_1" : "speaker_2";
  }

  const value = rawSpeaker.trim().toLowerCase();
  if (value.includes("1") || value.includes("a") || value.includes("left")) {
    return "speaker_1";
  }
  if (value.includes("2") || value.includes("b") || value.includes("right")) {
    return "speaker_2";
  }

  return `speaker_${(index % 2) + 1}`;
}

function splitTextIntoChunks(text, targetChars = 180) {
  const sentences = String(text)
    .split(/(?<=[.!?])\s+/)
    .map((item) => item.trim())
    .filter(Boolean);

  if (sentences.length === 0) {
    return [];
  }

  const chunks = [];
  let current = "";

  for (const sentence of sentences) {
    const candidate = current ? `${current} ${sentence}` : sentence;
    if (candidate.length <= targetChars || current.length < Math.floor(targetChars * 0.55)) {
      current = candidate;
      continue;
    }

    chunks.push(current);
    current = sentence;
  }

  if (current) {
    chunks.push(current);
  }

  return chunks;
}

function estimateDurationFromText(text) {
  const wordCount = String(text)
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
  if (wordCount === 0) {
    return 5;
  }
  // Rough speaking-rate fallback when ffprobe is unavailable.
  return Math.max(8, wordCount / 2.5);
}

function buildTimedSegmentsFromText(text, audioDurationSeconds) {
  const chunks = splitTextIntoChunks(text);
  if (chunks.length === 0) {
    return [];
  }

  const duration = Math.max(5, Number(audioDurationSeconds) || estimateDurationFromText(text));
  const weights = chunks.map((chunk) => Math.max(1, chunk.split(/\s+/).filter(Boolean).length));
  const totalWeight = weights.reduce((sum, weight) => sum + weight, 0);

  const segments = [];
  let currentStart = 0;

  for (let index = 0; index < chunks.length; index += 1) {
    const isLast = index === chunks.length - 1;
    let currentEnd;

    if (isLast) {
      currentEnd = duration;
    } else {
      const proportional = duration * (weights[index] / totalWeight);
      const minDuration = 1.2;
      const remainingSlots = chunks.length - index - 1;
      const remainingMin = remainingSlots * minDuration;
      const maxAllowedEnd = Math.max(currentStart + minDuration, duration - remainingMin);
      currentEnd = Math.min(maxAllowedEnd, currentStart + Math.max(minDuration, proportional));
    }

    segments.push({
      start: roundToMs(currentStart),
      end: roundToMs(Math.max(currentStart + 0.5, currentEnd)),
      speaker: index % 2 === 0 ? "speaker_1" : "speaker_2",
      text: chunks[index]
    });

    currentStart = currentEnd;
  }

  if (segments.length > 0) {
    segments[segments.length - 1].end = roundToMs(duration);
  }

  return segments;
}

function normalizeTranscriptResponse(response, audioDurationSeconds) {
  const segments = Array.isArray(response?.segments) ? response.segments : [];

  const normalized = segments
    .map((segment, index) => {
      const text = String(segment?.text ?? "").trim();
      if (!text) {
        return null;
      }

      const start = roundToMs(segment?.start ?? 0);
      const end = roundToMs(segment?.end ?? start + 2);

      return {
        start,
        end: end > start ? end : roundToMs(start + 2),
        speaker: normalizeSpeaker(segment?.speaker ?? segment?.speaker_label, index),
        text
      };
    })
    .filter(Boolean);

  if (normalized.length > 0) {
    return { segments: normalized };
  }

  const fallbackText = String(response?.text ?? response ?? "").trim();
  if (!fallbackText) {
    return { segments: [] };
  }

  const fallbackSegments = buildTimedSegmentsFromText(fallbackText, audioDurationSeconds);
  if (fallbackSegments.length > 0) {
    return { segments: fallbackSegments };
  }

  return {
    segments: [
      {
        start: 0,
        end: 5,
        speaker: "speaker_1",
        text: fallbackText
      }
    ]
  };
}

function mockTranscript() {
  return {
    segments: [
      { start: 0, end: 4.2, speaker: "speaker_1", text: "Welcome back to the show." },
      { start: 4.2, end: 8.6, speaker: "speaker_2", text: "Thanks, today we have a quick update." },
      { start: 8.6, end: 13.4, speaker: "speaker_1", text: "Let us walk through the key points." }
    ]
  };
}

function isRetryableTranscriptionOptionError(error) {
  const message = String(error?.message ?? "").toLowerCase();
  return (
    message.includes("response_format") ||
    message.includes("timestamp_granularities") ||
    message.includes("diarization") ||
    message.includes("not compatible") ||
    message.includes("unknown parameter")
  );
}

async function callTranscriptionWithFallback(client, inputAudioPath, model) {
  const attempts = [
    {
      label: "verbose_json+diarization",
      options: {
        response_format: "verbose_json",
        timestamp_granularities: ["segment"],
        diarization: true
      }
    },
    {
      label: "json",
      options: {
        response_format: "json"
      }
    },
    {
      label: "text",
      options: {
        response_format: "text"
      }
    }
  ];

  let lastError;
  for (const attempt of attempts) {
    try {
      logStage("transcribe", `Trying transcription mode: ${attempt.label}`);
      const file = createReadStream(inputAudioPath);
      return await client.audio.transcriptions.create({
        model,
        file,
        ...attempt.options
      });
    } catch (error) {
      lastError = error;
      if (!isRetryableTranscriptionOptionError(error)) {
        throw error;
      }
    }
  }

  throw lastError;
}

async function getAudioDurationSeconds(inputAudioPath) {
  try {
    const { stdout } = await runCommand("ffprobe", [
      "-v",
      "error",
      "-show_entries",
      "format=duration",
      "-of",
      "default=nw=1:nk=1",
      inputAudioPath
    ]);
    const parsed = Number.parseFloat(String(stdout).trim());
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return null;
    }
    return roundToMs(parsed);
  } catch {
    return null;
  }
}

export async function transcribeAudio({
  inputAudioPath = "input/audio.mp3",
  outputPath = "output/transcript.json",
  model = process.env.OPENAI_TRANSCRIBE_MODEL || "gpt-4o-transcribe",
  mock = false
} = {}) {
  const audioPath = toAbs(inputAudioPath);
  const transcriptPath = toAbs(outputPath);

  await assertFileExists(audioPath, InputError, `Input audio not found: ${audioPath}`);

  logStage("transcribe", `Starting transcription for ${audioPath}`);

  if (mock) {
    const mocked = mockTranscript();
    await writeJson(transcriptPath, mocked);
    logStage("transcribe", `Mock transcript saved to ${transcriptPath}`);
    return mocked;
  }

  let response;
  try {
    const client = createOpenAIClient();
    response = await callTranscriptionWithFallback(client, audioPath, model);
  } catch (error) {
    throw new ApiError(`Transcription failed: ${error.message}`);
  }

  const audioDurationSeconds = await getAudioDurationSeconds(audioPath);
  if (audioDurationSeconds) {
    logStage("transcribe", `Detected audio duration: ${audioDurationSeconds}s`);
  } else {
    logStage("transcribe", "Audio duration probe unavailable, using text-based estimate if needed.");
  }

  const normalized = normalizeTranscriptResponse(response, audioDurationSeconds);
  await writeJson(transcriptPath, normalized);
  logStage("transcribe", `Transcript saved to ${transcriptPath}`);

  return normalized;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const inputArg = process.argv[2] || "input/audio.mp3";
  const mock = process.argv.includes("--mock");

  transcribeAudio({ inputAudioPath: inputArg, mock }).catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
