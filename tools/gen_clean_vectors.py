#!/usr/bin/env python3
"""Cross-validation vector generator for the Layer A port.

Runs the reference Python `clean_text`/`inspect_text` over curated edge cases
plus seeded random fuzz strings, and emits `src/clean/vectors_gen_test.mbt`
with one MoonBit `test` block per case. All strings are emitted with
`\\u{...}` escapes so the generated source stays pure ASCII.

Regenerate: python3 tools/gen_clean_vectors.py [--seed N] [--random N]
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "reference" / "watermarks-remover"))
import text_unicode as TU  # noqa: E402


def mbt_string(s: str) -> str:
    out = ['"']
    for ch in s:
        cp = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\r":
            out.append("\\r")
        elif 0x20 <= cp <= 0x7E:
            out.append(ch)
        else:
            out.append(f"\\u{{{cp:X}}}")
    out.append('"')
    return "".join(out)


def sanitize_name(name: str) -> str:
    return "".join(c if c.isalnum() or c in "-_" else "_" for c in name).lower()


def build_cases(seed: int, random_count: int) -> list[dict]:
    rng = random.Random(seed)
    cases: list[dict] = []

    def case(name: str, text: str, **opts):
        cases.append({"name": name, "text": text, "opts": opts})

    # Plain text: nothing suspicious
    case("plain", "Hello world, nothing to see here.")
    # Zero-width carriers sprinkled into prose
    case(
        "zw-basics",
        "Vi\u200Bsi\u200Bble\u200C but\u200D marked\u2060 and\u00AD soft\uFEFF.",
    )
    # Bidi: paired LRE..PDF (preserved), unpaired RLO (stripped), isolates (preservable)
    case(
        "bidi",
        "a\u202Ab\u202Cc d\u202De\u202Cf g\u2066h\u2069i \u061Cj",
    )
    case("bidi-strip", "a\u202Ab\u202Cc d\u202De\u202Cf g\u2066h\u2069i \u061Cj", strip_bidi=True)
    # Emoji glue: family ZWJ chain kept, lone ZWJ stripped, VS16 after base kept
    case(
        "emoji-glue",
        "hi \U0001F468\u200D\U0001F469\u200D\U0001F467 bye \u26A0\uFE0F! lone\u200D \U0001F3F3\uFE0F\u200D\U0001F308",
    )
    case(
        "emoji-glue-strip",
        "hi \U0001F468\u200D\U0001F469\u200D\U0001F467 bye \u26A0\uFE0F! lone\u200D \U0001F3F3\uFE0F\u200D\U0001F308",
        strip_emoji_glue=True,
    )
    # Subdivision flag: complete tag run kept, orphan tag chars stripped
    case(
        "flag-tags",
        "flag \U0001F3F4\U000E0067\U000E0062\U000E0073\U000E0063\U000E0074\U000E007F end \U000E0067 orphans \U000E007F",
    )
    # Space homoglyphs normalized; ideographic space; no-normalize variant
    case("spaces", "a\u00A0b\u2003c\u205Fd\u3000e\u202Ff")
    case("spaces-off", "a\u00A0b\u2003c\u205Fd\u3000e\u202Ff", normalize_spaces=False)
    # Confusables only in aggressive mode
    case("confusable", "\u0410\u0412\u0415\u041A \uFF21\uFF22\uFF23 abc")
    case(
        "confusable-aggressive",
        "\u0410\u0412\u0415\u041A \uFF21\uFF22\uFF23 abc",
        aggressive=True,
    )
    # Script-internal glue: Arabic ZWNJ between letters, isolated ZWNJ
    case("arabic-zwnj", "\u0645\u06CC\u200D\u0631\u0648\u0645 isolated\u200C\u0645")
    # Mongolian FVS after Mongolian letter vs isolated
    case("mongolian-fvs", "\u1824\u180B\u1824 isolated\u180B\u180F")
    # Khmer inherent vowel after Khmer letter vs isolated
    case("khmer", "\u1780\u17B4\u1781 isolated\u17B5")
    # Hangul filler after jamo vs isolated
    case("hangul", "\u1100\u115F\u1160 isolated\u3164\uFFA0")
    # CJK ideograph + VS kept; lone VS stripped; Mongolian base + FVS kept
    case("variation-selectors", "\u4E00\uFE00\u4E01\uE0100 lone\uFE0F\uE0100 \u1820\u180D")
    # Private use, noncharacters, reserved ignorables, soft hyphen run
    case("pua", "x\U0000E000y\uF890z \U000F0000\U000F0001 \U00100000")
    case("noncharacters", "a\uFDD0b\uFDEFc\uFFFEd\uFFFFe\U0010FFFEf")
    case("reserved", "a\u2065b\uFFF0c\U000E0080d\U000E01F0e\U000E0000f")
    # Orthographic Arabic Cf kept, other Cf stripped
    case("orthographic-cf", "keep \u0600\u0601 drop \u2061\u2062 \u070F")
    # Layout Cf controls next to their script vs floating
    case(
        "layout-cf",
        "hieroglyph \U00013362\U00013430\U00013362 floating\U00013430",
    )
    # Aggressive + strip-everything combined
    case(
        "paranoid",
        "\u0410 \U0001F469\u200D\U0001F4BB a\u00A0b\u200B \u202Aa\u202Cb",
        aggressive=True,
        strip_emoji_glue=True,
        strip_bidi=True,
    )
    # Empty and tiny inputs
    case("empty", "")
    case("one-char", "a")
    case("one-zwsp", "\u200B")

    # Seeded fuzz: mix prose, strip-class cps, spaces, confusables, Cf, planes
    prose = "the quick brown fox jumps over the lazy dog "
    interesting = sorted(
        set(TU.STRIP_CODEPOINTS)
        | set(TU.SPACE_HOMOGLYPHS)
        | set(TU.LATIN_CONFUSABLES)
        | {0x2061, 0x2062, 0x0600, 0x070F, 0xE0001, 0xE007F, 0x13430, 0x1BCA0, 0x1D173}
    )
    for i in range(random_count):
        parts = []
        for _ in range(rng.randint(4, 18)):
            r = rng.random()
            if r < 0.45:
                parts.append(rng.choice(prose.split() + ["\u4E2D\u6587", "\u0645\u0631\u062D\u0628\u0627"]))
            elif r < 0.85:
                parts.append(chr(rng.choice(interesting)))
            else:
                cp = rng.choice(
                    [rng.randint(0x20, 0x7E), rng.randint(0xA0, 0x2FFF), rng.randint(0x3000, 0xD7FF), rng.randint(0xE000, 0x10FFFF)]
                )
                parts.append(chr(cp))
        case(f"fuzz-{i}", "".join(parts))
    return cases


def main() -> None:
    seed = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else 20260822
    random_count = int(sys.argv[sys.argv.index("--random") + 1]) if "--random" in sys.argv else 40
    cases = build_cases(seed, random_count)

    lines = [
        "// Generated by tools/gen_clean_vectors.py -- DO NOT EDIT BY HAND.",
        "// Expectations come from the reference Python text_unicode.py.",
        "",
        "fn veq_str(label : String, got : String, want : String) -> Unit raise {",
        "  if got != want {",
        "    println(\"mismatch [\" + label + \"]\")",
        "    println(\"  got : \" + got.escape())",
        "    println(\"  want: \" + want.escape())",
        "  }",
        "  assert_eq(got, want, msg=label)",
        "}",
        "",
        "fn veq_hits(label : String, report : InspectReport, want : Array[(Int, String, Int)]) -> Unit raise {",
        "  let got : Array[(Int, String, Int)] = []",
        "  for hit in report.hits {",
        "    got.push((hit.codepoint, hit.kind, hit.count))",
        "  }",
        "  assert_eq(report.hits.length(), want.length(), msg=label + \" hit count\")",
        "  for i = 0; i < got.length() && i < want.length(); i = i + 1 {",
        "    let (gcp, gkind, gcount) = got[i]",
        "    let (wcp, wkind, wcount) = want[i]",
        "    if gcp != wcp || gkind != wkind || gcount != wcount {",
        "      println(\"mismatch [\" + label + \"] hit \" + i.to_string() + \": got (\" + gcp.to_string() + \",\" + gkind + \",\" + gcount.to_string() + \") want (\" + wcp.to_string() + \",\" + wkind + \",\" + wcount.to_string() + \")\")",
        "    }",
        "    assert_eq(gcp, wcp, msg=label + \" hit cp\")",
        "    assert_eq(gkind, wkind, msg=label + \" hit kind\")",
        "    assert_eq(gcount, wcount, msg=label + \" hit count\")",
        "  }",
        "}",
        "",
        "fn veq_stats(label : String, stats : CleanStats, want_in : Int, want_out : Int, want_removed : Array[(String, Int)], want_replaced : Array[(String, Int)]) -> Unit raise {",
        "  assert_eq(stats.input_length, want_in, msg=label + \" input_length\")",
        "  assert_eq(stats.output_length, want_out, msg=label + \" output_length\")",
        "  assert_eq(stats.removed_count, want_removed.fold(init=0, fn(a, e) { a + e.1 }), msg=label + \" removed_count\")",
        "  assert_eq(stats.replaced_count, want_replaced.fold(init=0, fn(a, e) { a + e.1 }), msg=label + \" replaced_count\")",
        "  assert_eq(stats.removed.length(), want_removed.length(), msg=label + \" removed labels\")",
        "  for i = 0; i < stats.removed.length() && i < want_removed.length(); i = i + 1 {",
        "    assert_eq(stats.removed[i].0, want_removed[i].0, msg=label + \" removed label\")",
        "    assert_eq(stats.removed[i].1, want_removed[i].1, msg=label + \" removed count\")",
        "  }",
        "  assert_eq(stats.replaced.length(), want_replaced.length(), msg=label + \" replaced labels\")",
        "  for i = 0; i < stats.replaced.length() && i < want_replaced.length(); i = i + 1 {",
        "    assert_eq(stats.replaced[i].0, want_replaced[i].0, msg=label + \" replaced label\")",
        "    assert_eq(stats.replaced[i].1, want_replaced[i].1, msg=label + \" replaced count\")",
        "  }",
        "}",
        "",
    ]

    for idx, c in enumerate(cases):
        opts = c["opts"]
        kw = {
            "normalize_spaces": opts.get("normalize_spaces", True),
            "aggressive_homoglyphs": opts.get("aggressive", False),
            "strip_emoji_glue": opts.get("strip_emoji_glue", False),
            "strip_bidi": opts.get("strip_bidi", False),
        }
        cleaned, stats = TU.clean_text(c["text"], nfkc=False, **kw)
        report = TU.inspect_text(
            c["text"],
            aggressive=kw["aggressive_homoglyphs"],
            strip_emoji_glue=kw["strip_emoji_glue"],
        )
        name = f"{idx:03d}-{sanitize_name(c['name'])}"

        def count_list(counter: dict) -> str:
            items = [f"    ({mbt_string(k)}, {v})," for k, v in sorted(counter.items())]
            if not items:
                return "[]"
            return "[\n" + "\n".join(items) + "\n  ]"

        hits = [f"    ({h.codepoint}, {mbt_string(h.kind)}, {h.count})," for h in report.hits]
        hits_lit = "[\n" + "\n".join(hits) + "\n  ]" if hits else "[]"

        lines.extend(
            [
                f"test \"vector {name}\" {{",
                f"  let (out, stats) = clean_text({mbt_string(c['text'])},",
                f"    normalize_spaces={str(kw['normalize_spaces']).lower()},",
                f"    aggressive_homoglyphs={str(kw['aggressive_homoglyphs']).lower()},",
                f"    strip_emoji_glue={str(kw['strip_emoji_glue']).lower()},",
                f"    strip_bidi={str(kw['strip_bidi']).lower()},",
                "  )",
                f"  veq_str(\"{name}/out\", out, {mbt_string(cleaned)})",
                f"  veq_stats(\"{name}\", stats, {stats['input_length']}, {stats['output_length']},",
                f"    {count_list(stats['removed'])},",
                f"    {count_list(stats['replaced'])},",
                "  )",
                f"  let report = inspect_text({mbt_string(c['text'])},",
                f"    aggressive={str(kw['aggressive_homoglyphs']).lower()},",
                f"    strip_emoji_glue={str(kw['strip_emoji_glue']).lower()},",
                "  )",
                f"  assert_eq(report.length, {report.length}, msg=\"{name}/len\")",
                f"  assert_eq(report.suspicious_total, {report.suspicious_total}, msg=\"{name}/total\")",
                f"  veq_hits(\"{name}\", report, {hits_lit})",
                "}",
                "",
            ]
        )

    out = ROOT / "src" / "clean" / "vectors_gen_test.mbt"
    out.write_text("\n".join(lines), encoding="ascii")
    print(f"wrote {out.relative_to(ROOT)}: {len(cases)} cases")


if __name__ == "__main__":
    main()
