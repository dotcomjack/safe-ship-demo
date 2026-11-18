import test from "node:test";
import assert from "node:assert";
import fs from "node:fs";

test("headline is one line", () => {
  assert.equal(fs.readFileSync("site/headline.txt", "utf8").trim().split("\n").length, 1);
});
