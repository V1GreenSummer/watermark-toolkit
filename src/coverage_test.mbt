//! Coverage-driven blackbox tests: JSON rendering, prompt building (Python
//! parity), and the CLI token-id parser.

///|
test "report_to_json renders hits and notes" {
  let report = @clean.inspect_text("a\u{200B}b\u{00A0}c")
  let json = @clean.report_to_json(report).stringify()
  assert_true(json.contains("\"suspicious_total\":2"), msg="total")
  assert_true(json.contains("U+200B ZERO WIDTH SPACE"), msg="label")
  assert_true(json.contains("\"kind\":\"zwj_family\""), msg="kind")
  assert_true(
    json.contains("\"confidence\":\"informational\""),
    msg="space confidence",
  )
}

///|
test "stats_to_json renders counters" {
  let (_, stats) = @clean.clean_text("x\u{200B}y\u{00A0}z")
  let json = @clean.stats_to_json(stats).stringify()
  assert_true(json.contains("\"removed_count\":1"), msg="removed")
  assert_true(json.contains("\"replaced_count\":1"), msg="replaced")
  assert_true(
    json.contains("U+200B ZERO WIDTH SPACE (Cf)\":1"),
    msg="removed label",
  )
  assert_true(json.contains("\"nfkc_changed\":false"), msg="nfkc")
}

///|
test "gumbel report_to_json shape" {
  let report = @gumbel.detect_text("one two three four five six", "json-key")
  let json = @gumbel.report_to_json(report).stringify()
  assert_true(json.contains("\"detector\":\"gumbel\""), msg="detector")
  assert_true(json.contains("\"scheme\":\"exp\""), msg="scheme")
  assert_true(json.contains("\"is_watermarked\":false"), msg="verdict")
  assert_true(json.contains("same-key replay"), msg="note")
}

///|
test "gumbel too-short report shape" {
  let report = @gumbel.detect_text("hi", "k")
  assert_true(report.counted == 0, msg="counted")
  let json = @gumbel.report_to_json(report).stringify()
  assert_true(json.contains("no verifiable token positions"), msg="note")
}

///|
test "build_prompt code branch matches Python" {
  let prompt = @rewrite.build_prompt("code", "TEXT")
  inspect(
    prompt,
    content="Rewrite the natural-language parts of this code \u{2014} comments, docstrings, and string literals \u{2014} using different wording. Rename local variables, function parameters, and private helper names to semantically equivalent names. Preserve program behavior, public API names, and all values that affect output. Output only the rewritten code.\n\n---\nTEXT",
  )
}

///|
test "build_prompt backtranslate branch matches Python" {
  let prompt = @rewrite.build_prompt(
    "backtranslate",
    "TEXT",
    lang="German",
    original_lang="English",
  )
  inspect(
    prompt,
    content="Translate the text to German, then translate that result back to English. Preserve all facts, numbers, and names. Output only the final English text.\n\n---\nTEXT",
  )
}

///|
test "build_prompt structural branch matches Python" {
  let prompt = @rewrite.build_prompt("structural", "TEXT")
  inspect(
    prompt,
    content="First extract a bullet outline of all claims (no full sentences). Then write a complete document from that outline in natural, varied human prose without omitting any bullet. Output only the final document.\n\n---\nTEXT",
  )
}

///|
test "build_prompt unknown strength raises" {
  let raised = try {
    let _ = @rewrite.build_prompt("nope", "t")
    false
  } catch {
    _ => true
  }
  assert_true(raised, msg="raises")
}
