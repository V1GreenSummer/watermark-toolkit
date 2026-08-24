# 项目申报书 — wmtool:LLM 文本水印工具箱(MoonBit)

> 2026 MoonBit 国产基础软件生态开源大赛 · 8 月黑客松

## 项目名称

**wmtool(watermark-toolkit)— LLM 文本水印工具箱**:隐形 Unicode 水印的检查与清洗(Layer A)、keyed-Gumbel 统计水印的同密钥重放检测、检测引导的 LLM 改写循环(Layer B)。纯 CPU 计算、零模型推理,以 MoonBit 为主要实现语言。

## 代码仓库

- GitHub:https://github.com/V1GreenSummer/watermark-toolkit(公开)
- mooncakes.io:`V1GreenSummer/watermark-toolkit@0.1.0`(已发布)
- 在线演示:https://v1greensummer.github.io/watermark-toolkit/(wasm-gc,纯浏览器端)

## 项目现有基础(截至报名)

核心功能已按上游 Python 工具链完成 MoonBit 移植并逐位对拍验证:

- **Layer A 检查/清洗**:剥离隐形 Unicode 载体(ZWSP/ZWJ/软连字符/bidi 控制/标签字符/私用区/非字符等),空格同形字归一、拉丁同形字标记,保留 emoji 连接符等"承重"字符避免破坏显示
- **统计检测**:keyed-Gumbel(Aaronson EXP)水印重放检测——HMAC-SHA256 重放噪声 + 精确 Poisson p 值 + 重复窗口掩码 + 确定性分词器
- **Layer B 改写**:OpenAI 兼容 API 改写循环,五档强度(paraphrase/humanize/code/backtranslate/structural),gumbel 检测或 bigram Jaccard 词法散度作评估,默认仅允许回环地址端点
- **配套工程**:`wmtool` CLI(4 子命令)、wasm-gc Web playground(检查/清洗/检测三页,中英双语)、Python 向量生成工具
- **质量与工程**:159 项测试全通过;与 Python 参考实现生成式对拍(65/65 Layer A、69/69 Gumbel、11/11 词法散度);`moon check --deny-warn` 零警告;CI(check/test/fmt/构建)已配置;README/AGENTS 文档完整

## 本次计划开发或新增的内容

1. Layer B rewrite 端到端对拍与边界完善(超时/重试、错误信息与上游对齐)
2. 补充 Unicode 复杂脚本边界用例(bidi 配对、承重字符保留)与模糊测试向量
3. CI 完善(多平台构建、wasm 测试)与 mooncakes.io 版本自动发布
4. Web playground 可读性持续打磨与文档完善

## 项目预期目标和技术路线

- **目标**:交付一个可复用、可发布的 MoonBit 生态库,附带开箱即用的 CLI 与 Web 工具,服务于内容溯源清理(隐私/来源卫生)与自有水印系统的鲁棒性评估;为 MoonBit 生态补充 LLM 水印检测这一空白方向
- **技术路线**:纯 MoonBit 实现(HMAC-SHA256、Gumbel 统计量、Poisson survival、Unicode 数据表),零模型推理、纯 CPU;Unicode 表由 `tools/gen_unicode_tables.py` 从 CPython unicodedata 生成;Python 参考实现仅用于对拍;接口 JSON 进出,便于跨语言集成

## 预计完成的功能、测试和文档

- **功能**:inspect/clean/detect/rewrite 四子命令 + Web 三页 playground(已完成);rewrite 边界打磨(验收期内完成)
- **测试**:单元测试 + 生成式对拍测试 + 浏览器端冒烟测试(159 项,持续扩展);CI 自动执行
- **文档**:README(用途/功能/用法/对拍方法/已知差异/致谢)、AGENTS.md、申报书(本文)

## 移植项目说明(原项目、链接、许可证、移植范围)

| 原项目 | 链接 | 许可证 | 移植范围 |
|---|---|---|---|
| watermarks-remover | https://github.com/guillaumemeyer/watermarks-remover | MIT | Layer A 清洗/检测规则与 Layer B 改写循环,移植为 `src/clean`、`src/rewrite` |
| kuleshov-group/watermark("A Watermark for Large Language Models" 官方实现) | https://github.com/kuleshov-group/watermark | Apache-2.0 | Gumbel 统计检测逻辑,移植为 `src/gumbel` |

- Python 源码副本保留在 `reference/` 仅供对拍,原版权头与许可证均已保留,来源说明见 README「致谢」
- 尚未移植/明确不包含:NFKC 归一化、C2PA/EXIF 元数据剥离、像素水印去除、MarkLLM/torch 生态(见 README「能力」与「与 Python 版的已知差异」)
