/* wmtool playground — i18n + wasm glue */

// ---------------- i18n ----------------
const I18N = {
  zh: {
    title: "WMTOOL",
    tagline: "LLM 文本水印工具箱 v0.1",
    tabInspect: "▚ 检查",
    tabClean: "▞ 清洗",
    tabDetect: "▞ 检测",
    inputPh: "在此粘贴文本…",
    outputPh: "清洗结果…",
    aggressive: "严格模式(标记拉丁同形字)",
    stripGlue: "视承重字符为可疑",
    normSpaces: "空格同形字归一",
    paranoid: "偏执模式(连承重字符也剥离)",
    stripBidi: "剥离方向控制符",
    loadDemo: "载入示例",
    runInspect: "开始扫描",
    runClean: "开始清洗",
    runDetect: "开始检测",
    key: "密钥",
    window: "窗口 H",
    threshold: "阈值",
    footer: "仅处理你拥有或获授权的内容 · 检测为同密钥重放,阴性结果不构成证据",
    scanning: "扫描中…",
    cleaning: "清洗中…",
    detecting: "检测中…",
    empty: "请先输入文本",
    noHits: "未发现隐形 Unicode 载体。统计水印与像素水印不在本页范围内。",
    inspSummary: (n, total) => `长度 <b>${n}</b> 字符 · 可疑 <b>${total}</b> 处`,
    statLine: (label, val) => `${label}: ${val}`,
    removed: "剥离",
    replaced: "替换",
    len: "长度",
    copied: "已复制",
    detTokens: (total, counted, skipped) => `token 共 ${total} · 计入 ${counted} · 跳过 ${skipped}`,
    watermarked: "⚠ 检出水印",
    notWatermarked: "✓ 未检出水印",
    pvalue: "p 值",
    score: "得分 (-log₁₀p)",
    statistic: "统计量",
    introHead: "▍这是什么",
    introInspect1: "检查文本里的「隐形字符」:零宽空格、方向控制符、变体选择器等肉眼看不见的 Unicode 字符,常被用来给文本打标记。",
    introInspect2: "用途:找出可疑字符是什么、在哪、有多少,判断文本是否被动过手脚。",
    introInspectCant: "只查字符层面的标记;统计类水印(靠改词换句)在这里查不出来。",
    introClean1: "按你勾选的规则清洗文本:空格同形字归一、同形字转 ASCII、剥离零宽字符与方向控制符。",
    introClean2: "用途:发布、粘贴或存档前移除隐形标记,输出可直接复制使用。",
    introCleanCant: "只作用于字符层面,不影响统计水印;承重字符(如 emoji 连接符)默认保留,以免破坏显示。",
    introDetect1: "检测统计类文本水印:用你提供的密钥重演水印规则,看文本里的 token 是否像「由这把钥匙生成」。",
    introDetect2: "用途:验证一段文本是否由持有该密钥的模型生成。",
    introDetectCant: "密钥、窗口、分词必须与生成时完全一致;没检出不代表无水印,只是「这把钥匙没检出」。",
    helpAggressive: "把同形异体拉丁字母(如西里尔 А)也标记出来;更严格,可能有误报。",
    helpStripGlue: "默认跳过 emoji 连接符等「承重字符」;勾选后连它们也标为可疑。",
    helpNormSpaces: "把各种长得像空格的字符统一成普通空格(默认开启)。",
    helpHomoglyphs: "把西里尔 А、全角字母等转成 ASCII 字母;文字外观可能变化。",
    helpParanoid: "连 emoji 连接符等承重字符也剥离,可能破坏表情和组合字符。",
    helpBidi: "移除 LTR/RTL 方向控制符;它们能反转文字的显示顺序。",
    helpKey: "生成文本时用的密钥;检测用同一把钥匙重演水印。",
    helpWindow: "生成时的窗口大小 H(默认 4);必须与生成一致。",
    helpThreshold: "p 值低于此值即判定检出;默认 0.000001(百万分之一)。",
    inspStep1: "扫描文本",
    inspStep2: "分类可疑字符",
    inspStep3: "定位码点偏移",
    inspStep4: "汇总结果",
    cleanStep1: "归一化空格",
    cleanStep2: "剥离方向控制符",
    cleanStep3: "替换同形字",
    cleanStep4: "汇总统计",
    detStep1: "确定性分词",
    detStep2: "按密钥重放噪声",
    detStep3: "计算统计量",
    detStep4: "p 值判定",
    guideTitle: "如何读结果 ▸",
    guideInsp1: "每行一个可疑字符:红=疑似,青=提示;中间是码点(U+XXXX)和 Unicode 名称,×N 是出现次数。",
    guideInsp2: "「码点偏移」是各次出现的位置(从 0 数起),最多列 10 个示例。",
    guideInsp3: "没找到不等于干净:统计类水印不在此页的检查范围内。",
    guideInsp4: "列表下方的说明解释了检查范围,以及哪些字符默认被视为「正常」。",
    guideClean1: "「剥离」=字符被删除;「替换」=换成普通字符;数字是各改了多少处。",
    guideClean2: "下方表格逐类列出动了哪些字符,方便确认没有误伤正常内容。",
    guideClean3: "输出可直接复制;开「偏执模式」时,表情或组合字符可能被破坏。",
    guideDetect1: "p 值是「纯随机文本也出现这个统计量」的概率,越小越像打了水印;低于阈值即判定检出。",
    guideDetect2: "得分 = -log₁₀(p):例如 p=0.001 得分就是 3;越大越可疑。",
    guideDetect3: "「检出」只说明:用这把钥匙重放,文本符合水印规律;换钥匙可能就检不出。",
    guideDetect4: "被跳过的 token 不参与统计:开头没有上下文的,以及窗口内重复出现的。",
    badgeProbable: "疑似",
    badgeInfo: "提示",
    offsets: "码点偏移",
    tokens: "TOKEN",
    detSkipCtx: "无上下文",
    detSkipRepeat: "重复窗口",
    copy: "复制",
    copyFail: "复制失败",
    tableChar: "字符",
    tableCount: "数量",
    nfkcChanged: "NFKC 归一化改变了文本(全文统一为兼容形式)",
    cleanNoop: "未做任何修改:没有字符匹配到开启的规则",
    explainScore: "p 值 = 随机文本出现该统计量的概率;得分 = -log₁₀(p),越大越可疑。",
    explainWatermarked: "p 值低于阈值:这段文本极可能由持有该密钥的生成器输出(同密钥重放)。",
    explainClean: "p 值未低于阈值:这把钥匙没检出。这不等于无水印——密钥或分词不同就测不到。",
    detMeta: (d, s) => `探测器 ${d} · 方案 ${s}`,
    wasmFail: "WebAssembly 加载失败,请刷新重试:",
    runError: "运行出错:",
    toEn: "EN_中文",
  },
  en: {
    title: "WMTOOL",
    tagline: "LLM text watermark toolkit v0.1",
    tabInspect: "▚ INSPECT",
    tabClean: "▞ CLEAN",
    tabDetect: "▞ DETECT",
    inputPh: "Paste text here…",
    outputPh: "Cleaned output…",
    aggressive: "Aggressive (flag Latin confusables)",
    stripGlue: "Treat glue as suspicious",
    normSpaces: "Normalize space homoglyphs",
    paranoid: "Paranoid (strip glue too)",
    stripBidi: "Strip bidi controls",
    loadDemo: "DEMO",
    runInspect: "SCAN",
    runClean: "CLEAN",
    runDetect: "DETECT",
    key: "KEY",
    window: "WINDOW H",
    threshold: "THRESHOLD",
    footer: "Only for content you own or are authorized to process · detection is same-key replay; a negative result proves nothing",
    scanning: "Scanning…",
    cleaning: "Cleaning…",
    detecting: "Detecting…",
    empty: "Input some text first",
    noHits: "No invisible-Unicode carriers found. Statistical and pixel watermarks are out of scope here.",
    inspSummary: (n, total) => `Length <b>${n}</b> chars · suspicious <b>${total}</b>`,
    statLine: (label, val) => `${label}: ${val}`,
    removed: "Removed",
    replaced: "Replaced",
    len: "Length",
    copied: "Copied",
    detTokens: (total, counted, skipped) => `tokens ${total} · counted ${counted} · skipped ${skipped}`,
    watermarked: "⚠ WATERMARKED",
    notWatermarked: "✓ NOT WATERMARKED",
    pvalue: "p-value",
    score: "Score (-log₁₀p)",
    statistic: "Statistic",
    introHead: "▍WHAT THIS DOES",
    introInspect1: "Scans text for \"invisible characters\" — zero-width spaces, direction controls, variation selectors — Unicode characters you can't see, often used to tag text.",
    introInspect2: "Use it to find out what suspicious characters exist, where they are, and how many — to judge whether text has been tampered with.",
    introInspectCant: "Character-level marks only; statistical watermarks (word swaps) can't be caught here.",
    introClean1: "Cleans text with the rules you tick: normalize space look-alikes, convert confusables to ASCII, strip zero-width and direction-control characters.",
    introClean2: "Use it before publishing or archiving to remove invisible marks; the output is ready to copy.",
    introCleanCant: "Character-level only; statistical watermarks are untouched. Load-bearing characters (e.g. emoji joiners) are kept by default so nothing breaks.",
    introDetect1: "Detects statistical text watermarks: replays the watermark rule with your key and tests whether the tokens look like they came from that key.",
    introDetect2: "Use it to check whether text was produced by a model holding this key.",
    introDetectCant: "Key, window and tokenization must match generation exactly. Not detected does not mean no watermark — only that this key found nothing.",
    helpAggressive: "Also flags look-alike Latin letters (e.g. Cyrillic А). Stricter, may over-report.",
    helpStripGlue: "Emoji joiners and other \"load-bearing\" characters are skipped by default; ticking this flags them too.",
    helpNormSpaces: "Turns space look-alikes into a normal space (on by default).",
    helpHomoglyphs: "Converts Cyrillic А, full-width letters etc. to ASCII; the text may look different.",
    helpParanoid: "Strips load-bearing characters too (emoji joiners…); may break emoji and combined glyphs.",
    helpBidi: "Removes LTR/RTL direction controls, which can reverse the visual order of text.",
    helpKey: "The key used at generation; detection replays the watermark with the same key.",
    helpWindow: "Window size H used at generation (default 4); must match.",
    helpThreshold: "A p-value below this is flagged; default 0.000001 (one in a million).",
    inspStep1: "Scan text",
    inspStep2: "Classify suspicious characters",
    inspStep3: "Locate code-point offsets",
    inspStep4: "Summarize report",
    cleanStep1: "Normalize spaces",
    cleanStep2: "Strip direction controls",
    cleanStep3: "Replace confusables",
    cleanStep4: "Summarize stats",
    detStep1: "Tokenize (deterministic)",
    detStep2: "Replay noise with key",
    detStep3: "Compute statistic",
    detStep4: "Judge p-value",
    guideTitle: "How to read results ▸",
    guideInsp1: "One line per suspicious character: red = probable, cyan = informational; then the code point (U+XXXX) and Unicode name; ×N is the count.",
    guideInsp2: "\"Offsets\" are the positions of each occurrence (counted from 0), up to 10 examples.",
    guideInsp3: "Nothing found does not mean clean: statistical watermarks are out of scope here.",
    guideInsp4: "The notes below explain the scope and which characters are treated as normal by default.",
    guideClean1: "\"Removed\" means deleted; \"replaced\" means swapped for a normal character; the numbers are how many.",
    guideClean2: "The table lists exactly which characters changed, so you can confirm nothing normal was harmed.",
    guideClean3: "The output is copyable. With paranoid mode on, emoji or combined glyphs may break.",
    guideDetect1: "The p-value is the probability that random text would produce this statistic; the smaller it is, the more watermark-like. Below the threshold it's flagged.",
    guideDetect2: "Score = -log₁₀(p): p = 0.001 gives a score of 3. Bigger = more suspicious.",
    guideDetect3: "A hit only means the text matches the watermark pattern when replayed with this key; another key may find nothing.",
    guideDetect4: "Skipped tokens don't count: those without context at the start, and duplicates inside a window.",
    badgeProbable: "PROBABLE",
    badgeInfo: "INFO",
    offsets: "offsets",
    tokens: "TOKENS",
    detSkipCtx: "no context",
    detSkipRepeat: "repeated window",
    copy: "COPY",
    copyFail: "COPY FAILED",
    tableChar: "CHARACTER",
    tableCount: "COUNT",
    nfkcChanged: "NFKC normalization changed the text (compatibility forms applied)",
    cleanNoop: "No changes: no characters matched the enabled rules",
    explainScore: "p-value = probability that random text would produce this statistic; score = -log₁₀(p), higher is more suspicious.",
    explainWatermarked: "p-value below threshold: this text very likely came from a generator holding this key (same-key replay).",
    explainClean: "p-value not below threshold: nothing found with this key. That doesn't mean no watermark — a different key or tokenizer would miss it.",
    detMeta: (d, s) => `detector ${d} · scheme ${s}`,
    wasmFail: "WebAssembly load failed, please refresh:",
    runError: "Run failed:",
    toZh: "中文_EN",
  },
};

