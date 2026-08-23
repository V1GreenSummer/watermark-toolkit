//! Model-free keyed-Gumbel (Aaronson EXP) text-watermark detector.
//!
//! Port of watermarks-remover `detect_gumbel.py` (MIT). Replays the keyed
//! sampler's noise from the text alone: seed = HMAC-SHA256(key, last H token
//! ids), u_t = HMAC-SHA256(seed, token id) mapped to (0,1), and
//! S = sum -ln(1-u_t) ~ Gamma(counted, 1) under the null.
//!
//! Same-key replay only: valid against the same key, tokenizer, and PRF
//! layout used at generation. A negative result establishes nothing.

///|
pub struct GumbelReport {
  window : Int
  threshold : Double
  tokens_total : Int
  skipped_no_context : Int
  skipped_repeated : Int
  counted : Int
  statistic : Double // 0.0 when nothing was counted
  p_value : Double
  score : Double
  is_watermarked : Bool
  note : String
}

///|
let u64_modulus : Double = 18446744073709551616.0 // 2^64

///|
let ln2 : Double = 0.6931471805599453

///|
fn ln(x : Double) -> Double {
  @math.log2(x) * ln2
}

// ---------------------------------------------------------------------------
// SHA-256 / HMAC over Bytes
// ---------------------------------------------------------------------------

///|
fn sha256_hex(parts : Array[Bytes]) -> String {
  let d = @sha256.Digest::new()
  for p in parts {
    for b in p {
      d.write(b)
    }
  }
  d.check_sum()
}

///|
fn hex_nibble(c : Char) -> Int? {
  let cp = c.to_int()
  if cp >= 0x30 && cp <= 0x39 {
    Some(cp - 0x30)
  } else if cp >= 0x61 && cp <= 0x66 {
    Some(cp - 0x61 + 10)
  } else if cp >= 0x41 && cp <= 0x46 {
    Some(cp - 0x41 + 10)
  } else {
    None
  }
}

///|
/// Parse even-length hex; None on any non-hex character.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(hex_to_bytes("00ff10").unwrap().length(), content="3")
///   inspect(hex_to_bytes("00ff10").unwrap()[1].to_int(), content="255")
///   inspect(hex_to_bytes("abc") is None, content="true")
/// }
/// ```
pub fn hex_to_bytes(hex : String) -> Bytes? {
  if hex.length() % 2 != 0 {
    return None
  }
  let out : Array[Byte] = []
  let chars = hex.to_array()
  for k in 0..<(chars.length() / 2) {
    let i = k * 2
    let hi = hex_nibble(chars[i])
    let lo = hex_nibble(chars[i + 1])
    match (hi, lo) {
      (Some(h), Some(l)) => out.push((h * 16 + l).to_byte())
      _ => return None
    }
  }
  Some(Bytes::from_array(out))
}

///|
fn utf8_bytes(text : String) -> Bytes {
  let buf = Buffer(size_hint=text.length() * 2)
  buf.write_string_utf8(text)
  buf.to_bytes()
}

///|
fn xor_byte(b : Byte, mask : Int) -> Byte {
  (b.to_int() ^ mask).to_byte()
}

///|
/// Standard HMAC-SHA256; the digest is returned as raw bytes.
fn hmac_sha256(key : Bytes, msg : Bytes) -> Bytes {
  let mut k : Bytes = key
  if k.length() > 64 {
    k = hex_to_bytes(sha256_hex([k])).unwrap()
  }
  let block = 64
  let ipad : Array[Byte] = []
  let opad : Array[Byte] = []
  for i in 0..<block {
    let kb = if i < k.length() { k[i] } else { b'\x00' }
    ipad.push(xor_byte(kb, 0x36))
    opad.push(xor_byte(kb, 0x5C))
  }
  let inner = hex_to_bytes(sha256_hex([Bytes::from_array(ipad), msg])).unwrap()
  hex_to_bytes(sha256_hex([Bytes::from_array(opad), inner])).unwrap()
}

///|
fn pack_u64_be(v : UInt64, out : Array[Byte]) -> Unit {
  for i in 0..<8 {
    let shift = (7 - i) * 8
    out.push(((v >> shift) & 0xFFUL).to_int().to_byte())
  }
}

///|
fn be_bytes_to_u64(bytes : Bytes) -> UInt64 {
  let n = if bytes.length() < 8 { bytes.length() } else { 8 }
  let mut v : UInt64 = 0UL
  for i in 0..<n {
    v = (v << 8) | bytes[i].to_int().to_uint64()
  }
  v
}

// ---------------------------------------------------------------------------
// Keyed replay
// ---------------------------------------------------------------------------

///|
fn pack_ids(ids : Array[UInt64], start : Int, len : Int) -> Bytes {
  let out : Array[Byte] = []
  for i in start..<(start + len) {
    pack_u64_be(ids[i], out)
  }
  Bytes::from_array(out)
}

///|
fn gumbel_seed(
  key : Bytes,
  ids : Array[UInt64],
  start : Int,
  len : Int,
) -> Bytes {
  hmac_sha256(key, pack_ids(ids, start, len))
}

///|
/// Per-candidate uniform in (0, 1): HMAC-SHA256(seed, token id).
fn gumbel_uniform(seed : Bytes, token_id : UInt64) -> Double {
  let tmp : Array[Byte] = []
  pack_u64_be(token_id, tmp)
  let digest = hmac_sha256(seed, Bytes::from_array(tmp))
  (be_bytes_to_u64(digest).to_double() + 0.5) / u64_modulus
}

