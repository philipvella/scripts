import path from "node:path";
import { fileURLToPath } from "node:url";
import { runCommand } from "../src/utils/exec.mjs";
import { ensureDir, fileExists } from "../src/utils/io.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, "..");

async function runSmokeTest() {
  const smokeDir = path.join(ROOT_DIR, "output", ".smoke");
  await ensureDir(smokeDir);
  const inputPath = path.join(smokeDir, "audio-smoke.mp3");

  await runCommand("ffmpeg", [
    "-y",
    "-f",
    "lavfi",
    "-i",
    "sine=frequency=550:duration=14",
    "-q:a",
    "9",
    inputPath
  ]);

  await runCommand("node", [path.join(ROOT_DIR, "src", "index.mjs"), inputPath, "--mock"], {
    cwd: ROOT_DIR
  });

  const mustExist = [
    path.join(ROOT_DIR, "output", "transcript.json"),
    path.join(ROOT_DIR, "output", "storyboard.json"),
    path.join(ROOT_DIR, "output", "assets-manifest.json"),
    path.join(ROOT_DIR, "output", "subtitles.srt"),
    path.join(ROOT_DIR, "output", "final.mp4")
  ];

  for (const filePath of mustExist) {
    if (!(await fileExists(filePath))) {
      throw new Error(`Smoke test failed, missing file: ${filePath}`);
    }
  }

  console.log("Smoke test passed.");
}

runSmokeTest().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
