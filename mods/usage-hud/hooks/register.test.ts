import { expect, mock, test } from 'claude-code/testing'

import { blocks, contextUsed, filled, halves, paint, percentLeft, title, until } from './register'

const BAND = {
  component: 'AbovePrompt' as const,
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 20,
    bodyColumns: 190,
    scroll: { offset: 0, bodyRows: 19 },
    view: {},
  },
}

test('a window counts down in half points, like health', async () => {
  expect(halves(0)).toBe(20)
  expect(halves(50)).toBe(10)
  expect(halves(97)).toBe(1)
  expect(halves(100)).toBe(0)
})

test('half a heart and a bitten shank, from the game sprites', async () => {
  const grid = paint({ weekly: 95, hourly: 95 }, 182)
  // heart 0: the left half is red with its highlight, the right half the container
  expect(grid[2]![2]).toBe(0xffc8c8)
  expect(grid[3]![6]).toBe(0x282828)
  // the rightmost shank (x 173..181) is food_half over food_empty
  expect(grid[1]![173 + 3]).toBe(0xb21818)
  expect(grid[1]![173 + 2]).toBe(0x282828)
})

test('the terminal gets braille cells, a half where each bar ends', async () => {
  const [hearts, hunger] = blocks({ weekly: 35, hourly: 55 })
  const R = '#ff1313', r = '#7a1010', B = '#d08a3c', b = '#6e4416', _ = '#3a3a3a'
  expect(hearts!.colors).toEqual([R, R, R, R, R, R, r, _, _, _])
  expect(hunger!.colors).toEqual([_, _, _, _, _, b, B, B, B, B])
  expect(hearts!.percent).toBe('65%')
  expect(hunger!.percent).toBe('45%')
  expect(percentLeft(null)).toBe('--%')
})

test('each bar is topped by when its window resets', async () => {
  const now = Date.parse('2026-10-06T12:00:00Z')
  expect(until('2026-10-09T16:00:00Z', now)).toBe('3d 4h')
  expect(until('2026-10-06T14:15:00Z', now)).toBe('2h 15m')
  expect(until('2026-10-06T12:40:00Z', now)).toBe('40m')
  expect(title('2026-10-06T14:15:00Z', now)).toBe('resets in 2h 15m')
  expect(title(null, now)).toBeNull()
})

test('a narrow band stacks the bars, hunger drawn like the hearts', async ($, on) => {
  on('session.measure', ($, e) => ({ changed: e.changed }))
  mock.clock(on)
  mock.store(on)
  mock.env(on, { TERM_PROGRAM: 'zed' })
  await $.session.measure({
    context: { window: 200000 },
    rateLimits: [
      { kind: 'seven_day', percentUsed: 30 },
      { kind: 'five_hour', percentUsed: 60 },
    ],
    changed: ['rateLimits'],
  })
  const terminal = await $.ui.mount({ plugin: 'usage-hud', surface: 'terminal', ...BAND })
  expect((await terminal.find({ key: 'hud' }))?.props.flexDirection).toBe('row')
  expect((await terminal.find({ key: 'hunger' }))?.props.alignItems).toBe('flex-end')
  expect(await terminal.find({ type: 'Text', text: '40% ' })).toBeDefined()
  await terminal.redraw({ ...BAND.props, bodyColumns: 20 })
  expect((await terminal.find({ key: 'hud' }))?.props.flexDirection).toBe('column')
  expect((await terminal.find({ key: 'hunger' }))?.props.alignItems).toBe('flex-start')
  expect(await terminal.find({ type: 'Text', text: ' 40%' })).toBeDefined()
  await terminal.unmount()
})

test('the band draws braille and percents in Zed and a picture on desktop', async ($, on) => {
  on('session.measure', ($, e) => ({ changed: e.changed }))
  mock.clock(on)
  mock.store(on)
  mock.env(on, { TERM_PROGRAM: 'zed' })
  await $.session.measure({
    context: { window: 200000 },
    rateLimits: [
      { kind: 'seven_day', percentUsed: 30 },
      { kind: 'five_hour', percentUsed: 60 },
    ],
    changed: ['rateLimits'],
  })
  const terminal = await $.ui.mount({ plugin: 'usage-hud', surface: 'terminal', ...BAND })
  expect(await terminal.find({ type: 'Text', text: ' 70%' })).toBeDefined()
  expect(await terminal.find({ type: 'Text', text: '⣿⣿⣿⣿⣿⣿⣿' })).toBeDefined()
  expect(await terminal.find({ type: 'Text', text: '40% ' })).toBeDefined()
  await terminal.unmount()
  const desktop = await $.ui.mount({ plugin: 'usage-hud', surface: 'desktop', ...BAND })
  expect(await desktop.find({ type: 'Svg' })).toBeDefined()
  await desktop.unmount()
})

