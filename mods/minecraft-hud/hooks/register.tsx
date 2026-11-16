import { atom, read, update } from 'claude-code'
import type { Register, SessionContextUsage, SessionRateLimit } from 'claude-code'

import type { Limits } from '../types'

import {
  FOOD_EMPTY,
  FOOD_FULL,
  FOOD_HALF,
  HEART_CONTAINER,
  HEART_FULL,
  HEART_HALF,
} from './sprites'
import type { Sprite } from './sprites'

const limits = atom({ plugin: 'minecraft-hud', key: 'limits' } as const, null)
const context = atom({ plugin: 'minecraft-hud', key: 'context' } as const, null)

// The store key holding the last rate-limit reading, kept across sessions.
const LAST = 'lastLimits'

// The vanilla HUD's geometry, in texture pixels: 9px icons, 8px apart (they
// overlap by one), ten of each, hearts flush left and hunger flush right.
const ICON = 9
const STEP = 8
const BAR = ICON + STEP * 9
const HOTBAR = 182

type Pixel = number | null
type Grid = Pixel[][]

const clamp = (percent: number) => Math.min(100, Math.max(0, percent))

/** Half-points left of a window, 0 to 20, as the game counts health and food. */
export function halves(percentUsed: number | null): number {
  return Math.ceil((100 - clamp(percentUsed ?? 0)) / 5)
}

function blank(width: number, height: number): Grid {
  return Array.from({ length: height }, () => Array<Pixel>(width).fill(null))
}

function stamp(grid: Grid, x: number, y: number, sprite: Sprite) {
  sprite.forEach((row, dy) =>
    row.forEach((color, dx) => {
      if (color !== null) grid[y + dy]![x + dx] = color
    }),
  )
}

// As the game draws them: the container, then the full or half heart over it,
// the last heart first so each one sits over the one to its right.
function hearts(grid: Grid, x: number, y: number, health: number) {
  for (let i = 9; i >= 0; i--) {
    const at = x + i * STEP
    stamp(grid, at, y, HEART_CONTAINER)
    const n = health - i * 2
    if (n >= 2) stamp(grid, at, y, HEART_FULL)
    else if (n === 1) stamp(grid, at, y, HEART_HALF)
  }
}

// Hunger runs from the right edge leftwards, the bitten shank where it ends.
function food(grid: Grid, right: number, y: number, level: number) {
  for (let i = 0; i < 10; i++) {
    const at = right - ICON - i * STEP
    stamp(grid, at, y, FOOD_EMPTY)
    const n = level - i * 2
    if (n >= 2) stamp(grid, at, y, FOOD_FULL)
    else if (n === 1) stamp(grid, at, y, FOOD_HALF)
  }
}

/** Both bars on one line, `width` pixels apart edge to edge, 9 tall. */
export function paint(state: Limits, width: number): Grid {
  const grid = blank(width, ICON)
  hearts(grid, 0, 0, halves(state.weekly))
  food(grid, width, 0, halves(state.hourly))
  return grid
}

// Between the bars, in columns: two braille cells.
const SPLIT = 2

// One braille cell per icon, no gaps; only the color says full, half or empty.
const CELL = '⣿'
const EMPTY = '#3a3a3a'
const HEART = ['#ff1313', '#7a1010', EMPTY]
const SHANK = ['#d08a3c', '#6e4416', EMPTY]

/** Percent left of a window, as the bar shows it. */
export function percentLeft(percentUsed: number | null): string {
  if (percentUsed === null) return '--%'
  return `${Math.round(100 - clamp(percentUsed))}%`
}

/**
 * Both bars as colored braille blocks, in every terminal:
 * hearts left to right with their percent after them, hunger right to left
 * as the game empties it with its percent before it.
 */
export function blocks(state: Limits) {
  const colors = (level: number, [full, half, empty]: string[]) =>
    Array.from({ length: 10 }, (_, i) => {
      const n = level - i * 2
      return n >= 2 ? full! : n === 1 ? half! : empty!
    })
  return [
    { key: 'hearts', colors: colors(halves(state.weekly), HEART), percent: percentLeft(state.weekly) },
    { key: 'hunger', colors: colors(halves(state.hourly), SHANK).reverse(), percent: percentLeft(state.hourly) },
  ]
}

