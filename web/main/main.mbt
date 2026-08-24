//! WASM export layer for the browser playground. Each export takes and
//! returns JSON strings so the JS side never touches MoonBit values.

///|
fn parse_args(args_json : String) -> Json {
  @json5.parse(args_json) catch {
    _ => Json::empty_object()
  }
}

///|
fn parse_bool(flags_json : Json, key : String) -> Bool {
  match flags_json {
    Object(obj) =>
      match obj.get(key) {
        Some(True) => true
        _ => false
      }
    _ => false
  }
}

///|
fn parse_number(flags_json : Json, key : String, default : Double) -> Double {
  match flags_json {
    Object(obj) =>
      match obj.get(key) {
        Some(Number(v, ..)) => v
        _ => default
      }
    _ => default
  }
}

///|
fn parse_int(flags_json : Json, key : String, default : Int) -> Int {
  parse_number(flags_json, key, default.to_double()).to_int()
}

///|
/// Layer A inspection: in { text, aggressive, stripEmojiGlue },
/// out the inspect report JSON.
#export_name("inspect_text")
pub fn inspect_text(args_json : String) -> String {
  let args = parse_args(args_json)
  let text = match args {
    Object(obj) =>
      match obj.get("text") {
        Some(String(t)) => t
        _ => ""
      }
    _ => ""
  }
  @clean.report_to_json(
    @clean.inspect_text(
      text,
      aggressive=parse_bool(args, "aggressive"),
      strip_emoji_glue=parse_bool(args, "stripEmojiGlue"),
    ),
  ).stringify()
}

///|
/// Layer A cleaning: in { text, normalizeSpaces, aggressiveHomoglyphs,
/// stripEmojiGlue, stripBidi }, out { output, stats } JSON.
#export_name("clean_text")
pub fn clean_text(args_json : String) -> String {
  let args = parse_args(args_json)
  let text = match args {
    Object(obj) =>
      match obj.get("text") {
        Some(String(t)) => t
        _ => ""
      }
    _ => ""
  }
  let (output, stats) = @clean.clean_text(
    text,
    normalize_spaces=parse_bool(args, "normalizeSpaces"),
    aggressive_homoglyphs=parse_bool(args, "aggressiveHomoglyphs"),
    strip_emoji_glue=parse_bool(args, "stripEmojiGlue"),
    strip_bidi=parse_bool(args, "stripBidi"),
  )
  let root : Map[String, Json] = Map([])
  root.set("output", Json::string(output))
  root.set("stats", @clean.stats_to_json(stats))
  Json::object(root).stringify()
}

///|
/// keyed-Gumbel detection: in { text, key, window, threshold },
/// out the detector report JSON.
#export_name("detect_text")
pub fn detect_text(args_json : String) -> String {
  let args = parse_args(args_json)
  let text = match args {
    Object(obj) =>
      match obj.get("text") {
        Some(String(t)) => t
        _ => ""
      }
    _ => ""
  }
  let key = match args {
    Object(obj) =>
      match obj.get("key") {
        Some(k) =>
          match k {
            String(s) => s
            _ => ""
          }
        None => ""
      }
    _ => ""
  }
  let report = @gumbel.detect_text(
    text,
    key,
    window=parse_int(args, "window", 4),
    threshold=parse_number(args, "threshold", 0.000001),
  )
  @gumbel.report_to_json(report).stringify()
}
