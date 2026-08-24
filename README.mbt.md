# wmtool — LLM 文本水印工具箱（MoonBit）

[guillaumemeyer/watermarks-remover](https://github.com/guillaumemeyer/watermarks-remover)（MIT）核心能力的 [MoonBit](https://www.moonbitlang.com/) 移植：隐形 Unicode 水印的检查与清洗（Layer A）、keyed-Gumbel/EXP 统计水印的同密钥重放检测、检测引导的 LLM 改写循环（Layer B）。纯 CPU 计算、零模型推理、native 单二进制。

> **用途边界（与上游一致）**：本工具用于清理**你自己拥有或获得授权**的内容中的溯源标记（隐私清理/来源卫生），以及在你自己的水印系统上做鲁棒性评估。不用于学术造假或冒充人写内容。检测为同密钥重放（same-key replay），对他人密钥/厂商检测器不构成 oracle；阴性结果不能证明任何事。

## 能力

| 子命令 | 层 | 说明 |
|---|---|---|
| `wmtool clean` | Layer A | 剥离隐形 Unicode 载体（ZWSP/ZWJ/软连字符/bidi 控制/标签字符/私用区/非字符/保留可忽略码点等），空格同形字归一为 U+0020；保留"承重"隐形字符（emoji 胶水、完整旗帜标签序列、同文字系统连接符/填充符等） |
| `wmtool inspect` | Layer A | 报告可疑码点（类别/名称/次数/偏移），不修改文本 |
| `wmtool detect` | 统计层 | keyed-Gumbel（Aaronson EXP）重放检测：HMAC-SHA256 重放噪声 + 精确 Poisson p 值 + 重复窗口掩码；文本走确定性分词器，或 `--tokens` 直接喂引擎 token id |
| `wmtool rewrite` | Layer B | OpenAI 兼容 API 改写循环（paraphrase/humanize/code/backtranslate/structural 五档强度）：生成→评估（gumbel 检测引导或 bigram Jaccard 词法散度）→通过即停/择优；默认仅允许回环地址端点 |

不包含：C2PA/EXIF 文件元数据剥离、像素水印去除（CtrlRegen/MarkDiffusion）、MarkLLM/torch 生态（详见上游仓库）。

## Web Playground（浏览器端，零服务器）

`web/` 目录是纯静态页面：像素风 CRT 界面、中英文一键切换，三个标签页（检查 / 清洗 / 检测）直接调用编译到 wasm-gc 的同一套 MoonBit 核心逻辑（`web/main/` 导出层，启用 js-string builtins，字符串 JSON 进出）。无后端、无 API 调用、文本不出浏览器。

```sh
sh web/build.sh                 # 构建 wasm 并复制到 web/main.wasm (~257KB)
cd web && python3 -m http.server 8765
# 打开 http://localhost:8765
```

## 构建与运行

```sh
moon run cmd/main -- help
moon run cmd/main -- clean input.txt --json
moon run cmd/main -- inspect input.txt
moon run cmd/main -- detect input.txt --key '0x00112233' --window 4
moon run cmd/main -- detect ids.json --tokens --key my-key
moon run cmd/main -- rewrite input.txt --strength paraphrase --print-prompt
moon run cmd/main -- rewrite input.txt --model llama3.2 --gumbel-key K --max-loops 3
```

依赖：`gmlewis/sha256`（SHA-256/HMAC）、`moonbitlang/async`（HTTP）、`moonbitlang/x`（fs）。Unicode 表由 `tools/gen_unicode_tables.py` 从 CPython `unicodedata` 生成。

## 正确性验证（与 Python 参考实现逐位对拍）

所有核心逻辑用生成式对拍测试锁定（Python 参考实现跑期望值 → 生成 MoonBit 测试）：

- Layer A：25 个精选边界用例（ZW 家族、bidi 配对、emoji ZWJ 链、旗帜标签序列、蒙文 FVS/高棉元音/谚文填充的同文字保留、CJK 变体选择符、私用区/非字符/保留码点、布局 Cf 控制符…）+ 40 个种子模糊用例，清洗输出、统计、inspect 报告全字段一致（65/65）
- Gumbel：分词器、HMAC seed/uniform 逐位置中间值、Poisson p 值、重复窗口掩码、含贪心构造的强水印用例（69/69）
- 词法散度/候选选择：11/11

再生成向量：`python3 tools/gen_unicode_tables.py && python3 tools/gen_clean_vectors.py && python3 tools/gen_gumbel_vectors.py && python3 tools/gen_rewrite_vectors.py`

## 与 Python 版的已知差异

- `clean --nfkc` 未实现（上游默认关闭；需要 NFKC 规范化请用 Python 版）
- 自然对数用 `log2(x)·ln2` 计算（core 无 `log`/`log1p`），统计量相对误差 ~1e-15，对拍用 1e-9 容差覆盖
- `tokenize_simple` 的小写化是逐字符的（Python `str.lower()` 的完整映射如 ß→ss 不覆盖）
- rewrite 无请求超时参数；错误信息为构造器路径而非 Python 的文本消息
- 检测报告中的 statistic/score 不做 6 位小数舍入（全精度输出）

## 结构

```
src/unicodedata/  生成的码点表(Cf 全集/脚本字母区间/标签) + 查询函数
src/clean/        Layer A: decide/clean_text/inspect_text 移植
src/gumbel/       HMAC-SHA256、keyed-Gumbel 重放检测、Poisson survival
src/rewrite/      prompt 模板、bigram Jaccard 散度、OpenAI 兼容调用、改写循环
cmd/main/         argparse CLI
tools/            向量/表生成器（Python）
reference/        上游参考源码副本（对拍用）
```

## 致谢

- [watermarks-remover](https://github.com/guillaumemeyer/watermarks-remover)（MIT）— 上游实现与规则设计
- Kirchenbauer et al., *A Watermark for Large Language Models*；Aaronson keyed-Gumbel 方案；ARBI 技术报告 — 算法背景
- `reference/watermark_processor.py`、`reference/extended_watermark_processor.py`、`reference/normalizers.py` 来自论文官方实现（[kuleshov-group/watermark](https://github.com/kuleshov-group/watermark)，Apache-2.0，版权头保留），仅作对拍参考