/** Time until `resetsAt`, coarse: `3d 4h`, `2h 15m`, `40m`; null when unknown. */
export function until(resetsAt: string | null | undefined, now: number): string | null {
  if (!resetsAt) return null
  const ms = Date.parse(resetsAt) - now
  if (Number.isNaN(ms)) return null
  const minutes = Math.max(0, Math.round(ms / 60000))
  const d = Math.floor(minutes / 1440)
  const h = Math.floor((minutes % 1440) / 60)
  const m = minutes % 60
  if (d > 0) return `${d}d ${h}h`
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

/** The small line over a bar: when its window resets; null when unknown. */
export function title(resetsAt: string | null | undefined, now: number): string | null {
  const left = until(resetsAt, now)
  return left === null ? null : `resets in ${left}`
}

/** Neighbouring cells of one color, drawn as one Text each. */
function runs(colors: string[]) {
  const out: { color: string; count: number }[] = []
  for (const color of colors) {
    const last = out[out.length - 1]
    if (last?.color === color) last.count++
    else out.push({ color, count: 1 })
  }
  return out
}

function svg(grid: Pixel[][]): string {
  const width = grid[0]!.length
  let rects = ''
  grid.forEach((row, y) => {
    let x = 0
    while (x < width) {
      const color = row[x]
      if (color === null || color === undefined) {
        x++
        continue
      }
      let end = x + 1
      while (end < width && row[end] === color) end++
      rects += `<rect x="${x}" y="${y}" width="${end - x}" height="1" fill="#${color.toString(16).padStart(6, '0')}"/>`
      x = end
    }
  })
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${grid.length}" shape-rendering="crispEdges">${rects}</svg>`
}

const XP_GREEN = '#80ff20'
// A thin line in text, the middle two rows of dots, half a cell tall.
const XP_CELL = '⠶'

/** Columns of `width` the bar fills at `percent`. */
export function filled(percent: number, width: number): number {
  return Math.round((clamp(percent) / 100) * width)
}

function describe(state: Limits): string {
  const health = halves(state.weekly) / 2
  const food = halves(state.hourly) / 2
  return `Health ${health} of 10 hearts (weekly limit), hunger ${food} of 10 (5-hour limit)`
}

/** Percent of the context window in use, from the fill or the tokens; null before either. */
export function contextUsed(usage: SessionContextUsage): number | null {
  if (usage.percent !== undefined) return usage.percent
  if (usage.tokens !== undefined && usage.window > 0) return Math.round((usage.tokens / usage.window) * 100)
  return null
}

function toLimits(windows: SessionRateLimit[]): Limits | null {
  if (windows.length === 0) return null
  const weekly = windows.find(w => w.kind === 'seven_day')
  const hourly = windows.find(w => w.kind === 'five_hour')
  return {
    weekly: weekly?.percentUsed ?? null,
    hourly: hourly?.percentUsed ?? null,
    weeklyResets: weekly?.resetsAt ?? null,
    hourlyResets: hourly?.resetsAt ?? null,
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    const usage = await $.session.usage()
    // A new session has no reading until its first response: draw the last one
    // seen, kept across sessions, so the HUD shows from the start.
    const reading = toLimits(usage.rateLimits) ?? ((await $.store.get(LAST)) as Limits | undefined) ?? null
    if (reading) await update($, limits, () => reading)
    await update($, context, () => contextUsed(usage.context))
    return result
  })

  on('session.measure', async ($, e, next) => {
    if (e.changed.includes('rateLimits')) {
      // A /clear starts a session with no reading and fires no session.start:
      // keep drawing the last one rather than hide the HUD until a response.
      const reading = toLimits(e.rateLimits)
      if (reading) {
        await update($, limits, () => reading)
        await $.store.set(LAST, reading)
      } else {
        const last = ((await $.store.get(LAST)) as Limits | undefined) ?? null
        await update($, limits, current => current ?? last)
      }
    }
    if (e.changed.includes('context')) await update($, context, () => contextUsed(e.context))
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const state = await read($, limits)
    // Empty until the first response reports a fill, as a new world starts at 0.
    const used = (await read($, context)) ?? 0
    if (e.props.hasSurvey || state === null) return next(e)

    const ui = $.ui.resolve(e)
    const alt = describe(state)

    if (e.surface === 'terminal') {
      const { Box, Text } = ui
      const now = await $.clock.now()
      const items = blocks(state).map(({ key, colors, percent }) => {
        const name = title(key === 'hearts' ? state.weeklyResets : state.hourlyResets, now)
        const width = Math.max(name?.length ?? 0, colors.length + 1 + percent.length)
        return { key, colors, percent, name, width }
      })
      // Side by side when both fit the band, hunger flush right and mirrored;
      // stacked otherwise, hunger drawn like the hearts, flush left.
      const stacked = items[0]!.width + SPLIT + items[1]!.width > e.props.bodyColumns
      const bars = items.map(({ key, colors, percent, name }) => {
        const left = key === 'hearts' || stacked
        const bar = runs(colors).map(({ color, count }, i) => (
          <Text key={i} color={color}>
            {CELL.repeat(count)}
          </Text>
        ))
        const label = (
          <Text key="percent" bold>
            {left ? ` ${percent}` : `${percent} `}
          </Text>
        )
        return (
          <Box key={key} flexDirection="column" alignItems={left ? 'flex-start' : 'flex-end'}>
            {name === null ? null : (
              <Text key="title" dimColor>
                {name}
              </Text>
            )}
            <Box key="row" flexDirection="row">
              {left ? [...bar, label] : [label, ...bar]}
            </Box>
          </Box>
        )
      })
      const hud = (
        <Box
          key="hud"
          width="100%"
          flexDirection={stacked ? 'column' : 'row'}
          justifyContent="space-between"
          alignItems={stacked ? 'flex-start' : 'flex-end'}
          columnGap={SPLIT}
        >
          {bars}
        </Box>
      )
      // The experience bar under both, the band's whole width, its level (the
      // context in use) in green inside the thin braille line.
      const level = `${used}%`
      const columns = Math.min(255, e.props.bodyColumns)
      const fill = filled(used, columns)
      const tag = ` ${level} `
      const start = Math.max(0, Math.floor((columns - tag.length) / 2))
      const color = (i: number) => (i < fill ? XP_GREEN : EMPTY)
      const line = (from: number, to: number, side: string) =>
        runs(Array.from({ length: Math.max(0, to - from) }, (_, i) => color(from + i))).map(({ color, count }, i) => (
          <Text key={`${side}${i}`} color={color}>
            {XP_CELL.repeat(count)}
          </Text>
        ))
      return (
        <Box key="minecraft" width="100%" flexDirection="column">
          {hud}
          <Box key="xp" width="100%" flexDirection="row">
            {line(0, start, 'l')}
            <Text key="level" color={XP_GREEN} bold>
              {tag}
            </Text>
            {line(start + tag.length, columns, 'r')}
          </Box>
        </Box>
      )
    }

    if ('Svg' in ui) {
      const { Svg } = ui
      return <Svg source={svg(paint(state, HOTBAR))} alt={alt} width={HOTBAR * 4} height={ICON * 4} />
    }
    return next(e)
  })
}
