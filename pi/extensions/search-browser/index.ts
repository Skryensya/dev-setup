import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const endpoint = process.env.PI_SEARXNG_URL || "http://127.0.0.1:8888";
const dir = new URL(".", import.meta.url).pathname;

async function compose(args: string[]) {
  return execFileAsync("docker", ["compose", ...args], { cwd: dir, timeout: 120_000 });
}

async function ensureSearxng() {
  try {
    const response = await fetch(`${endpoint}/search?q=ping&format=json`, { signal: AbortSignal.timeout(5_000) });
    if (response.ok) return;
  } catch {}
  await compose(["up", "-d"]);
}

const searchBrowserTool = defineTool({
  name: "web_search",
  label: "Web search",
  description: "Search the web through the local SearXNG Docker service and return concise results with URLs.",
  parameters: Type.Object({
    query: Type.String({ description: "Search query" }),
    limit: Type.Optional(Type.Number({ description: "Maximum results to return", minimum: 1, maximum: 20 })),
  }),
  async execute(_toolCallId, params, signal) {
    await ensureSearxng();
    const url = new URL(`${endpoint}/search`);
    url.searchParams.set("q", params.query);
    url.searchParams.set("format", "json");
    const response = await fetch(url, { signal });
    if (!response.ok) throw new Error(`SearXNG search failed: HTTP ${response.status}`);
    const data: any = await response.json();
    const limit = Math.max(1, Math.min(20, params.limit ?? 8));
    const results = (data.results || []).slice(0, limit).map((r: any, i: number) => ({
      index: i + 1,
      title: r.title,
      url: r.url,
      content: r.content,
      engine: r.engine,
    }));
    const text = results.map((r: any) => `${r.index}. ${r.title}\n${r.url}\n${r.content || ""}`).join("\n\n");
    return { content: [{ type: "text", text: text || "No results." }], details: { endpoint, query: params.query, results } };
  },
});

export default function (pi: ExtensionAPI) {
  pi.registerTool(searchBrowserTool);
  pi.registerCommand("search-browser-up", {
    description: "Start the local SearXNG search browser Docker service",
    handler: async (_args, ctx) => {
      await compose(["up", "-d"]);
      ctx.ui.notify(`SearXNG running at ${endpoint}`, "info");
    },
  });
  pi.registerCommand("search-browser-down", {
    description: "Stop the local SearXNG search browser Docker service",
    handler: async (_args, ctx) => {
      await compose(["down"]);
      ctx.ui.notify("SearXNG stopped", "info");
    },
  });
}
