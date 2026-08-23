//! Layer B: LLM rewrite loop (paraphrase-class removal, best-effort).
//!
//! Port of watermarks-remover `rewrite_text.py` (MIT), OpenAI-compatible
//! backend only, with the same detection-guided loop: generate candidates,
//! optionally Layer-A clean them, evaluate with the keyed-Gumbel detector
//! when a key is configured (else lexical divergence), stop at the first
//! passing attempt, otherwise return the best-effort variant.
//!
//! Same-key gumbel evaluation is only meaningful against the same key used
//! at generation; without it the evaluator has no verdict and every attempt
//! is generated, selecting the most lexically diverged variant.

///|
pub(all) struct RewriteOptions {
  strength : String // paraphrase | humanize | code | backtranslate | structural
  lang : String
  original_lang : String
  temperature : Double
  candidates : Int
  max_loops : Int
  layer_a_after : Bool
  gumbel_key : String? // detection-guided evaluation when set
}

///|
pub(all) struct RewriteAttempt {
  text : String
  loop_index : Int
  lexical_divergence : Double
  passed : Bool? // None = evaluator without verdict
  gumbel_score : Double? // set when the gumbel evaluator ran
  mut selected : Bool
}

///|
pub(all) struct RewriteInfo {
  backend : String
  model : String
  base_url : String
  strength : String
  temperature : Double
  prompt_chars : Int
  input_chars : Int
  evaluator : String
  attempts : Array[RewriteAttempt]
  passed : Bool?
}

///|
let prompt_paraphrase : String = "Rewrite the following text so that it uses substantially different wording at the token level. Change clause order, connectors, and transition words; vary sentence boundaries and length; and replace both content words and function words where meaning allows. Preserve all facts, numbers, names, and technical identifiers. Do not add or remove claims. Output only the rewritten text.\n\n---\n"

///|
let prompt_humanize : String = "Rewrite the following text so it reads as if a human wrote it from scratch. Vary sentence rhythm and length, replace formulaic AI-style transitions and filler with concrete natural phrasing, and use plain, varied wording. Preserve all facts, numbers, names, and technical identifiers. Do not add or remove claims. Output only the rewritten text.\n\n---\n"

///|
let prompt_code : String = "Rewrite the natural-language parts of this code \u{2014} comments, docstrings, and string literals \u{2014} using different wording. Rename local variables, function parameters, and private helper names to semantically equivalent names. Preserve program behavior, public API names, and all values that affect output. Output only the rewritten code.\n\n---\n"

///|
pub fn build_prompt(
  strength : String,
  text : String,
  lang? : String = "English",
  original_lang? : String = "English",
) -> String raise RewriteError {
  match strength {
    "paraphrase" => prompt_paraphrase + text
    "humanize" => prompt_humanize + text
    "code" => prompt_code + text
    "backtranslate" =>
      "Translate the text to " +
      lang +
      ", then translate that result back to " +
      original_lang +
      ". Preserve all facts, numbers, and names. Output only the final " +
      original_lang +
      " text.\n\n---\n" +
      text
    "structural" =>
      "First extract a bullet outline of all claims (no full sentences). Then write a complete document from that outline in natural, varied human prose without omitting any bullet. Output only the final document.\n\n---\n" +
      text
    _ => raise UnknownStrength(strength)
  }
}

///|
pub(all) suberror RewriteError {
  UnknownStrength(String)
  RemoteBlocked(String)
  BadApiResponse(String)
} derive(Eq, @debug.Debug)

// ---------------------------------------------------------------------------
// Lexical divergence (bigram Jaccard)
// ---------------------------------------------------------------------------

///|
fn word_tokens(text : String) -> Array[String] {
  let lowered = text.to_lower()
  let toks : Array[String] = []
  try {
    let re = @string.Regex::Regex("[A-Za-z0-9]+")
    for m in re.find(lowered) {
      toks.push(m.content().to_owned())
    }
  } catch {
    _ => ()
  }
  toks
}

///|
fn bigram_set(tokens : Array[String]) -> Map[String, Bool] {
  let set : Map[String, Bool] = Map([])
  for i in 0..<(tokens.length() - 1) {
    set.set(tokens[i] + "\u{1F}" + tokens[i + 1], true)
  }
  set
}

///|
/// Bigram Jaccard distance: 0.0 identical, 1.0 fully different.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(lexical_divergence("same words here", "same words here"), content="0")
///   inspect(lexical_divergence("one two three", "four five six"), content="1")
///   inspect(lexical_divergence("a b c", ""), content="1")
/// }
/// ```
pub fn lexical_divergence(original : String, candidate : String) -> Double {
  let a = word_tokens(original)
  let b = word_tokens(candidate)
  if a.length() == 0 && b.length() == 0 {
    return 0.0
  }
  if a.length() == 0 || b.length() == 0 {
    return 1.0
  }
  let ba = bigram_set(a)
  let bb = bigram_set(b)
  let mut inter = 0
  ba.each(fn(k, _) { if bb.get(k).unwrap_or(false) { inter = inter + 1 } })
  let union = ba.length() + bb.length() - inter
  if union == 0 {
    return 0.0
  }
  1.0 - inter.to_double() / union.to_double()
}

