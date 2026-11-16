import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Pi exposes no 5-hour or weekly limit, so the hearts show the context window left.
const CELL = "⣿";
const COLORS = ["#ff1313", "#7a1010", "#3a3a3a"]; // full, half, empty

const paint = (hex: string, text: string) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
  return `\x1b[38;2;${r};${g};${b}m${text}\x1b[0m`;
};

/** Half-points left of the window, 0 to 20, as the game counts health. */
export function halves(percentUsed: number): number {
  return Math.ceil((100 - Math.min(100, Math.max(0, percentUsed))) / 5);
}

/** Ten hearts and the percent left; full hearts and `--%` while the usage is unknown. */
export function hud(percentUsed: number | null): string {
  const health = halves(percentUsed ?? 0);
  const hearts = Array.from({ length: 10 }, (_, i) => {
    const n = health - i * 2;
    return paint(COLORS[n >= 2 ? 0 : n === 1 ? 1 : 2]!, CELL);
  }).join("");
  const left = percentUsed === null ? "--" : Math.round(100 - Math.min(100, Math.max(0, percentUsed)));
  return `${hearts} \x1b[1m${left}%\x1b[0m`;
}

const refresh = (ctx: ExtensionContext) =>
  ctx.ui.setWidget("usage-hud", [hud(ctx.getContextUsage()?.percent ?? null)]);

export default function (pi: ExtensionAPI) {
  for (const event of ["session_start", "turn_end", "session_compact", "model_select"] as const) {
    pi.on(event, async (_event, ctx) => refresh(ctx));
  }
}
