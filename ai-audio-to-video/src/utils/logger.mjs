export function logStage(stage, message, extra = undefined) {
  const timestamp = new Date().toISOString();
  if (extra === undefined) {
    console.log(`[${timestamp}] [${stage}] ${message}`);
    return;
  }
  console.log(`[${timestamp}] [${stage}] ${message}`, extra);
}

