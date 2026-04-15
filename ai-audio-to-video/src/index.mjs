import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildStoryboard } from "./buildStoryboard.mjs";
import { generateCharacters } from "./generateCharacters.mjs";
import { renderVideo } from "./renderVideo.mjs";
import { transcribeAudio } from "./transcribe.mjs";
import { logStage } from "./utils/logger.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, "..");

function toProjectPath(targetPath) {
  return path.isAbsolute(targetPath)
    ? targetPath
    : path.resolve(ROOT_DIR, targetPath);
}

function printUsage() {
  console.log("Usage: node src/index.mjs <audio-path> [--mock]");
  console.log("Example: node src/index.mjs input/audio.mp3");
}

async function run() {
  const args = process.argv.slice(2);

  if (args.includes("--help") || args.includes("-h")) {
    printUsage();
    return;
  }

  const mock = args.includes("--mock");
  const audioArg = args.find((arg) => !arg.startsWith("--")) || "input/audio.mp3";
  const audioPath = toProjectPath(audioArg);

  const transcriptPath = "output/transcript.json";
  const storyboardPath = "output/storyboard.json";
  const manifestPath = "output/assets-manifest.json";

  logStage("pipeline", "Starting audio-to-video pipeline", { audioPath, mock });

  await transcribeAudio({
    inputAudioPath: audioPath,
    outputPath: transcriptPath,
    mock
  });

  await buildStoryboard({
    transcriptPath,
    outputPath: storyboardPath
  });

  await generateCharacters({
    storyboardPath,
    outputPath: manifestPath,
    mock
  });

  await renderVideo({
    storyboardPath,
    manifestPath,
    inputAudioPath: audioPath,
    outputVideoPath: "output/final.mp4",
    subtitlePath: "output/subtitles.srt"
  });

  logStage("pipeline", "Done. Output: output/final.mp4");
}

run().catch((error) => {
  console.error(`[pipeline] Failed: ${error.name || "Error"}: ${error.message}`);
  process.exit(1);
});

