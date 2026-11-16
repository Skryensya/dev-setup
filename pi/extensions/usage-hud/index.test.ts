import { expect, test } from "bun:test";
import { halves, hud } from "./index";

test("a window counts down in half points", () => {
  expect(halves(0)).toBe(20);
  expect(halves(50)).toBe(10);
  expect(halves(97)).toBe(1);
  expect(halves(100)).toBe(0);
  expect(halves(250)).toBe(0);
});

test("the hud shows the percent left, and --% when unknown", () => {
  expect(hud(25)).toContain("75%");
  expect(hud(null)).toContain("--%");
});
