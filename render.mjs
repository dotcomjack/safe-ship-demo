#!/usr/bin/env node
// Renders Claude Code's stream-json into a readable play-by-play, and saves the raw stream.
//   claude -p ... --output-format stream-json --verbose | node render.mjs <raw.jsonl>
import fs from "node:fs";
import readline from "node:readline";

const raw = process.argv[2] ? fs.createWriteStream(process.argv[2]) : null;
const C = { dim: "\x1b[2m", red: "\x1b[31m", green: "\x1b[32m", gold: "\x1b[33m", bold: "\x1b[1m", off: "\x1b[0m" };
const trim = (s, n = 6) => String(s).trim().split("\n").slice(0, n).join("\n    ");
const tools = new Map();

const text = (c) => (typeof c === "string" ? c : Array.isArray(c) ? c.map((x) => x.text || "").join("\n") : "");

for await (const line of readline.createInterface({ input: process.stdin })) {
  if (!line.trim()) continue;
  raw?.write(line + "\n");
  let m;
  try { m = JSON.parse(line); } catch { continue; }
  if (m.type === "assistant") {
    for (const b of m.message?.content || []) {
      if (b.type === "text" && b.text.trim()) console.log(`\n${C.bold}Claude:${C.off} ${b.text.trim()}`);
      if (b.type === "tool_use") {
        tools.set(b.id, b.name);
        const arg = b.input?.command ?? b.input?.file_path ?? b.input?.skill ?? JSON.stringify(b.input).slice(0, 120);
        console.log(`${C.gold}  > ${b.name}: ${arg}${C.off}`);
      }
    }
  } else if (m.type === "user") {
    for (const b of m.message?.content || []) {
      if (b.type !== "tool_result") continue;
      const body = text(b.content);
      if (b.is_error) console.log(`${C.red}    x ${trim(body, 8)}${C.off}`);
      else if (body.trim()) console.log(`${C.dim}    ${trim(body, 3)}${C.off}`);
    }
  } else if (m.type === "result") {
    const secs = Math.round((m.duration_ms || 0) / 1000);
    console.log(`\n${C.green}Done in ${secs}s, ${m.num_turns ?? "?"} turns.${C.off}`);
  }
}
raw?.end();