// ---------------- kind / note translation tables ----------------
const KIND_INFO = {
  strip: {
    zh: { name: "可剥离字符", desc: "通用隐形字符(零宽空格等),清洗时会被剥离" },
    en: { name: "Strippable", desc: "Generic invisible characters (e.g. zero-width space); removed by cleaning" },
  },
  bidi: {
    zh: { name: "方向控制符", desc: "控制文字显示方向,可能让文本「倒着读」" },
    en: { name: "Bidi control", desc: "Controls text direction; can make text display reversed" },
  },
  tag_chars: {
    zh: { name: "隐形标签", desc: "U+E0000 区标签字符,常用于嵌入隐藏标记" },
    en: { name: "Hidden tag", desc: "U+E0000-range tag characters, often used to embed hidden marks" },
  },
  variation_selector: {
    zh: { name: "变体选择器", desc: "改变前一个字符的字形;部分(如 emoji 肤色)属正常排版" },
    en: { name: "Variation selector", desc: "Changes the glyph of the previous character; some (e.g. emoji skin tone) are normal typography" },
  },
  zwj_family: {
    zh: { name: "零宽连接符", desc: "把相邻字符连成一个整体(如家庭 emoji);剥离会破坏显示" },
    en: { name: "Zero-width joiner", desc: "Joins adjacent characters (e.g. family emoji); stripping breaks them" },
  },
  private_use: {
    zh: { name: "私用区字符", desc: "Unicode 私用区;各平台含义不同,常被用于自定义标记" },
    en: { name: "Private use", desc: "Unicode private-use area; platform-specific, often used for custom marks" },
  },
  space: {
    zh: { name: "空格同形字", desc: "长得像空格但不是空格(如不换行空格 NBSP)" },
    en: { name: "Space homoglyph", desc: "Looks like a space but isn't (e.g. non-breaking space)" },
  },
  confusable: {
    zh: { name: "同形字", desc: "外形与常见字母几乎相同(如西里尔 А 冒充 A);仅严格模式标记" },
    en: { name: "Confusable", desc: "Nearly identical to a common letter (e.g. Cyrillic А posing as A); flagged only in aggressive mode" },
  },
  other_cf: {
    zh: { name: "其他格式符", desc: "其他 Cf 类格式控制字符" },
    en: { name: "Other format", desc: "Other Cf-class format control characters" },
  },
};

