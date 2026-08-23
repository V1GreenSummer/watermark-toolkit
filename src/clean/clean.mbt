//! Layer A: invisible Unicode / homoglyph-space detection and cleaning.
//!
//! Faithful port of watermarks-remover `text_unicode.py` (MIT). All indices are
//! codepoint indices, matching Python's `str` semantics: convert input to
//! `Array[Char]` once and index that array.

///|
priv enum Action {
  Keep
  Strip
  Replace
}

///|
priv struct Decision {
  action : Action
  out : String // surviving text fragment: the char for keep, "" for strip
  kind : String? // inspect classification; None = not suspicious
}

///|
pub struct CharHit {
  codepoint : Int
  label : String
  count : Int
  kind : String
  samples : Array[Int] // first 10 character offsets
}

///|
pub struct InspectReport {
  length : Int
  suspicious_total : Int
  hits : Array[CharHit]
  notes : Array[String]
}

///|
pub struct CleanStats {
  input_length : Int
  output_length : Int
  removed : Array[(String, Int)] // label -> count, label ascending
  replaced : Array[(String, Int)]
  removed_count : Int
  replaced_count : Int
}

// ---------------------------------------------------------------------------
// Codepoint predicates (ranges mirrored from text_unicode.py)
// ---------------------------------------------------------------------------

///|
fn is_vs_supplement(cp : Int) -> Bool {
  cp >= 0xE0100 && cp < 0xE01F0
}

///|
fn in_tag_range(cp : Int) -> Bool {
  cp >= 0xE0020 && cp < 0xE0080
}

///|
fn is_reserved_ignorable(cp : Int) -> Bool {
  cp == 0x2065 ||
  cp == 0xE0000 ||
  (cp >= 0xFFF0 && cp < 0xFFF9) ||
  (cp >= 0xE0080 && cp < 0xE0100) ||
  (cp >= 0xE01F0 && cp < 0xE1000)
}

///|
fn is_strip_cp(cp : Int) -> Bool {
  @uc.is_strip_explicit(cp) ||
  is_vs_supplement(cp) ||
  (cp >= 0xE0001 && cp <= 0xE007F) ||
  @uc.is_noncharacter(cp) ||
  is_reserved_ignorable(cp) ||
  @uc.is_private_use(cp)
}

///|
fn strip_kind(cp : Int) -> String {
  if cp >= 0xE0001 && cp <= 0xE007F {
    return "tag_chars"
  }
  if @uc.is_noncharacter(cp) {
    return "noncharacter"
  }
  if is_reserved_ignorable(cp) {
    return "reserved_ignorable"
  }
  if is_vs_supplement(cp) ||
    (cp >= 0xFE00 && cp <= 0xFE0F) ||
    @uc.is_mongolian_fvs(cp) {
    return "variation_selector"
  }
  if @uc.is_bidi(cp) {
    return "bidi"
  }
  if @uc.is_zw_family(cp) {
    return "zwj_family"
  }
  if @uc.is_private_use(cp) {
    return "private_use"
  }
  "strip"
}

///|
fn is_cjk_ideograph(cp : Int) -> Bool {
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0xF900 && cp <= 0xFAFF) ||
  (cp >= 0x20000 && cp <= 0x323AF)
}

///|
fn is_mongolian_base(cp : Int) -> Bool {
  cp >= 0x1800 && cp <= 0x18AF
}

///|
fn is_khmer_letter(cp : Int) -> Bool {
  cp >= 0x1780 && cp <= 0x17FF && @uc.is_script_letter(cp)
}

///|
fn is_mongolian_letter(cp : Int) -> Bool {
  cp >= 0x1800 && cp <= 0x18AF && @uc.is_script_letter(cp)
}

///|
fn is_hangul_jamo(cp : Int) -> Bool {
  (cp >= 0x1100 && cp <= 0x11FF) ||
  (cp >= 0xA960 && cp <= 0xA97C) ||
  (cp >= 0xD7B0 && cp <= 0xD7C6) ||
  (cp >= 0x3131 && cp <= 0x318E) ||
  (cp >= 0xFFA1 && cp <= 0xFFDC)
}

