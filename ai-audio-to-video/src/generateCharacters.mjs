import path from "node:path";
import { fileURLToPath } from "node:url";
import { rm, writeFile } from "node:fs/promises";
import { ApiError, InputError } from "./utils/errors.mjs";
import { assertFileExists, ensureDir, fileExists, readJson, writeJson } from "./utils/io.mjs";
import { logStage } from "./utils/logger.mjs";
import { createOpenAIClient } from "./utils/openai.mjs";
import { BACKGROUND_PROMPTS, CHARACTER_DEFINITIONS } from "./utils/prompts.mjs";
import { runCommand } from "./utils/exec.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, "..");

function toAbs(targetPath) {
  return path.isAbsolute(targetPath) ? targetPath : path.resolve(ROOT_DIR, targetPath);
}

async function generateImageBuffer(client, prompt, model) {
  const result = await client.images.generate({
    model,
    prompt,
    size: "1024x1024"
  });

  const image = result?.data?.[0];
  if (!image) {
    throw new ApiError("Image generation returned no data.");
  }

  if (image.b64_json) {
    return Buffer.from(image.b64_json, "base64");
  }

  if (image.url) {
    const response = await fetch(image.url);
    if (!response.ok) {
      throw new ApiError(`Failed to download generated image: ${response.status}`);
    }
    return Buffer.from(await response.arrayBuffer());
  }

  throw new ApiError("Image generation response missing b64_json and url.");
}

async function createPlaceholderImage(targetPath, color) {
  await runCommand("ffmpeg", [
    "-y",
    "-f",
    "lavfi",
    "-i",
    `color=c=${color}:s=1024x1024:d=1`,
    "-frames:v",
    "1",
    targetPath
  ]);
}

async function clearDir(dirPath) {
  await rm(dirPath, { recursive: true, force: true });
  await ensureDir(dirPath);
}

async function wasGeneratedWithMock(manifestPath) {
  try {
    const existing = await readJson(manifestPath);
    return existing?._meta?.mock === true;
  } catch {
    return null; // manifest doesn't exist yet
  }
}

export async function generateCharacters({
  storyboardPath = "output/storyboard.json",
  outputPath = "output/assets-manifest.json",
  imageModel = process.env.OPENAI_IMAGE_MODEL || "gpt-image-1",
  mock = false
} = {}) {
  const sourcePath = toAbs(storyboardPath);
  const manifestPath = toAbs(outputPath);
  const charactersDir = toAbs("output/characters");
  const backgroundsDir = toAbs("output/backgrounds");

  await assertFileExists(sourcePath, InputError, `Storyboard not found: ${sourcePath}`);

  // Detect stale mock assets and wipe them before a real run (and vice-versa).
  const previousMock = await wasGeneratedWithMock(manifestPath);
  const modeChanged = previousMock !== null && previousMock !== mock;
  if (modeChanged) {
    logStage("assets", `Mode changed (mock: ${previousMock} → ${mock}). Clearing cached assets.`);
    await clearDir(charactersDir);
    await clearDir(backgroundsDir);
  } else {
    await ensureDir(charactersDir);
    await ensureDir(backgroundsDir);
  }

  const storyboard = await readJson(sourcePath);
  const scenes = Array.isArray(storyboard?.scenes) ? storyboard.scenes : [];

  const characters = Object.keys(CHARACTER_DEFINITIONS);
  const states = ["neutral", "talking", "listening"];
  const manifest = {
    _meta: { mock },
    characters: {},
    backgrounds: {}
  };

  let client;
  if (!mock) {
    client = createOpenAIClient();
  }

  for (const characterId of characters) {
    manifest.characters[characterId] = {};

    for (const state of states) {
      const outputFile = path.join(charactersDir, `${characterId}_${state}.png`);
      manifest.characters[characterId][state] = outputFile;

      if (await fileExists(outputFile)) {
        logStage("assets", `Reusing cached: ${path.basename(outputFile)}`);
        continue;
      }

      if (mock) {
        const color = characterId === "alex" ? "#3A86FF" : "#FF006E";
        await createPlaceholderImage(outputFile, color);
        logStage("assets", `Mock placeholder created: ${path.basename(outputFile)}`);
        continue;
      }

      logStage("assets", `Generating image: ${characterId} / ${state}`);
      const prompt = `${CHARACTER_DEFINITIONS[characterId].visualPrompt} Pose: ${state}. Clean white background, single person, no text.`;
      try {
        const imageBuffer = await generateImageBuffer(client, prompt, imageModel);
        await writeFile(outputFile, imageBuffer);
      } catch (error) {
        throw new ApiError(`Failed generating ${characterId}/${state}: ${error.message}`);
      }
    }
  }

  const backgroundsInUse = new Set(scenes.map((scene) => scene.background).filter(Boolean));
  if (backgroundsInUse.size === 0) {
    backgroundsInUse.add("simple_gradient");
  }

  for (const backgroundId of backgroundsInUse) {
    const outputFile = path.join(backgroundsDir, `${backgroundId}.png`);
    manifest.backgrounds[backgroundId] = outputFile;

    if (await fileExists(outputFile)) {
      logStage("assets", `Reusing cached: ${path.basename(outputFile)}`);
      continue;
    }

    if (mock) {
      const color = backgroundId === "podcast_studio" ? "#0B132B" : backgroundId === "living_room" ? "#1C2541" : "#5BC0BE";
      await createPlaceholderImage(outputFile, color);
      logStage("assets", `Mock background created: ${backgroundId}`);
      continue;
    }

    logStage("assets", `Generating background: ${backgroundId}`);
    const prompt = BACKGROUND_PROMPTS[backgroundId] || BACKGROUND_PROMPTS.simple_gradient;
    try {
      const imageBuffer = await generateImageBuffer(client, prompt, imageModel);
      await writeFile(outputFile, imageBuffer);
    } catch (error) {
      throw new ApiError(`Failed generating background ${backgroundId}: ${error.message}`);
    }
  }

  await writeJson(manifestPath, manifest);
  logStage("assets", `Asset manifest saved to ${manifestPath}`);
  return manifest;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const mock = process.argv.includes("--mock");

  generateCharacters({ mock }).catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

