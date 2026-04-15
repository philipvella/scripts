import { spawn } from "node:child_process";
import { RenderError } from "./errors.mjs";

export function runCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: ["ignore", "pipe", "pipe"],
      ...options
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += String(chunk);
    });

    child.stderr.on("data", (chunk) => {
      stderr += String(chunk);
    });

    child.on("error", (error) => {
      reject(new RenderError(`${command} failed to start: ${error.message}`));
    });

    child.on("close", (code) => {
      if (code !== 0) {
        reject(
          new RenderError(
            `${command} exited with code ${code}.\n${stderr || stdout}`
          )
        );
        return;
      }
      resolve({ stdout, stderr });
    });
  });
}

export async function checkBinaryExists(binaryName) {
  try {
    await runCommand(binaryName, ["-version"]);
    return true;
  } catch {
    return false;
  }
}