///|
/// P(Gamma(n, 1) >= s) = e^-s * sum_{k<n} s^k / k!, computed via logsumexp.
fn poisson_survival(s : Double, n : Int) -> Double {
  if n <= 0 || s <= 0.0 {
    return 1.0
  }
  let lns = ln(s)
  let mut log_term = 0.0 // k = 0 term is 1
  let mut maxv = 0.0
  for k in 1..<n {
    log_term = log_term + lns - ln(k.to_double())
    if log_term > maxv {
      maxv = log_term
    }
  }
  log_term = 0.0
  let mut acc = @math.exp(-maxv) // k = 0 term
  for k in 1..<n {
    log_term = log_term + lns - ln(k.to_double())
    acc = acc + @math.exp(log_term - maxv)
  }
  let p = @math.exp(-s + maxv + ln(acc))
  if p < 0.0 {
    return 0.0
  }
  if p > 1.0 {
    return 1.0
  }
  p
}

///|
/// Run the keyed-Gumbel replay test over a sequence of token ids.
/// mask_repeated counts a context window only on its first occurrence.
pub fn detect_token_ids(
  token_ids : Array[UInt64],
  key : String,
  window? : Int = 4,
  threshold? : Double = 0.000001,
  mask_repeated? : Bool = true,
) -> GumbelReport {
  let key_bytes = normalize_key(key)
  let total = token_ids.length()
  let mut statistic = 0.0
  let mut counted = 0
  let seen : Map[Bytes, Bool] = Map([])
  let mut skipped_repeated = 0
  if window >= 1 && total > window {
    for t in window..<total {
      let win = pack_ids(token_ids, t - window, window)
      if mask_repeated {
        if seen.get(win).unwrap_or(false) {
          skipped_repeated = skipped_repeated + 1
          continue
        }
        seen.set(win, true)
      }
      let u = gumbel_uniform(
        gumbel_seed(key_bytes, token_ids, t - window, window),
        token_ids[t],
      )
      statistic = statistic - ln(1.0 - u)
      counted = counted + 1
    }
  }
  let skipped_no_context = if total < window { total } else { window }
  if counted == 0 {
    return {
      window,
      threshold,
      tokens_total: total,
      skipped_no_context,
      skipped_repeated,
      counted,
      statistic: 0.0,
      p_value: 1.0,
      score: 0.0,
      is_watermarked: false,
      note: "no verifiable token positions (text too short for a full context window)",
    }
  }
  let p = poisson_survival(statistic, counted)
  let score = if p > 0.0 { -@math.log10(p) } else { 300.0 }
  {
    window,
    threshold,
    tokens_total: total,
    skipped_no_context,
    skipped_repeated,
    counted,
    statistic,
    p_value: p,
    score,
    is_watermarked: p < threshold,
    note: "same-key replay of the keyed-Gumbel (Aaronson EXP) watermark; valid only against the same key, tokenizer, and PRF layout used at generation",
  }
}

///|
/// Key -> bytes: "0x<hex>" decodes to raw bytes, anything else is UTF-8.
pub fn normalize_key(raw : String) -> Bytes {
  let s = raw
  if s.length() >= 2 && (s.has_prefix("0x") || s.has_prefix("0X")) {
    let hexpart = s.sub(start=2).to_owned()
    match hex_to_bytes(hexpart) {
      Some(bytes) => return bytes
      None => ()
    }
  }
  utf8_bytes(s)
}

///|
/// Deterministic word/run tokenizer -> stable token ids: SHA-256 of each
/// [A-Za-z0-9]+ run of the lowercased text, first 8 bytes big-endian.
pub fn tokenize_simple(text : String) -> Array[UInt64] {
  let lowered = text.to_lower()
  let ids : Array[UInt64] = []
  try {
    let re = @string.Regex::Regex("[A-Za-z0-9]+")
    for m in re.find(lowered) {
      let digest_hex = sha256_hex([utf8_bytes(m.content().to_owned())])
      ids.push(be_bytes_to_u64(hex_to_bytes(digest_hex).unwrap()))
    }
  } catch {
    _ => ()
  }
  ids
}

///|
/// Run the replay test over plain text via the deterministic tokenizer.
pub fn detect_text(
  text : String,
  key : String,
  window? : Int = 4,
  threshold? : Double = 0.000001,
) -> GumbelReport {
  detect_token_ids(tokenize_simple(text), key, window~, threshold~)
}

///|
pub fn report_to_json(report : GumbelReport) -> Json {
  let root : Map[String, Json] = Map([])
  root.set("detector", Json::string("gumbel"))
  root.set("scheme", Json::string("exp"))
  root.set("vendor", Json::string("self-hosted"))
  root.set("available", Json::boolean(true))
  root.set("window", Json::number(report.window.to_double()))
  root.set("threshold", Json::number(report.threshold))
  root.set("tokens_total", Json::number(report.tokens_total.to_double()))
  root.set(
    "skipped_no_context",
    Json::number(report.skipped_no_context.to_double()),
  )
  root.set(
    "skipped_repeated",
    Json::number(report.skipped_repeated.to_double()),
  )
  root.set("counted", Json::number(report.counted.to_double()))
  root.set("statistic", Json::number(report.statistic))
  root.set("p_value", Json::number(report.p_value))
  root.set("score", Json::number(report.score))
  root.set("is_watermarked", Json::boolean(report.is_watermarked))
  root.set("note", Json::string(report.note))
  Json::object(root)
}

///|
