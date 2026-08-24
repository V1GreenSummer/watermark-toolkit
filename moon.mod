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

name = "V1GreenSummer/watermark-toolkit"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/V1GreenSummer/watermark-toolkit"

license = "MIT"

keywords = [
  "watermark",
  "llm",
  "detection",
  "unicode",
  "gumbel",
  "cli",
  "wasm",
]

preferred_target = "native"

description = "LLM 文本水印工具箱:隐形 Unicode 载体清洗与检测、keyed-Gumbel 统计水印重放检测、检测引导的 LLM 改写循环(纯 CPU、零模型推理)"

import {
  "gmlewis/sha256@0.17.32",
  "gmlewis/base64@0.16.11",
  "moonbitlang/x@0.5.1",
  "moonbitlang/async@0.21.0",
}
