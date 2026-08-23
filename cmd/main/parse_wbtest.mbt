//! Whitebox test for the private token-id parser.

///|
test "parse_token_ids json array and lines" {
  let from_json = parse_token_ids("[2, 1337, 42]")
  assert_eq(from_json.length(), 3, msg="json count")
  assert_true(from_json[1] == 1337UL, msg="json id")

  let from_lines = parse_token_ids("7\n\n8\n9\n")
  assert_eq(from_lines.length(), 3, msg="lines count")
  assert_true(from_lines[2] == 9UL, msg="lines id")

  let empty = parse_token_ids("")
  assert_eq(empty.length(), 0, msg="empty")
}
