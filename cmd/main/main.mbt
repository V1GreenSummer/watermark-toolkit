//! CLI entry: clean / inspect / detect subcommands over the ported layers.

///|
fn read_input(path : String) -> String raise {
  @fs.read_file_to_string(path)
}

///|
fn write_output(path : String, content : String) -> Unit raise {
  @fs.write_string_to_file(path, content)
}

///|
fn run_clean(m : @argparse.Matches) -> Unit raise {
  let path = m.values.get("input").unwrap()[0]
  let text = read_input(path)
  let (cleaned, stats) = @clean.clean_text(
    text,
    normalize_spaces=!m.flags.get("no-normalize-spaces").unwrap_or(false),
    aggressive_homoglyphs=m.flags.get("aggressive-homoglyphs").unwrap_or(false),
    strip_emoji_glue=m.flags.get("strip-emoji-glue").unwrap_or(false),
    strip_bidi=m.flags.get("strip-bidi").unwrap_or(false),
  )
  match m.values.get("output") {
    Some(out) => write_output(out[0], cleaned)
    None => println(cleaned)
  }
  if m.flags.get("json").unwrap_or(false) {
    println(@clean.stats_to_json(stats).stringify(indent=2))
  } else {
    println(
      "removed=\{stats.removed_count} replaced=\{stats.replaced_count} len \{stats.input_length}->\{stats.output_length}",
    )
  }
}

///|
fn run_inspect(m : @argparse.Matches) -> Unit raise {
  let path = m.values.get("input").unwrap()[0]
  let text = read_input(path)
  let report = @clean.inspect_text(
    text,
    aggressive=m.flags.get("aggressive").unwrap_or(false),
    strip_emoji_glue=m.flags.get("strip-emoji-glue").unwrap_or(false),
  )
  if m.flags.get("json").unwrap_or(false) {
    println(@clean.report_to_json(report).stringify(indent=2))
  } else {
    println(@clean.human_report(report))
  }
}

///|
fn parse_token_ids(raw : String) -> Array[UInt64] raise {
  // JSON array of integers, or one integer per line
  let ids : Array[UInt64] = []
  let trimmed = raw
  if trimmed.has_prefix("[") {
    // minimal JSON array scan: digits, commas, whitespace
    let mut current = ""
    for ch in trimmed {
      let cp = ch.to_int()
      if (cp >= 0x30 && cp <= 0x39) || ch == 'e' || ch == 'E' {
        current = current + ch.to_string()
      } else if current != "" {
        ids.push(@string.parse_uint64(current))
        current = ""
      }
    }
    if current != "" {
      ids.push(@string.parse_uint64(current))
    }
  } else {
    for line in trimmed.split("\n") {
      let mut l = line.to_owned()
      while l.length() > 0 && (l[0] == 32 || l[0] == 9 || l[0] == 13) {
        l = l.sub(start=1).to_owned()
      }
      while l.length() > 0 &&
            (
              l[l.length() - 1] == 32 ||
              l[l.length() - 1] == 9 ||
              l[l.length() - 1] == 13
            ) {
        l = l.sub(end=l.length() - 1).to_owned()
      }
      if l != "" {
        ids.push(@string.parse_uint64(l))
      }
    }
  }
  ids
}

///|
fn run_detect(m : @argparse.Matches) -> Unit raise {
  let key = m.values.get("key").unwrap()[0]
  let path = m.values.get("input").unwrap()[0]
  let raw = read_input(path)
  let window = @string.parse_int(m.values.get("window").unwrap()[0])
  let threshold = @string.parse_double(m.values.get("threshold").unwrap()[0])
  let report = if m.flags.get("tokens").unwrap_or(false) {
    @gumbel.detect_token_ids(parse_token_ids(raw), key, window~, threshold~)
  } else {
    @gumbel.detect_text(raw, key, window~, threshold~)
  }
  if m.flags.get("json").unwrap_or(false) {
    println(@gumbel.report_to_json(report).stringify(indent=2))
  } else {
    println(
      "keyed-Gumbel (EXP) detection: watermarked=\{report.is_watermarked} p=\{report.p_value} (threshold \{report.threshold}) counted=\{report.counted})/\{report.tokens_total} tokens, skipped \{report.skipped_no_context + report.skipped_repeated} (no-context \{report.skipped_no_context}, repeated-window \{report.skipped_repeated})",
    )
    println("note: \{report.note}")
  }
}

///|
async fn run_rewrite(m : @argparse.Matches) -> Unit {
  let path = m.values.get("input").unwrap()[0]
  let text = read_input(path)
  let strength = m.values.get("strength").unwrap()[0]
  if m.flags.get("print-prompt").unwrap_or(false) {
    println(@rewrite.build_prompt(strength, text))
    return
  }
  let model = m.values.get("model").unwrap()[0]
  let base_url = m.values.get("base-url").unwrap()[0]
  @rewrite.check_remote(
    base_url,
    allow_remote=m.flags.get("allow-remote").unwrap_or(false),
  )
  let api_key = match m.values.get("api-key") {
    Some(arr) if arr.length() > 0 => Some(arr[0])
    _ => None
  }
  let gumbel_key = match m.values.get("gumbel-key") {
    Some(arr) if arr.length() > 0 => Some(arr[0])
    _ => None
  }
  let candidates = @string.parse_int(m.values.get("candidates").unwrap()[0])
  let max_loops = @string.parse_int(m.values.get("max-loops").unwrap()[0])
  let temperature = @string.parse_double(
    m.values.get("temperature").unwrap()[0],
  )
  let opts : @rewrite.RewriteOptions = {
    strength,
    lang: "English",
    original_lang: "English",
    temperature,
    candidates,
    max_loops,
    layer_a_after: m.flags.get("layer-a-after").unwrap_or(false),
    gumbel_key,
  }
  let result = @rewrite.rewrite_text(text, base_url, model, api_key~, opts~)
  println(result.text)
  if m.flags.get("json").unwrap_or(false) {
    println(@rewrite.info_to_json(result.info).stringify(indent=2))
  }
}

