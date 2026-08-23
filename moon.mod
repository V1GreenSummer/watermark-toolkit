// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "watermark/watermark-toolkit"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/V1GreenSummer/watermark-toolkit"

license = "MIT"

keywords = [ ]

preferred_target = "native"

description = ""

import {
  "gmlewis/sha256@0.17.32",
  "gmlewis/base64@0.16.11",
  "moonbitlang/x@0.5.1",
  "moonbitlang/async@0.21.0",
}