test('Ghostty draws braille too, no images', async ($, on) => {
  on('session.measure', ($, e) => ({ changed: e.changed }))
  mock.clock(on)
  mock.store(on)
  mock.env(on, { TERM_PROGRAM: 'ghostty' })
  await $.session.measure({
    context: { window: 200000 },
    rateLimits: [{ kind: 'seven_day', percentUsed: 10 }],
    changed: ['rateLimits'],
  })
  const terminal = await $.ui.mount({ plugin: 'usage-hud', surface: 'terminal', ...BAND })
  expect(await terminal.find({ type: 'Image' })).toBeUndefined()
  expect(await terminal.find({ type: 'Text', text: '⣿'.repeat(9) })).toBeDefined()
  expect(await terminal.find({ type: 'Text', text: ' 90%' })).toBeDefined()
  await terminal.unmount()
})

test('the experience bar fills with the context in use', async ($, on) => {
  expect(filled(25, 40)).toBe(10)
  expect(filled(100, 40)).toBe(40)
  on('session.measure', ($, e) => ({ changed: e.changed }))
  mock.clock(on)
  mock.store(on)
  mock.env(on, { TERM_PROGRAM: 'zed' })
  await $.session.measure({
    context: { window: 200000, tokens: 50000, percent: 25 },
    rateLimits: [{ kind: 'seven_day', percentUsed: 30 }],
    changed: ['context', 'rateLimits'],
  })
  const terminal = await $.ui.mount({ plugin: 'usage-hud', surface: 'terminal', ...BAND, props: { ...BAND.props, bodyColumns: 40 } })
  // 40 columns: 17 of line, ' 25% ', 18 of line; the first 10 green
  expect(await terminal.find({ type: 'Text', text: ' 25% ' })).toBeDefined()
  expect(await terminal.find({ type: 'Text', text: '⠶'.repeat(10) })).toBeDefined()
  expect(await terminal.find({ type: 'Text', text: '⠶'.repeat(7) })).toBeDefined()
  expect(await terminal.find({ type: 'Text', text: '⠶'.repeat(18) })).toBeDefined()
  await terminal.unmount()
})

test('a new session shows the experience bar empty until the first fill', async ($, on) => {
  expect(contextUsed({ window: 200000 })).toBeNull()
  expect(contextUsed({ window: 200000, tokens: 50000 })).toBe(25)
  expect(contextUsed({ window: 200000, tokens: 50000, percent: 26 })).toBe(26)
  on('session.measure', ($, e) => ({ changed: e.changed }))
  mock.clock(on)
  mock.store(on)
  mock.env(on, { TERM_PROGRAM: 'ghostty' })
  await $.session.measure({
    context: { window: 200000 },
    rateLimits: [{ kind: 'seven_day', percentUsed: 10 }],
    changed: ['rateLimits'],
  })
  const terminal = await $.ui.mount({ plugin: 'usage-hud', surface: 'terminal', ...BAND })
  expect(await terminal.find({ type: 'Text', text: ' 0% ' })).toBeDefined()
  await terminal.unmount()
})

test('a new session draws the last reading kept, before its first response', async ($, on) => {
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.usage', () => ({ value: { startedAt: 0, context: { window: 200000 }, rateLimits: [] } }))
  mock.clock(on)
  mock.store(on, { lastLimits: { weekly: 30, hourly: 60, weeklyResets: null, hourlyResets: null } })
  mock.env(on, { TERM_PROGRAM: 'zed' })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const terminal = await $.ui.mount({ plugin: 'usage-hud', surface: 'terminal', ...BAND })
  expect(await terminal.find({ key: 'hud' })).toBeDefined()
  expect(await terminal.find({ type: 'Text', text: '40% ' })).toBeDefined()
  await terminal.unmount()
})

test('each reading is kept for the next session', async ($, on) => {
  on('session.measure', ($, e) => ({ changed: e.changed }))
  const kept: Record<string, unknown> = {}
  on('store.set', ($, e) => ({ value: void (kept[e.key] = e.value) }))
  await $.session.measure({
    context: { window: 200000 },
    rateLimits: [{ kind: 'seven_day', percentUsed: 30 }],
    changed: ['rateLimits'],
  })
  expect(kept.lastLimits).toEqual({ weekly: 30, hourly: null, weeklyResets: null, hourlyResets: null })
})

test('a /clear keeps the HUD, with the last reading, until the first response', async ($, on) => {
  on('session.measure', ($, e) => ({ changed: e.changed }))
  mock.clock(on)
  mock.store(on)
  mock.env(on, { TERM_PROGRAM: 'zed' })
  await $.session.measure({
    context: { window: 200000 },
    rateLimits: [{ kind: 'seven_day', percentUsed: 30 }, { kind: 'five_hour', percentUsed: 60 }],
    changed: ['rateLimits'],
  })
  await $.session.measure({ context: { window: 200000 }, rateLimits: [], changed: ['rateLimits', 'context'] })
  const terminal = await $.ui.mount({ plugin: 'usage-hud', surface: 'terminal', ...BAND })
  expect(await terminal.find({ key: 'hud' })).toBeDefined()
  expect(await terminal.find({ type: 'Text', text: '40% ' })).toBeDefined()
  await terminal.unmount()
})