const NOTE_MAP = {
  "Layer A only: invisible/format Unicode and space homoglyphs (edit-based carriers).":
    { zh: "本页只检查「改字符」式水印:Unicode 隐形/格式字符与空格同形字。", variant: "info" },
  "Statistical (token-sampling) watermarks are not detectable here; use Layer B rewrite.":
    { zh: "统计类(token 采样)水印在本页查不出来,请到「检测」页。", variant: "info" },
  "Inspect kinds: strip, bidi, tag_chars, variation_selector, zwj_family, private_use, space, confusable, other_cf.":
    { zh: "检查的类别:可剥离字符、方向控制符、隐形标签、变体选择器、零宽连接符、私用区字符、空格同形字、同形字、其他格式符。", variant: "info" },
  "Load-bearing invisibles are preserved by default during cleaning: emoji glue, CJK/Mongolian variation selectors, script joiners, complete flag tag sequences, same-script fillers/selectors (Mongolian FVS, Khmer inherent vowels, Hangul jamo fillers), RTL directional marks/paired embeddings, orthographic Arabic/Syriac Cf marks, and visible-layout format controls next to their own script (Egyptian hieroglyph quadrat, Duployan shorthand, musical beaming). Inspection still reports bidi controls. Use explicit strip flags only after review.":
    { zh: "清洗时默认保留以下「承重」隐形字符,以免破坏正常显示:emoji 连接符、CJK/蒙古文变体选择器、脚本连接符、完整的旗帜标签序列、同文种填充/选择符(蒙古文 FVS、高棉文固有元音、谚文 jamo 填充)、RTL 方向标记与成对嵌入、阿拉伯/叙利亚文拼写所需的 Cf 字符,以及紧邻自身文种的可见布局格式符(埃及象形文字方块、Duployan 速记、音乐连音符)。本页仍会报告方向控制符;只有在确认后,才建议勾选剥离选项。", variant: "warn" },
  "No deterministic Layer A (invisible Unicode/format) carriers detected; statistical and pixel-domain marks are out of scope here.":
    { zh: "未发现字符层的隐形标记;统计水印与像素水印不在本页范围内。", variant: "ok" },
  "no verifiable token positions (text too short for a full context window)":
    { zh: "文本太短,凑不出一个完整的上下文窗口,无法统计。", variant: "warn" },
  "same-key replay of the keyed-Gumbel (Aaronson EXP) watermark; valid only against the same key, tokenizer, and PRF layout used at generation":
    { zh: "这是「同密钥重放」检测:结果只在与生成时相同的密钥、分词方式、PRF 布局下才有效。", variant: "warn" },
};

