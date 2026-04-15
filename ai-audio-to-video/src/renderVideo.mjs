import path from "node:path";
import { fileURLToPath } from "node:url";
import { readdir } from "node:fs/promises";
import { InputError, RenderError } from "./utils/errors.mjs";
import { assertFileExists, ensureDir, readJson, writeText } from "./utils/io.mjs";
import { checkBinaryExists, runCommand } from "./utils/exec.mjs";
import { logStage } from "./utils/logger.mjs";
import { formatSrtTime } from "./utils/time.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, "..");

function toAbs(targetPath) {
  return path.isAbsolute(targetPath) ? targetPath : path.resolve(ROOT_DIR, targetPath);
}

function subtitleLine(scene, index) {
  return `${index + 1}\n${formatSrtTime(scene.start)} --> ${formatSrtTime(scene.end)}\n${scene.subtitle}\n`;
}

function escapeSubtitlePath(filePath) {
  return filePath.replace(/\\/g, "\\\\").replace(/:/g, "\\:").replace(/'/g, "\\'");
}

async function buildSceneClip({ scene, sceneIndex, manifest, scenesDir, fps = 30 }) {
  const activeState = "talking";
  const reactionState = "listening";

  const activeImage = manifest.characters?.[scene.onScreenCharacter]?.[activeState];
  const reactionImage = manifest.characters?.[scene.reactionCharacter]?.[reactionState];
  const backgroundImage =
    manifest.backgrounds?.[scene.background] ||
    Object.values(manifest.backgrounds ?? {})[0];

  if (!activeImage || !reactionImage || !backgroundImage) {
    throw new InputError(`Missing assets for scene ${scene.id}`);
  }

  const scenePath = path.join(scenesDir, `scene_${String(sceneIndex + 1).padStart(4, "0")}.mp4`);

  const filter = [
    // Background: scale to canvas, subtle zoom, convert to rgba so overlays work cleanly.
    `[0:v]scale=1280:720,zoompan=z='min(zoom+0.0006,1.05)':d=1:s=1280x720:fps=${fps},format=rgba[bg]`,
    // Active speaker: larger, full opacity, force rgba to honour PNG alpha.
    `[1:v]scale=620:620,format=rgba[active]`,
    // Reaction character: smaller, dimmed to 70% opacity via alpha channel.
    `[2:v]scale=320:320,format=rgba,colorchannelmixer=aa=0.70[react]`,
    // Composite active speaker over background, then reaction character on top right.
    // format=auto tells overlay to respect the alpha channel of the top layer.
    "[bg][active]overlay=format=auto:x=70:y=50[tmp1]",
    "[tmp1][react]overlay=format=auto:x=930:y=350[vout]"
  ].join(";");

  await runCommand("ffmpeg", [
    "-y",
    "-loop",
    "1",
    "-t",
    String(scene.duration),
    "-i",
    backgroundImage,
    "-loop",
    "1",
    "-t",
    String(scene.duration),
    "-i",
    activeImage,
    "-loop",
    "1",
    "-t",
    String(scene.duration),
    "-i",
    reactionImage,
    "-filter_complex",
    filter,
    "-map",
    "[vout]",
    "-r",
    String(fps),
    "-c:v",
    "libx264",
    "-pix_fmt",
    "yuv420p",
    "-an",
    scenePath
  ]);

  return scenePath;
}

async function concatScenes(scenePaths, concatPath, videoNoAudioPath) {
  const list = scenePaths.map((scenePath) => `file '${scenePath.replace(/'/g, "'\\''")}'`).join("\n");
  await writeText(concatPath, `${list}\n`);

  await runCommand("ffmpeg", [
    "-y",
    "-f",
    "concat",
    "-safe",
    "0",
    "-i",
    concatPath,
    "-c:v",
    "libx264",
    "-pix_fmt",
    "yuv420p",
    "-an",
    videoNoAudioPath
  ]);
}

export async function renderVideo({
  storyboardPath = "output/storyboard.json",
  manifestPath = "output/assets-manifest.json",
  inputAudioPath = "input/audio.mp3",
  outputVideoPath = "output/final.mp4",
  subtitlePath = "output/subtitles.srt"
} = {}) {
  const absStoryboardPath = toAbs(storyboardPath);
  const absManifestPath = toAbs(manifestPath);
  const absAudioPath = toAbs(inputAudioPath);
  const absOutputPath = toAbs(outputVideoPath);
  const absSubtitlePath = toAbs(subtitlePath);
  const tempDir = toAbs("output/.temp");
  const scenesDir = path.join(tempDir, "scenes");
  const concatPath = path.join(tempDir, "scene-list.txt");
  const videoNoAudioPath = path.join(tempDir, "video-no-audio.mp4");

  await assertFileExists(absStoryboardPath, InputError, `Storyboard not found: ${absStoryboardPath}`);
  await assertFileExists(absManifestPath, InputError, `Asset manifest not found: ${absManifestPath}`);
  await assertFileExists(absAudioPath, InputError, `Input audio not found: ${absAudioPath}`);

  const ffmpegExists = await checkBinaryExists("ffmpeg");
  if (!ffmpegExists) {
    throw new RenderError("ffmpeg not found in PATH.");
  }

  await ensureDir(tempDir);
  await ensureDir(scenesDir);

  const oldSceneFiles = await readdir(scenesDir);
  for (const fileName of oldSceneFiles) {
    if (fileName.endsWith(".mp4")) {
      // Ignore cleanup errors to keep the render flow simple and resilient.
      try {
        await runCommand("rm", ["-f", path.join(scenesDir, fileName)]);
      } catch {
        // no-op
      }
    }
  }

  const storyboard = await readJson(absStoryboardPath);
  const manifest = await readJson(absManifestPath);
  const scenes = Array.isArray(storyboard?.scenes) ? storyboard.scenes : [];

  if (scenes.length === 0) {
    throw new InputError("Storyboard has no scenes to render.");
  }

  const srt = scenes.map(subtitleLine).join("\n");
  await writeText(absSubtitlePath, srt);

  const scenePaths = [];
  for (let i = 0; i < scenes.length; i += 1) {
    const scene = scenes[i];
    const scenePath = await buildSceneClip({
      scene,
      sceneIndex: i,
      manifest,
      scenesDir
    });
    scenePaths.push(scenePath);
  }

  await concatScenes(scenePaths, concatPath, videoNoAudioPath);

  const subtitleFilter = `subtitles='${escapeSubtitlePath(absSubtitlePath)}':force_style='Fontsize=24,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=1,Outline=2,Alignment=2'`;

  await runCommand("ffmpeg", [
    "-y",
    "-i",
    videoNoAudioPath,
    "-i",
    absAudioPath,
    "-vf",
    subtitleFilter,
    "-map",
    "0:v:0",
    "-map",
    "1:a:0",
    "-c:v",
    "libx264",
    "-c:a",
    "aac",
    "-shortest",
    absOutputPath
  ]);

  logStage("render", `Final video saved to ${absOutputPath}`);
  return {
    outputVideoPath: absOutputPath,
    subtitlePath: absSubtitlePath
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  renderVideo().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

