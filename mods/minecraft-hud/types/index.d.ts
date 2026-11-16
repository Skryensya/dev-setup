/**
 * Percent used of each window, 0 to 100, and when each resets (ISO 8601);
 * null until the engine has a reading.
 */
export type Limits = {
  weekly: number | null
  hourly: number | null
  weeklyResets?: string | null
  hourlyResets?: string | null
}

declare module 'claude-code' {
  interface PluginState {
    /** `context`: percent of the session's context window in use, 0 to 100. */
    'minecraft-hud': { limits: Limits | null; context: number | null }
  }
}