let lang = "zh";
const t = () => I18N[lang];

const $ = (id) => document.getElementById(id);

function applyLang() {
  document.documentElement.lang = lang === "zh" ? "zh-CN" : "en";
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const v = t()[el.dataset.i18n];
    if (typeof v === "string") el.textContent = v;
  });
  document.querySelectorAll("[data-i18n-ph]").forEach((el) => {
    el.placeholder = t()[el.dataset.i18nPh];
  });
  $("btn-lang").textContent = lang === "zh" ? t().toEn : t().toZh;
}

$("btn-lang").addEventListener("click", () => {
  lang = lang === "zh" ? "en" : "zh";
  applyLang();
  // re-render cached results so labels follow the new language
  if (lastInspect) renderInspect(lastInspect);
  if (lastClean) renderCleanStats(lastClean);
  if (lastDetect) renderDetect(lastDetect);
});

let lastDetect = null;
let lastClean = null;
let lastInspect = null;

// ---------------- tabs ----------------
document.querySelectorAll(".tab").forEach((tab) => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((x) => x.classList.remove("active"));
    document.querySelectorAll(".panel").forEach((x) => x.classList.remove("active"));
    tab.classList.add("active");
    $(`panel-${tab.dataset.tab}`).classList.add("active");
  });
});

