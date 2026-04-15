export function roundToMs(seconds) {
  return Math.round(Number(seconds || 0) * 1000) / 1000;
}

export function formatSrtTime(seconds) {
  const totalMs = Math.max(0, Math.floor(seconds * 1000));
  const ms = totalMs % 1000;
  const totalSec = Math.floor(totalMs / 1000);
  const sec = totalSec % 60;
  const totalMin = Math.floor(totalSec / 60);
  const min = totalMin % 60;
  const hr = Math.floor(totalMin / 60);

  const p2 = (value) => String(value).padStart(2, "0");
  const p3 = (value) => String(value).padStart(3, "0");

  return `${p2(hr)}:${p2(min)}:${p2(sec)},${p3(ms)}`;
}