///|
/// Most lexically diverged rewrite, gently guarding extreme length drift.
pub fn select_candidate(
  original : String,
  candidates : Array[String],
) -> (Int, Array[Double]) {
  let scores : Array[Double] = []
  let mut best = 0
  let mut best_score = -1.7976931348623157e308
  for i in 0..<candidates.length() {
    let cand = candidates[i]
    let mut score = lexical_divergence(original, cand)
    if original != "" {
      let ratio = cand.length().to_double() / original.length().to_double()
      if ratio > 2.0 || ratio < 0.5 {
        score = score - 0.15
      }
    }
    scores.push(score)
    if score > best_score {
      best_score = score
      best = i
    }
  }
  (best, scores)
}

// ---------------------------------------------------------------------------
// OpenAI-compatible transport
// ---------------------------------------------------------------------------

///|
fn is_loopback_host(host : String) -> Bool {
  host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
}

///|
/// Same safety rule as the reference: refuse non-loopback endpoints unless
/// explicitly allowed.
pub fn check_remote(
  base_url : String,
  allow_remote? : Bool = false,
) -> Unit raise RewriteError {
  if allow_remote {
    return
  }
  let host_part = base_url
  // strip scheme
  let after_scheme = match host_part.find("://") {
    Some(i) => host_part.sub(start=i + 3).to_owned()
    None => host_part
  }
  // strip path and port
  let mut host = after_scheme
  match host.find("/") {
    Some(i) => host = host.sub(end=i).to_owned()
    None => ()
  }
  match host.rev_find(":") {
    Some(i) => {
      let bracket_end = host.rev_find("]").unwrap_or(-1)
      if !host.contains("]") || i > bracket_end {
        host = host.sub(end=i).to_owned()
      }
    }
    None => ()
  }
  if !is_loopback_host(host) {
    raise RemoteBlocked(host)
  }
}

///|
fn extract_content(body : Json) -> String raise RewriteError {
  match body {
    Object(root) =>
      match root.get("choices") {
        Some(Array(choices)) => {
          if choices.length() == 0 {
            raise BadApiResponse("empty choices")
          }
          match choices[0] {
            Object(choice) =>
              match choice.get("message") {
                Some(Object(message)) =>
                  match message.get("content") {
                    Some(String(content)) => content
                    _ => raise BadApiResponse("empty content")
                  }
                _ => raise BadApiResponse("empty content")
              }
            _ => raise BadApiResponse("empty choices")
          }
        }
        _ => raise BadApiResponse("empty choices")
      }
    _ => raise BadApiResponse("unexpected response shape")
  }
}

///|
async fn call_openai_compatible(
  base_url : String,
  model : String,
  prompt : String,
  api_key? : String? = None,
  temperature? : Double = 1.0,
) -> String {
  let url = base_url + "/chat/completions"
  let headers : Map[@http.CaseInsensitiveString, String] = Map([])
  match api_key {
    Some(key) =>
      headers.set(CaseInsensitiveString("Authorization"), "Bearer " + key)
    None => ()
  }
  let payload : Map[String, Json] = Map([])
  payload.set("model", Json::string(model))
  let message : Map[String, Json] = Map([])
  message.set("role", Json::string("user"))
  message.set("content", Json::string(prompt))
  payload.set("messages", Json::array([Json::object(message)]))
  payload.set("temperature", Json::number(temperature))
  let body = Json::object(payload).stringify()
  let (response, data) = @http.post(url, body, headers~)
  if response.code != 200 {
    raise BadApiResponse("HTTP \{response.code}: \{response.reason}")
  }
  trim(extract_content(data.json()))
}

///|
fn trim(s : String) -> String {
  let mut out = s
  while out.length() > 0 && out[0] is (' ' | '\t' | '\r' | '\n') {
    out = out.sub(start=1).to_owned()
  }
  while out.length() > 0 && out[out.length() - 1] is (' ' | '\t' | '\r' | '\n') {
    out = out.sub(end=out.length() - 1).to_owned()
  }
  out
}

// ---------------------------------------------------------------------------
// Rewrite loop
// ---------------------------------------------------------------------------

///|
pub(all) struct RewriteResult {
  text : String
  info : RewriteInfo
}