// ---------------- wasm ----------------
let wasm = null;

async function initWasm() {
  // compileOptions is a non-standard third argument understood by V8: it
  // auto-provisions the `wasm:js-string` builtins and the `_` imported
  // string constants. Other engines ignore it, so we always pass an
  // explicit import object instead (WASM_STRING_IMPORTS is generated by
  // tools/gen_string_imports.mjs; the builtins below are the js-string
  // builtins proposal surface used by the MoonBit runtime).
  const compileOptions = { builtins: ["js-string"], importedStringConstants: "_" };
  const imports = {
    _: WASM_STRING_IMPORTS,
    "wasm:js-string": {
      length: (s) => s.length,
      charCodeAt: (s, i) => s.charCodeAt(i),
      equals: (a, b) => (a === b ? 1 : 0),
      concat: (a, b) => a + b,
      fromCodePoint: (c) => String.fromCodePoint(c),
      fromCharCodeArray: (arr) => {
        let out = "";
        const n = arr.length;
        for (let i = 0; i < n; i++) out += String.fromCharCode(arr.get(i));
        return out;
      },
    },
  };
  // instantiateStreaming needs an application/wasm response; fall back to
  // a buffer for static hosts with generic MIME types.
  let instance;
  try {
    ({ instance } = await WebAssembly.instantiateStreaming(
      fetch("main.wasm"), imports, compileOptions,
    ));
  } catch {
    const buf = await (await fetch("main.wasm")).arrayBuffer();
    ({ instance } = await WebAssembly.instantiate(buf, imports, compileOptions));
  }
  wasm = instance.exports;
}

