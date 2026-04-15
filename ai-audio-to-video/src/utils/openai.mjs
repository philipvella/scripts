import OpenAI from "openai";
import { ConfigError } from "./errors.mjs";

export function createOpenAIClient() {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new ConfigError("OPENAI_API_KEY is required. Set it in your environment.");
  }

  return new OpenAI({ apiKey });
}