///|
/// Run the iterative rewrite. `base_url` is an OpenAI-compatible endpoint
/// root that already includes the version prefix (for example
/// `http://127.0.0.1:11434/v1`).
pub async fn rewrite_text(
  text : String,
  base_url : String,
  model : String,
  api_key? : String? = None,
  opts~ : RewriteOptions,
) -> RewriteResult {
  let prompt = build_prompt(
    opts.strength,
    text,
    lang=opts.lang,
    original_lang=opts.original_lang,
  )
  let use_gumbel = opts.gumbel_key is Some(_)
  let n_cands = if opts.candidates > 1 { opts.candidates } else { 1 }
  let n_loops = if opts.max_loops > 1 { opts.max_loops } else { 1 }
  let attempts : Array[RewriteAttempt] = []
  let mut passed : Bool? = None
  for loop_index in 0..<n_loops {
    for _ in 0..<n_cands {
      let mut cand = call_openai_compatible(
        base_url,
        model,
        prompt,
        api_key~,
        temperature=opts.temperature,
      )
      if opts.layer_a_after {
        let (cleaned, _) = @clean.clean_text(cand)
        cand = cleaned
      }
      let divergence = lexical_divergence(text, cand)
      if use_gumbel {
        let report = @gumbel.detect_text(cand, opts.gumbel_key.unwrap())
        let verdict = !report.is_watermarked
        attempts.push({
          text: cand,
          loop_index,
          lexical_divergence: divergence,
          passed: Some(verdict),
          gumbel_score: Some(report.score),
          selected: false,
        })
        if verdict {
          passed = Some(true)
          break
        }
      } else {
        attempts.push({
          text: cand,
          loop_index,
          lexical_divergence: divergence,
          passed: None,
          gumbel_score: None,
          selected: false,
        })
      }
    }
    if passed is Some(true) {
      break
    }
  }
  if use_gumbel && passed is None {
    passed = Some(false)
  }
  // Selection: first passing attempt, else lowest gumbel score (detector
  // evaluator) or most diverged variant (fallback).
  let mut selected = -1
  if use_gumbel {
    let mut best_score = 1.7976931348623157e308
    for i in 0..<attempts.length() {
      let score = attempts[i].gumbel_score.unwrap_or(1.7976931348623157e308)
      let better = attempts[i].passed.unwrap_or(false) || score < best_score
      if better {
        best_score = score
        selected = i
      }
    }
  } else {
    let texts : Array[String] = []
    for a in attempts {
      texts.push(a.text)
    }
    let (best, _) = select_candidate(text, texts)
    selected = best
  }
  if selected >= 0 && selected < attempts.length() {
    attempts[selected].selected = true
  }
  let result_text = if selected >= 0 && selected < attempts.length() {
    attempts[selected].text
  } else {
    text
  }
  {
    text: result_text,
    info: {
      backend: "openai-compatible",
      model,
      base_url,
      strength: opts.strength,
      temperature: opts.temperature,
      prompt_chars: prompt.length(),
      input_chars: text.length(),
      evaluator: if use_gumbel {
        "gumbel"
      } else {
        "lexical-divergence"
      },
      attempts,
      passed,
    },
  }
}

///|
fn attempt_to_json(a : RewriteAttempt) -> Json {
  let obj : Map[String, Json] = Map([])
  obj.set("loop", Json::number(a.loop_index.to_double()))
  obj.set("lexical_divergence", Json::number(a.lexical_divergence))
  match a.passed {
    Some(v) => obj.set("passed", Json::boolean(v))
    None => obj.set("passed", Json::null())
  }
  match a.gumbel_score {
    Some(s) => obj.set("gumbel_score", Json::number(s))
    None => ()
  }
  obj.set("selected", Json::boolean(a.selected))
  obj.set("text", Json::string(a.text))
  Json::object(obj)
}

///|
pub fn info_to_json(info : RewriteInfo) -> Json {
  let root : Map[String, Json] = Map([])
  root.set("backend", Json::string(info.backend))
  root.set("model", Json::string(info.model))
  root.set("base_url", Json::string(info.base_url))
  root.set("strength", Json::string(info.strength))
  root.set("temperature", Json::number(info.temperature))
  root.set("prompt_chars", Json::number(info.prompt_chars.to_double()))
  root.set("input_chars", Json::number(info.input_chars.to_double()))
  root.set("evaluator", Json::string(info.evaluator))
  let arr : Array[Json] = []
  for a in info.attempts {
    arr.push(attempt_to_json(a))
  }
  root.set("attempts_made", Json::number(info.attempts.length().to_double()))
  root.set("attempts", Json::array(arr))
  match info.passed {
    Some(v) => root.set("passed", Json::boolean(v))
    None => root.set("passed", Json::null())
  }
  Json::object(root)
}