// ---------------- demos ----------------
const DEMO = "Vi\u200Bsi\u200Bble \u0410\u0412\u0415 text\uFEFF a\u00A0b \u{1F468}\u200D\u{1F4BB} done\u200C";
const DEMO_DETECT = "the quick brown fox jumps over the lazy dog and keeps running through the field until the sun goes down behind the hills";

for (const id of ["insp-demo", "clean-demo"]) {
  $(id).addEventListener("click", () => { $(id.replace("demo", "input")).value = DEMO; });
}
$("det-demo").addEventListener("click", () => { $("det-input").value = DEMO_DETECT; });

// ---------------- shared helpers ----------------
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// core notes arrive in English; zh uses the NOTE_MAP, en keeps the original
const translateNote = (n) => (lang === "zh" && NOTE_MAP[n] ? NOTE_MAP[n].zh : n);
const noteVariant = (n) => (NOTE_MAP[n] && NOTE_MAP[n].variant) || "info";
const kindInfo = (k) => (KIND_INFO[k] && KIND_INFO[k][lang]) || { name: k, desc: "" };

function showErr(id, msg) {
  const el = $(id);
  el.textContent = msg;
  el.classList.remove("hidden");
}
function hideErr(id) { $(id).classList.add("hidden"); }

// Runs the (synchronous, near-instant) wasm call, then animates the panel's
// step list — the steps label the real internal stages of that call, not
// invented progress.
async function runPipeline({ panel, busyKey, idleKey, compute, render }) {
  const runBtn = $(panel + "-run");
  const box = $(panel + "-steps");
  runBtn.disabled = true;
  runBtn.textContent = t()[busyKey];
  hideErr(panel + "-err");
  box.classList.remove("hidden");
  const steps = [...box.querySelectorAll(".step")];
  steps.forEach((s) => s.classList.remove("done", "current"));
  steps[0]?.classList.add("current");
  let result;
  try {
    result = compute();
  } catch (e) {
    showErr(panel + "-err", t().runError + " " + e.message);
    box.classList.add("hidden");
    runBtn.disabled = false;
    runBtn.textContent = t()[idleKey];
    return;
  }
  for (let i = 0; i < steps.length; i++) {
    await sleep(80);
    steps[i].classList.add("done");
    steps[i].classList.remove("current");
    if (steps[i + 1]) steps[i + 1].classList.add("current");
  }
  render(result);
  await sleep(120);
  box.classList.add("hidden");
  runBtn.disabled = false;
  runBtn.textContent = t()[idleKey];
}

