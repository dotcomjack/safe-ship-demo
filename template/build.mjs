// Builds dist/index.html from the headline and the price formatter.
import fs from "node:fs";
import { formatPrice } from "./pricing.js";

const headline = fs.readFileSync("site/headline.txt", "utf8").trim();
fs.mkdirSync("dist", { recursive: true });
fs.writeFileSync("dist/index.html", `<!doctype html><title>Acme</title>
<h1>${headline}</h1>
<p class="price">Pro: ${formatPrice(1999)} a month</p>
`);
