// Drive headless Chrome via CDP to interactively test the playground.
// Usage: node tools/browser_test.mjs
import { spawn } from "node:child_process";
import { setTimeout as sleep } from "node:timers/promises";
import { writeFileSync } from "node:fs";

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PORT = 9223;
const URL_ = "http://localhost:8765/index.html";

const chrome = spawn(CHROME, [
  "--headless=new", "--disable-gpu", "--no-sandbox",
  `--remote-debugging-port=${PORT}`,
  "--window-size=1280,900", "about:blank",
], { stdio: "ignore" });
await sleep(1500);

async function getTarget() {
  for (let i = 0; i < 10; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const targets = await res.json();
      const page = targets.find(t => t.type === "page");
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(500);
  }
  throw new Error("no CDP page target");
}

const ws = new WebSocket(await getTarget());
await new Promise(r => ws.onopen = r);

let msgId = 0;
const pending = new Map();
ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  }
};

function send(method, params = {}) {
  const id = ++msgId;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => {
    pending.set(id, (msg) => msg.error ? reject(new Error(method + ": " + JSON.stringify(msg.error))) : resolve(msg.result));
    setTimeout(() => { if (pending.delete(id)) reject(new Error(method + " timeout")); }, 20000);
  });
}

async function evaluate(expression) {
  const r = await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error("page error: " + JSON.stringify(r.exceptionDetails.exception?.description || r.exceptionDetails.text));
  return r.result.value;
}

async function screenshot(path) {
  const r = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(path, Buffer.from(r.data, "base64"));
  console.log("saved", path);
}

// ---- test session ----
await send("Page.enable");
await send("Runtime.enable");
await send("Page.navigate", { url: URL_ });
await sleep(1500);

const boot = await evaluate("(() => ({ wasmReady: !!window.wasm, summary: document.getElementById('insp-summary').textContent }))()");
console.log("boot:", JSON.stringify(boot));

// tab: clean
console.log("clean:", JSON.stringify(await evaluate(`(() => {
  document.querySelector('[data-tab="clean"]').click();
  document.getElementById('clean-demo').click();
  document.getElementById('clean-run').click();
  const out = document.getElementById('clean-output').value;
  const stats = document.getElementById('clean-stats').textContent;
  return { out, stats };
})()`)));
await screenshot("/tmp/wm_clean.png");

// tab: detect
console.log("detect:", JSON.stringify(await evaluate(`(() => {
  document.querySelector('[data-tab="detect"]').click();
  document.getElementById('det-demo').click();
  document.getElementById('det-run').click();
  const r = document.getElementById('det-result');
  return { visible: !r.classList.contains('hidden'), verdict: r.querySelector('.verdict').textContent.trim() };
})()`)));
await screenshot("/tmp/wm_detect.png");

// language switch
console.log("lang:", JSON.stringify(await evaluate(`(() => {
  document.getElementById('btn-lang').click();
  return {
    tagline: document.querySelector('.tagline').textContent,
    tab: document.querySelector('.tab.active').textContent,
    verdict: document.getElementById('det-result').querySelector('.verdict').textContent.trim(),
  };
})()`)));
await screenshot("/tmp/wm_en.png");

// i18n with detect result present (verdict text should be English)
console.log("verdict-en:", await evaluate("document.getElementById('det-result').querySelector('.verdict').textContent.trim()"));

// console errors?
chrome.kill();
console.log("done");