async function copyText(btn, text) {
  let ok = false;
  try { await navigator.clipboard.writeText(text); ok = true; } catch {}
  if (!ok) {
    try {
      const ta = document.createElement("textarea");
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      ok = document.execCommand("copy");
      ta.remove();
    } catch {}
  }
  btn.textContent = ok ? t().copied + " ✓" : t().copyFail;
  setTimeout(() => { btn.textContent = t().copy; }, 1500);
}

// ---------------- inspect ----------------
$("insp-run").addEventListener("click", () => {
  const text = $("insp-input").value;
  if (!text) { showErr("insp-err", t().empty); return; }
  runPipeline({
    panel: "insp",
    busyKey: "scanning",
    idleKey: "runInspect",
    compute: () => JSON.parse(wasm.inspect_text(JSON.stringify({
      text,
      aggressive: $("insp-aggressive").checked,
      stripEmojiGlue: $("insp-glue").checked,
    }))),
    render: (out) => {
      lastInspect = out;
      renderInspect(out);
    },
  });
});

function renderInspect(out) {
  const s = $("insp-summary");
  s.classList.remove("hidden");
  s.innerHTML = t().inspSummary(out.length, out.suspicious_total);
  const hits = $("insp-hits");
  hits.innerHTML = "";
  if (out.hits.length === 0) {
    hits.innerHTML = `<div class="summary">${t().noHits}</div>`;
  } else {
    for (const h of out.hits) {
      const ki = kindInfo(h.kind);
      const offs = (h.sample_offsets || []).join(", ")
        + (h.count > (h.sample_offsets || []).length ? ", …" : "");
      const el = document.createElement("div");
      el.className = "hit new";
      el.innerHTML = `
        <span class="badge ${h.confidence}">${h.confidence === "probable" ? t().badgeProbable : t().badgeInfo}</span>
        <span class="badge kind kind-${h.kind}">${ki.name}</span>
        <span class="cp">${h.codepoint}</span>
        <span class="label">${h.label}</span>
        <span class="count">×<b>${h.count}</b></span>
        <span class="hit-detail">${ki.desc}${offs ? ` <span class="off">${t().offsets}: ${offs}</span>` : ""}</span>`;
      hits.appendChild(el);
    }
  }
  const notes = document.createElement("div");
  notes.className = "notes";
  for (const n of out.notes) {
    notes.innerHTML += `<div class="callout ${noteVariant(n)}">${translateNote(n)}</div>`;
  }
  hits.appendChild(notes);
}

// ---------------- clean ----------------
$("clean-run").addEventListener("click", () => {
  const text = $("clean-input").value;
  if (!text) { showErr("clean-err", t().empty); return; }
  runPipeline({
    panel: "clean",
    busyKey: "cleaning",
    idleKey: "runClean",
    compute: () => JSON.parse(wasm.clean_text(JSON.stringify({
      text,
      normalizeSpaces: $("clean-spaces").checked,
      aggressiveHomoglyphs: $("clean-homoglyphs").checked,
      stripEmojiGlue: $("clean-glue").checked,
      stripBidi: $("clean-bidi").checked,
    }))),
    render: (out) => {
      $("clean-output").value = out.output;
      lastClean = out;
      renderCleanStats(out);
    },
  });
});