///|
fn is_variation_selector(cp : Int) -> Bool {
  is_vs_supplement(cp) ||
  (cp >= 0xFE00 && cp <= 0xFE0F) ||
  @uc.is_mongolian_fvs(cp)
}

///|
fn is_emoji_base(cp : Int) -> Bool {
  if cp >= 0x1F000 && cp <= 0x1FAFF {
    return true
  }
  if cp >= 0x2190 && cp <= 0x25FF {
    return true
  }
  if cp >= 0x2600 && cp <= 0x27BF {
    return true
  }
  if cp >= 0x2B00 && cp <= 0x2BFF {
    return true
  }
  if cp == 0x00A9 ||
    cp == 0x00AE ||
    cp == 0x2122 ||
    cp == 0x3030 ||
    cp == 0x303D ||
    cp == 0x3297 ||
    cp == 0x3299 {
    return true
  }
  cp == 0x0023 || cp == 0x002A || (cp >= 0x0030 && cp <= 0x0039)
}

///|
/// Load-bearing invisible char: emoji glue, script joiner, flag tag char, or
/// same-script filler/selector.
fn is_glue(cp : Int) -> Bool {
  @uc.is_emoji_glue(cp) ||
  is_variation_selector(cp) ||
  @uc.is_script_joiner(cp) ||
  in_tag_range(cp) ||
  @uc.is_mongolian_fvs(cp) ||
  @uc.is_khmer_vowel(cp) ||
  @uc.is_hangul_filler(cp)
}

// ---------------------------------------------------------------------------
// Sequence-level structure: complete flag tag runs and paired bidi embeddings
// ---------------------------------------------------------------------------

///|
fn valid_flag_tag_indices(chars : Array[Char]) -> Map[Int, Bool] {
  let valid : Map[Int, Bool] = Map([])
  let mut i = 0
  while i < chars.length() {
    if chars[i].to_int() != 0x1F3F4 {
      i = i + 1
      continue
    }
    let mut j = i + 1
    while j < chars.length() &&
          chars[j].to_int() >= 0xE0020 &&
          chars[j].to_int() <= 0xE007E {
      j = j + 1
    }
    if j > i + 1 && j < chars.length() && chars[j].to_int() == 0xE007F {
      for k in (i + 1)..<=j {
        valid.set(k, true)
      }
      i = j + 1
    } else {
      i = i + 1
    }
  }
  valid
}

///|
fn valid_bidi_embedding_indices(chars : Array[Char]) -> Map[Int, Bool] {
  let valid : Map[Int, Bool] = Map([])
  let stack : Array[(Int, Int)] = [] // (opener cp, opener index)
  for i in 0..<chars.length() {
    let cp = chars[i].to_int()
    if cp == 0x202A || cp == 0x202B || cp == 0x202D || cp == 0x202E {
      stack.push((cp, i))
    } else if cp == 0x202C {
      if stack.length() == 0 {
        continue
      }
      let (opener, opener_index) = stack.pop().unwrap()
      if opener == 0x202A || opener == 0x202B {
        valid.set(opener_index, true)
        valid.set(i, true)
      }
    }
  }
  valid
}

// ---------------------------------------------------------------------------
// Per-character decision
// ---------------------------------------------------------------------------

