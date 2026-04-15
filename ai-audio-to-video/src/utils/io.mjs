import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

export async function ensureDir(dirPath) {
  await mkdir(dirPath, { recursive: true });
}

export async function fileExists(filePath) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

export async function assertFileExists(filePath, ErrorType, message) {
  if (!(await fileExists(filePath))) {
    throw new ErrorType(message ?? `File not found: ${filePath}`);
  }
}

export async function readJson(filePath) {
  const raw = await readFile(filePath, "utf8");
  return JSON.parse(raw);
}

function stableSortObject(value) {
  if (Array.isArray(value)) {
    return value.map(stableSortObject);
  }

  if (value && typeof value === "object") {
    return Object.keys(value)
      .sort()
      .reduce((acc, key) => {
        acc[key] = stableSortObject(value[key]);
        return acc;
      }, {});
  }

  return value;
}

export async function writeJson(filePath, data) {
  await ensureDir(path.dirname(filePath));
  const stable = stableSortObject(data);
  await writeFile(filePath, `${JSON.stringify(stable, null, 2)}\n`, "utf8");
}

export async function writeText(filePath, content) {
  await ensureDir(path.dirname(filePath));
  await writeFile(filePath, content, "utf8");
}