function renderCleanStats(out) {
  const st = out.stats;
  const s = $("clean-stats");
  s.classList.remove("hidden");
  const lines = [
    t().statLine(t().len, `${st.input_length} → ${st.output_length}`),
    t().statLine(t().removed, st.removed_count),
    t().statLine(t().replaced, st.replaced_count),
  ];
  if (st.nfkc_changed) lines.push(t().nfkcChanged);
  if (st.removed_count + st.replaced_count === 0) lines.push(t().cleanNoop);
  s.innerHTML = lines.join("\n");
  const b = $("clean-breakdown");
  const parts = [[t().removed, st.removed || {}], [t().replaced, st.replaced || {}]]
    .filter(([, m]) => Object.keys(m).length)
    .map(([title, m]) =>
      `<h4>${title}</h4><table><tr><th>${t().tableChar}</th><th>${t().tableCount}</th></tr>` +
      Object.entries(m).map(([k, v]) => `<tr><td>${k}</td><td class="num">${v}</td></tr>`).join("") +
      `</table>`)
    .join("");
  b.classList.toggle("hidden", !parts);
  if (parts) b.innerHTML = parts;
}

$("clean-copy").addEventListener("click", () => {
  copyText($("clean-copy"), $("clean-output").value);
});

// ---------------- detect ----------------
$("det-run").addEventListener("click", () => {
  const text = $("det-input").value;
  if (!text) { showErr("det-err", t().empty); return; }
  runPipeline({
    panel: "det",
    busyKey: "detecting",
    idleKey: "runDetect",
    compute: () => JSON.parse(wasm.detect_text(JSON.stringify({
      text,
      key: $("det-key").value,
      window: parseInt($("det-window").value, 10) || 4,
      threshold: parseFloat($("det-threshold").value) || 0.000001,
    }))),
    render: (out) => {
      lastDetect = out;
      renderDetect(out);
    },
  });
});

function renderDetect(out) {
  const r = $("det-result");
  r.classList.remove("hidden");
  const fmt = (x) => (x === null || x === undefined) ? "—" : Number(x).toPrecision(4);
  const skipped = out.skipped_no_context + out.skipped_repeated;
  r.innerHTML = `
    <span class="k">${t().detMeta(out.detector, out.scheme)}</span><span class="v">${out.vendor}</span>
    <span class="k">${t().window}</span><span class="v">${out.window}</span>
    <span class="k">${t().threshold}</span><span class="v">${fmt(out.threshold)}</span>
    <span class="k">${t().pvalue}</span><span class="v"><b>${fmt(out.p_value)}</b></span>
    <span class="k">${t().statistic}</span><span class="v">${fmt(out.statistic)}</span>
    <span class="k">${t().score}</span><span class="v">${fmt(out.score)}</span>
    <span class="k">${t().tokens}</span><span class="v">${t().detTokens(out.tokens_total, out.counted, skipped)}</span>
    <div class="skip-line">${t().detSkipCtx}: ${out.skipped_no_context} · ${t().detSkipRepeat}: ${out.skipped_repeated}</div>
    ${out.note ? `<div class="callout ${noteVariant(out.note)}">${translateNote(out.note)}</div>` : ""}
    <div class="verdict ${out.is_watermarked ? "watermarked" : "clean"}">
      ${out.is_watermarked ? t().watermarked : t().notWatermarked}
    </div>
    <div class="callout ${out.is_watermarked ? "ok" : "info"}">${out.is_watermarked ? t().explainWatermarked : t().explainClean}</div>
    <div class="callout info">${t().explainScore}</div>`;
}

// ---------------- boot ----------------
(async () => {
  applyLang(); // sync static zh HTML with the dict (and set the lang button)
  try {
    await initWasm();
    $("insp-demo").click(); // preload demo for first impression
    $("insp-run").click();
  } catch (e) {
    console.error(e);
    const d = document.createElement("div");
    d.className = "err";
    d.textContent = t().wasmFail + " " + e.message;
    document.querySelector("main").prepend(d);
  }
})();