///|
fn build_parser() -> @argparse.Command {
  Command(
    "wmtool",
    about="LLM text watermark Layer A cleaning and keyed-Gumbel detection (MoonBit port of watermarks-remover)",
    version="0.1.0",
    subcommands=[
      Command(
        "clean",
        about="Strip invisible Unicode / normalize space homoglyphs (Layer A)",
        positionals=[PositionArg("input", about="Input text file")],
        options=[
          OptionArg(
            "output",
            short='o',
            long="output",
            about="Output path (default: stdout)",
          ),
        ],
        flags=[
          FlagArg(
            "json",
            long="json",
            about="Print stats JSON after the cleaned text",
          ),
          FlagArg(
            "no-normalize-spaces",
            long="no-normalize-spaces",
            about="Do not rewrite exotic spaces to U+0020",
          ),
          FlagArg(
            "aggressive-homoglyphs",
            long="aggressive-homoglyphs",
            about="Map Cyrillic/fullwidth Latin confusables to ASCII",
          ),
          FlagArg(
            "strip-emoji-glue",
            long="strip-emoji-glue",
            about="Paranoid: strip load-bearing invisibles too",
          ),
          FlagArg(
            "strip-bidi",
            long="strip-bidi",
            about="Also strip legitimate RTL/LTR marks and isolates",
          ),
        ],
      ),
      Command(
        "inspect",
        about="Report suspicious invisible Unicode carriers (Layer A)",
        positionals=[PositionArg("input", about="Input text file")],
        flags=[
          FlagArg("json", long="json", about="Emit the report as JSON"),
          FlagArg(
            "aggressive",
            long="aggressive",
            about="Also flag Latin confusables",
          ),
          FlagArg(
            "strip-emoji-glue",
            long="strip-emoji-glue",
            about="Classify load-bearing invisibles as suspicious",
          ),
        ],
      ),
      Command(
        "rewrite",
        about="LLM rewrite loop (Layer B, best-effort; loopback endpoints only unless --allow-remote)",
        positionals=[PositionArg("input", about="Input text file")],
        options=[
          OptionArg("model", long="model", about="OpenAI-compatible model id"),
          OptionArg(
            "base-url",
            long="base-url",
            about="API root incl. version prefix (default: local ollama)",
            default_values=["http://127.0.0.1:11434/v1"],
          ),
          OptionArg(
            "api-key",
            long="api-key",
            about="Bearer key; default: $OPENAI_API_KEY",
            env="OPENAI_API_KEY",
          ),
          OptionArg(
            "strength",
            long="strength",
            about="paraphrase | humanize | code | backtranslate | structural",
            default_values=["paraphrase"],
          ),
          OptionArg(
            "gumbel-key",
            long="gumbel-key",
            about="Keyed-Gumbel key to guide the loop (same-key replay only)",
          ),
          OptionArg(
            "candidates",
            long="candidates",
            about="Candidates per loop (default: 1)",
            default_values=["1"],
          ),
          OptionArg(
            "max-loops",
            long="max-loops",
            about="Evaluation rounds cap (default: 1)",
            default_values=["1"],
          ),
          OptionArg(
            "temperature",
            long="temperature",
            about="Sampling temperature (default: 1.0)",
            default_values=["1.0"],
          ),
        ],
        flags=[
          FlagArg(
            "layer-a-after",
            long="layer-a-after",
            about="Layer-A clean each candidate",
          ),
          FlagArg(
            "allow-remote",
            long="allow-remote",
            about="Permit non-loopback endpoints",
          ),
          FlagArg(
            "print-prompt",
            long="print-prompt",
            about="Print the built prompt instead of calling an API",
          ),
          FlagArg(
            "json",
            long="json",
            about="Print loop report JSON after the rewritten text",
          ),
        ],
      ),
      Command(
        "detect",
        about="Keyed-Gumbel (EXP) watermark replay detection",
        positionals=[
          PositionArg(
            "input",
            about="Input text file (or token ids with --tokens)",
          ),
        ],
        options=[
          OptionArg(
            "key",
            long="key",
            about="Watermark key (0x<hex> or string); default: $WATERMARKS_GUMBEL_KEY",
            env="WATERMARKS_GUMBEL_KEY",
          ),
          OptionArg(
            "window",
            long="window",
            about="Context window size H (default: 4)",
            default_values=["4"],
          ),
          OptionArg(
            "threshold",
            long="threshold",
            about="p-value threshold (default: 1e-6)",
            default_values=["0.000001"],
          ),
        ],
        flags=[
          FlagArg(
            "tokens",
            long="tokens",
            about="Treat input as token ids (JSON array or one per line)",
          ),
          FlagArg("json", long="json", about="Emit the report as JSON"),
        ],
      ),
    ],
    subcommand_required=true,
  )
}

///|
async fn main {
  let parser = build_parser()
  try {
    let matches = parser.parse()
    match matches.subcommand {
      Some((name, m)) =>
        match name {
          "clean" => run_clean(m)
          "inspect" => run_inspect(m)
          "detect" => run_detect(m)
          "rewrite" => run_rewrite(m)
          _ => println(parser.render_help())
        }
      None => println(parser.render_help())
    }
  } catch {
    e => println("error: \{e}")
  }
}