///|
fn decide(
  ch : Char,
  prev_kept : Char?,
  prev_input : Char?,
  next_input : Char?,
  valid_flag_tag~ : Bool,
  valid_bidi_embedding~ : Bool,
  normalize_spaces~ : Bool,
  treat_confusables~ : Bool,
  strip_emoji_glue~ : Bool,
  strip_bidi~ : Bool,
) -> Decision {
  let cp = ch.to_int()
  if valid_bidi_embedding && !strip_bidi {
    return { action: Keep, out: ch.to_string(), kind: None }
  }
  if @uc.is_preservable_bidi(cp) && !strip_bidi {
    return { action: Keep, out: ch.to_string(), kind: None }
  }
  if prev_input is Some(p) && !strip_emoji_glue {
    let prev_cp = p.to_int()
    if is_vs_supplement(cp) && is_cjk_ideograph(prev_cp) {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
    if @uc.is_mongolian_fvs(cp) && is_mongolian_base(prev_cp) {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
    if cp >= 0xFE00 && cp <= 0xFE0D && is_cjk_ideograph(prev_cp) {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
  }
  if @uc.is_emoji_glue(cp) && !strip_emoji_glue {
    if (cp == 0xFE0E || cp == 0xFE0F) &&
      prev_input is Some(p) &&
      is_emoji_base(p.to_int()) {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
    if cp == 0x200D && prev_kept is Some(pk) && next_input is Some(n) {
      if is_emoji_base(pk.to_int()) && is_emoji_base(n.to_int()) {
        return { action: Keep, out: ch.to_string(), kind: None }
      }
    }
  }
  if !strip_emoji_glue {
    if @uc.is_script_joiner(cp) &&
      prev_input is Some(p) &&
      next_input is Some(n) {
      let prev_script = @uc.joining_script(p.to_int())
      let next_script = @uc.joining_script(n.to_int())
      if prev_script is Some(ps) && next_script is Some(ns) && ps == ns {
        return { action: Keep, out: ch.to_string(), kind: None }
      }
    }
    if in_tag_range(cp) && valid_flag_tag {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
    if @uc.is_mongolian_fvs(cp) &&
      prev_kept is Some(pk) &&
      is_mongolian_letter(pk.to_int()) {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
    if @uc.is_khmer_vowel(cp) &&
      prev_kept is Some(pk) &&
      is_khmer_letter(pk.to_int()) {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
    if @uc.is_hangul_filler(cp) &&
      prev_kept is Some(pk) &&
      is_hangul_jamo(pk.to_int()) {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
    if @uc.is_orthographic_cf(cp) {
      return { action: Keep, out: ch.to_string(), kind: None }
    }
    match @uc.layout_cf_script(cp) {
      Some((s_lo, s_hi)) => {
        let prev_in = prev_input is Some(p) &&
          p.to_int() >= s_lo &&
          p.to_int() <= s_hi
        let next_in = next_input is Some(n) &&
          n.to_int() >= s_lo &&
          n.to_int() <= s_hi
        if prev_in || next_in {
          return { action: Keep, out: ch.to_string(), kind: None }
        }
      }
      None => ()
    }
  }
  if is_strip_cp(cp) {
    return { action: Strip, out: "", kind: Some(strip_kind(cp)) }
  }
  if normalize_spaces {
    match @uc.space_replacement(cp) {
      Some(replacement) =>
        return { action: Replace, out: replacement, kind: Some("space") }
      None => ()
    }
  }
  if treat_confusables {
    match @uc.latin_confusable_replacement(cp) {
      Some(replacement) =>
        return { action: Replace, out: replacement, kind: Some("confusable") }
      None => ()
    }
  }
  if @uc.is_format(cp) && !@uc.in_space_homoglyphs(cp) {
    return { action: Strip, out: "", kind: Some("other_cf") }
  }
  { action: Keep, out: ch.to_string(), kind: None }
}

// ---------------------------------------------------------------------------
// Clean and inspect
// ---------------------------------------------------------------------------

///|
fn counter_add(counter : Map[String, Int], key : String) -> Unit {
  counter.set(key, counter.get(key).unwrap_or(0) + 1)
}

///|
fn counter_entries(counter : Map[String, Int]) -> Array[(String, Int)] {
  let entries : Array[(String, Int)] = []
  counter.each(fn(k, v) { entries.push((k, v)) })
  entries.sort_by(fn(a, b) { String::lexical_compare(a.0, b.0) })
  entries
}

///|
/// Return cleaned text and stats. NFKC post-normalization is not supported
/// (the Python flag defaults to off).
///
/// # Example
/// ```mbt check
/// test {
///   let (out, stats) = clean_text("a\u{200B}b\u{00A0}c")
///   inspect(out, content="ab c")
///   inspect(stats.removed_count, content="1")
///   inspect(stats.replaced_count, content="1")
/// }
/// ```
pub fn clean_text(
  text : String,
  normalize_spaces? : Bool = true,
  aggressive_homoglyphs? : Bool = false,
  strip_emoji_glue? : Bool = false,
  strip_bidi? : Bool = false,
) -> (String, CleanStats) {
  let chars = text.to_array()
  let removed : Map[String, Int] = Map([])
  let replaced : Map[String, Int] = Map([])
  let out : Array[Char] = []
  let mut prev_kept : Char? = None
  let flag_tags = valid_flag_tag_indices(chars)
  let bidi_embeddings = valid_bidi_embedding_indices(chars)
  for i, ch in chars {
    let d = decide(
      ch,
      prev_kept,
      if i > 0 {
        Some(chars[i - 1])
      } else {
        None
      },
      if i + 1 < chars.length() {
        Some(chars[i + 1])
      } else {
        None
      },
      valid_flag_tag=flag_tags.get(i).unwrap_or(false),
      valid_bidi_embedding=bidi_embeddings.get(i).unwrap_or(false),
      normalize_spaces~,
      treat_confusables=aggressive_homoglyphs,
      strip_emoji_glue~,
      strip_bidi~,
    )
    match d.action {
      Keep => {
        out.push(ch)
        // Glue does not advance the "previous kept" base so ZWJ chains and
        // flag runs stay bound.
        if !is_glue(ch.to_int()) {
          prev_kept = Some(ch)
        }
      }
      Replace => {
        for c in d.out {
          out.push(c)
        }
        counter_add(replaced, @uc.char_label(ch.to_int()))
        prev_kept = Some(d.out.to_array()[0])
      }
      Strip => counter_add(removed, @uc.char_label(ch.to_int()))
      // prev_kept unchanged
    }
  }
  let removed_entries = counter_entries(removed)
  let replaced_entries = counter_entries(replaced)
  let removed_count = removed_entries.fold(init=0, fn(acc, entry) {
    acc + entry.1
  })
  let replaced_count = replaced_entries.fold(init=0, fn(acc, entry) {
    acc + entry.1
  })
  (
    String::from_array(out),
    {
      input_length: chars.length(),
      output_length: out.length(),
      removed: removed_entries,
      replaced: replaced_entries,
      removed_count,
      replaced_count,
    },
  )
}

///|
fn hit_confidence(kind : String) -> String {
  if kind == "space" {
    "informational"
  } else {
    "probable"
  }
}

///|
let inspect_base_notes : Array[String] = [
  "Layer A only: invisible/format Unicode and space homoglyphs (edit-based carriers).",
  "Statistical (token-sampling) watermarks are not detectable here; use Layer B rewrite.",
  "Inspect kinds: strip, bidi, tag_chars, variation_selector, zwj_family, private_use, space, confusable, other_cf.",
  "Load-bearing invisibles are preserved by default during cleaning: emoji glue, CJK/Mongolian variation selectors, script joiners, complete flag tag sequences, same-script fillers/selectors (Mongolian FVS, Khmer inherent vowels, Hangul jamo fillers), RTL directional marks/paired embeddings, orthographic Arabic/Syriac Cf marks, and visible-layout format controls next to their own script (Egyptian hieroglyph quadrat, Duployan shorthand, musical beaming). Inspection still reports bidi controls. Use explicit strip flags only after review.",
]

///|
pub fn inspect_text(
  text : String,
  aggressive? : Bool = false,
  strip_emoji_glue? : Bool = false,
) -> InspectReport {
  let chars = text.to_array()
  let buckets : Map[Int, Array[Int]] = Map([]) // cp -> offsets (one kind per cp)
  let kinds : Map[Int, String] = Map([])
  let mut prev_kept : Char? = None
  let flag_tags = valid_flag_tag_indices(chars)
  let bidi_embeddings = valid_bidi_embedding_indices(chars)
  for i, ch in chars {
    let d = decide(
      ch,
      prev_kept,
      if i > 0 {
        Some(chars[i - 1])
      } else {
        None
      },
      if i + 1 < chars.length() {
        Some(chars[i + 1])
      } else {
        None
      },
      valid_flag_tag=flag_tags.get(i).unwrap_or(false),
      valid_bidi_embedding=bidi_embeddings.get(i).unwrap_or(false),
      normalize_spaces=true,
      treat_confusables=aggressive,
      strip_emoji_glue~,
      strip_bidi=true,
    )
    match d.kind {
      None => if !is_glue(ch.to_int()) { prev_kept = Some(ch) }
      Some(kind) => {
        let cp = ch.to_int()
        match buckets.get(cp) {
          Some(offsets) => offsets.push(i)
          None => {
            buckets.set(cp, [i])
            kinds.set(cp, kind)
          }
        }
        if d.action is Replace {
          prev_kept = Some(d.out.to_array()[0])
        }
      }
    }
  }
  let hits : Array[CharHit] = []
  let mut total = 0
  buckets.each(fn(cp, offsets) {
    hits.push({
      codepoint: cp,
      label: @uc.char_label(cp),
      count: offsets.length(),
      kind: kinds.get(cp).unwrap(),
      samples: offsets.copy(),
    })
    total = total + offsets.length()
  })
  hits.sort_by(fn(a, b) {
    if a.count != b.count {
      b.count - a.count
    } else {
      a.codepoint - b.codepoint
    }
  })
  let notes : Array[String] = inspect_base_notes.copy()
  if hits.length() == 0 {
    notes.push(
      "No deterministic Layer A (invisible Unicode/format) carriers detected; statistical and pixel-domain marks are out of scope here.",
    )
  }
  { length: chars.length(), suspicious_total: total, hits, notes }
}

// ---------------------------------------------------------------------------
// JSON rendering (shape matches the Python CLI's report dicts)
// ---------------------------------------------------------------------------

///|
fn offsets_json(offsets : Array[Int], limit : Int) -> Json {
  let n = if offsets.length() < limit { offsets.length() } else { limit }
  let items : Array[Json] = []
  for i in 0..<n {
    items.push(Json::number(offsets[i].to_double()))
  }
  Json::array(items)
}

///|
pub fn report_to_json(report : InspectReport) -> Json {
  let hits : Array[Json] = []
  for hit in report.hits {
    let obj : Map[String, Json] = Map([])
    obj.set("codepoint", Json::string(@uc.char_codepoint_hex(hit.codepoint)))
    obj.set("label", Json::string(hit.label))
    obj.set("count", Json::number(hit.count.to_double()))
    obj.set("kind", Json::string(hit.kind))
    obj.set("confidence", Json::string(hit_confidence(hit.kind)))
    obj.set("sample_offsets", offsets_json(hit.samples, 10))
    hits.push(Json::object(obj))
  }
  let notes : Array[Json] = []
  for note in report.notes {
    notes.push(Json::string(note))
  }
  let root : Map[String, Json] = Map([])
  root.set("length", Json::number(report.length.to_double()))
  root.set(
    "suspicious_total",
    Json::number(report.suspicious_total.to_double()),
  )
  root.set("hits", Json::array(hits))
  root.set("notes", Json::array(notes))
  Json::object(root)
}

///|
pub fn stats_to_json(stats : CleanStats) -> Json {
  fn entries_json(entries : Array[(String, Int)]) -> Json {
    let obj : Map[String, Json] = Map([])
    for entry in entries {
      obj.set(entry.0, Json::number(entry.1.to_double()))
    }
    Json::object(obj)
  }
  let root : Map[String, Json] = Map([])
  root.set("input_length", Json::number(stats.input_length.to_double()))
  root.set("output_length", Json::number(stats.output_length.to_double()))
  root.set("removed", entries_json(stats.removed))
  root.set("replaced", entries_json(stats.replaced))
  root.set("removed_count", Json::number(stats.removed_count.to_double()))
  root.set("replaced_count", Json::number(stats.replaced_count.to_double()))
  root.set("nfkc_changed", Json::boolean(false))
  Json::object(root)
}

///|
pub fn human_report(report : InspectReport) -> String {
  let lines : Array[String] = []
  lines.push("Length: \{report.length} chars")
  lines.push("Suspicious: \{report.suspicious_total}")
  if report.hits.length() > 0 {
    lines.push("Hits:")
    for hit in report.hits {
      let mut samples = ""
      for
        i in 0..<(if hit.samples.length() < 5 {
          hit.samples.length()
        } else {
          5
        }) {
        if i > 0 {
          samples = samples + ", "
        }
        samples = samples + hit.samples[i].to_string()
      }
      lines.push(
        "  [\{hit.kind}/\{hit_confidence(hit.kind)}] \{hit.label} x\{hit.count} @ \{samples}",
      )
    }
  }
  for note in report.notes {
    lines.push("Note: \{note}")
  }
  lines.join("\n")
}
