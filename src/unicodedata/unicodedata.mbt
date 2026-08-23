//! Unicode data lookups backing the Layer A port.
//!
//! The tables in `tables.mbt` are generated from CPython's `unicodedata` by
//! `tools/gen_unicode_tables.py`; this file only provides lookup functions.
//! Unnamed codepoints (private-use, noncharacters, reserved ignorables) are
//! synthesized as "UNKNOWN (Co|Cn)" so labels match Python's
//! `unicodedata.name(ch, "UNKNOWN")` fallback exactly.

///|
fn ranges_contain(ranges : Array[(Int, Int)], cp : Int) -> Bool {
  let mut lo = 0
  let mut hi = ranges.length() - 1
  while lo <= hi {
    let mid = (lo + hi) >> 1
    let (start, end) = ranges[mid]
    if cp < start {
      hi = mid - 1
    } else if cp > end {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
fn label_of(cp : Int) -> String? {
  let pairs = label_pairs
  let mut lo = 0
  let mut hi = pairs.length() - 1
  while lo <= hi {
    let mid = (lo + hi) >> 1
    let (key, text) = pairs[mid]
    if cp < key {
      hi = mid - 1
    } else if cp > key {
      lo = mid + 1
    } else {
      return Some(text)
    }
  }
  None
}

///|
let hex_digits : Array[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
]

///|
fn hex_upper(n0 : Int) -> String {
  let mut n = n0
  let rev : Array[Char] = []
  if n == 0 {
    rev.push('0')
  }
  while n > 0 {
    rev.push(hex_digits[n % 16])
    n = n / 16
  }
  String::from_iter(rev.rev_iter())
}

///|
pub fn char_codepoint_hex(cp : Int) -> String {
  let h = hex_upper(cp)
  let pad = if h.length() >= 4 { 0 } else { 4 - h.length() }
  "U+" + String::make(pad, '0') + h
}

///|
/// Format category (format, Cf) membership over the whole codespace.
pub fn is_format(cp : Int) -> Bool {
  ranges_contain(cf_ranges, cp)
}

///|
/// Any L* category inside the five script groups used by `_joining_script`,
/// `_is_mongolian_letter`, and `_is_khmer_letter`.
pub fn is_script_letter(cp : Int) -> Bool {
  ranges_contain(script_letter_ranges, cp)
}

///|
/// Any L* or M* category inside the same script groups.
fn is_script_letter_or_mark(cp : Int) -> Bool {
  ranges_contain(script_letter_ranges, cp) ||
  ranges_contain(script_mark_ranges, cp)
}

///|
/// BMP and supplementary private-use planes.
pub fn is_private_use(cp : Int) -> Bool {
  (cp >= 0xE000 && cp <= 0xF8FF) ||
  (cp >= 0xF0000 && cp <= 0xFFFFD) ||
  (cp >= 0x100000 && cp <= 0x10FFFD)
}

///|
/// The 66 Unicode noncharacters: U+FDD0..U+FDEF and U+nFFFE/U+nFFFF per plane.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(is_noncharacter(0xFDD0), content="true")
///   inspect(is_noncharacter(0xFFFF), content="true")
///   inspect(is_noncharacter(0x10FFFE), content="true")
///   inspect(is_noncharacter('a'.to_int()), content="false")
/// }
/// ```
pub fn is_noncharacter(cp : Int) -> Bool {
  (cp >= 0xFDD0 && cp <= 0xFDEF) || (cp & 0xFFFE) == 0xFFFE
}

///|
fn script_group_range(cp : Int) -> String? {
  if cp >= 0x0600 && cp <= 0x08FF {
    Some("arabic")
  } else if cp >= 0x0900 && cp <= 0x0DFF {
    Some("indic")
  } else if cp >= 0x0F00 && cp <= 0x109F {
    Some("south-asian")
  } else if cp >= 0x1780 && cp <= 0x17FF {
    Some("khmer")
  } else if cp >= 0x1800 && cp <= 0x18AF {
    Some("mongolian")
  } else {
    None
  }
}

///|
/// Broad script group where ZWJ/ZWNJ can be orthographic, else None.
pub fn joining_script(cp : Int) -> String? {
  match script_group_range(cp) {
    Some(name) => if is_script_letter_or_mark(cp) { Some(name) } else { None }
    None => None
  }
}

///|
/// "U+XXXX NAME (CAT)" for hit codepoints; unnamed ones fall back like Python.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(char_label(0x200B), content="U+200B ZERO WIDTH SPACE (Cf)")
///   inspect(char_label(0xE000), content="U+E000 UNKNOWN (Co)")
/// }
/// ```
pub fn char_label(cp : Int) -> String {
  match label_of(cp) {
    Some(text) => text
    None => {
      let cat = if is_private_use(cp) { "Co" } else { "Cn" }
      char_codepoint_hex(cp) + " UNKNOWN (" + cat + ")"
    }
  }
}

///|
/// Explicitly enumerated strip-class codepoints (text_unicode STRIP_CODEPOINTS).
pub fn is_strip_explicit(cp : Int) -> Bool {
  ranges_contain(strip_cps, cp)
}

///|
fn cp_map_lookup(pairs : Array[(Int, String)], cp : Int) -> String? {
  let mut lo = 0
  let mut hi = pairs.length() - 1
  while lo <= hi {
    let mid = (lo + hi) >> 1
    let (key, text) = pairs[mid]
    if cp < key {
      hi = mid - 1
    } else if cp > key {
      lo = mid + 1
    } else {
      return Some(text)
    }
  }
  None
}

///|
/// Replacement (normally " ") for a space homoglyph, else None.
pub fn space_replacement(cp : Int) -> String? {
  cp_map_lookup(space_homoglyphs, cp)
}

///|
pub fn in_space_homoglyphs(cp : Int) -> Bool {
  space_replacement(cp) != None
}

///|
/// ASCII Latin replacement for a confusable lookalike, else None.
pub fn latin_confusable_replacement(cp : Int) -> String? {
  cp_map_lookup(latin_confusables, cp)
}

///|
/// Bidi / directional format controls (inspect labels).
pub fn is_bidi(cp : Int) -> Bool {
  ranges_contain(bidi_cps, cp)
}

///|
/// Directional marks and isolates preserved by the default clean.
pub fn is_preservable_bidi(cp : Int) -> Bool {
  ranges_contain(preservable_bidi_cps, cp)
}

///|
/// Zero-width family: ZWSP/ZWNJ/ZWJ/WJ/ZWNBSP/Mongolian vowel separator.
pub fn is_zw_family(cp : Int) -> Bool {
  ranges_contain(zw_family, cp)
}

///|
/// ZWJ plus text/emoji variation selectors.
pub fn is_emoji_glue(cp : Int) -> Bool {
  ranges_contain(emoji_glue_cps, cp)
}

///|
/// ZWNJ/ZWJ.
pub fn is_script_joiner(cp : Int) -> Bool {
  ranges_contain(script_joiners, cp)
}

///|
/// Cf marks that are normal Arabic/Syriac orthography.
pub fn is_orthographic_cf(cp : Int) -> Bool {
  ranges_contain(orthographic_cf, cp)
}

///|
/// Mongolian free variation selectors.
pub fn is_mongolian_fvs(cp : Int) -> Bool {
  ranges_contain(mongolian_fvs, cp)
}

///|
/// Khmer inherent vowels (invisible but phonemic).
pub fn is_khmer_vowel(cp : Int) -> Bool {
  ranges_contain(khmer_vowels, cp)
}

///|
/// Hangul fillers that hold a jamo slot.
pub fn is_hangul_filler(cp : Int) -> Bool {
  ranges_contain(hangul_fillers, cp)
}

///|
/// Script range for a visible-layout Cf control (hieroglyph/Duployan/musical),
/// as (script_lo, script_hi), else None.
pub fn layout_cf_script(cp : Int) -> (Int, Int)? {
  for entry in layout_cf_controls {
    let (c_lo, c_hi, s_lo, s_hi) = entry
    if cp >= c_lo && cp <= c_hi {
      return Some((s_lo, s_hi))
    }
  }
  None
}
