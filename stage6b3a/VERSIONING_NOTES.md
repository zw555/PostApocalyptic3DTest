# Stage 6-B.3-A 阶段归档与测试说明

归档审计日期：2026-11-18。玩家明确确认开发、自动化测试和人工验收已完成，人工验收状态为 **PASS**。本轮仅整理 Git 与文档，没有修改游戏逻辑、模型、场景、参数或测试断言，没有进入 B.3-B。

## 归档边界

归档前分支 main，HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127`，三个 tracked 脚本修改、1,389 个 untracked 文件，暂存为空。fetch 后本地相对 origin/main 领先两个既有提交，无分叉：`1346664`（Stage 5-D.1）和 `e36215e`（住宅楼与门洞可见性）。安全推送本分支也会发布这两个已有提交；不重写历史。它们已包含历史截图，最大已有对象为约 9.31 MB 的 GIF，没有超过 GitHub 单文件限制的对象。

本次逐文件清单为 `COMMIT_FILES.txt`。范围包括：B.3-A 配置、装配、场景、测试、入口及三个兼容接口修改；住宅楼 A.4/B、物品与容器 B.1、库存装备 B.2-A、A2.3/A2.4-A/B 的实际运行依赖；六种被引用模型的原生场景、Mesh、材质与 shader；六张运行时图标及离线图标生成脚本。模型 Mesh 和背包 PNG 是游戏运行所需的版本资产，不能用 `.godot` 缓存替代。

依赖审查同时读取了原生资源的外部引用，避免漏掉二进制 `.res` 内嵌的材质依赖；脚本静态路径、动态图标 ID 映射和历史基线入口分别核对。

没有修改 `.gitignore`。`tests/results/` 下仅明确选择的四份历史 `*_hashes.json` 被作为不可变测试输入单独纳入；它们不是本轮运行结果，不重建哈希、不改旧断言。其他输出仍忽略。新增 `.gitkeep` 仅保留测试及图标工具所需的空输出目录。

未纳入本次归档：历史独立美术预览和模型构建实验、旧阶段未被本次引用的测试/性能工具与夹具、截图、日志、初始工作区快照、原脚本备份、机器相关审计输出。它们继续保留在原工作区，并未删除。`tests/audit_workspace.py` 依赖本机完整初始快照，属于本地审计工具，不是可移植运行或功能测试依赖，故本次不纳入。开发报告中的原始 evidence 图片和 JSON 链接保留为本地证据，并不表示这些输出已版本管理；下表保存适合版本管理的结果摘要。

## 验证与复现

以下结果转录自本阶段已有 `evidence/validation_summary.json`，不是本次 Git 整理重新执行功能测试所得。玩家已完成人工验收。无意外失败、无最终运行时脚本错误，严格源码冻结检查仍有三项失败（两项既有、一项本阶段授权接口变更）。不得将其表述为全绿。

| 测试输出 | 通过 | 失败 |
|---|---:|---:|
| `combat_headless.json` | 96 | 0 |
| `combat_render.json` | 96 | 0 |
| `live_headless.json` | 10 | 0 |
| `live_render.json` | 10 | 0 |
| `a24b/journey_ui_headless.json` | 519 | 0 |
| `a24b/journey_ui_render.json` | 519 | 0 |
| `a24b/legacy_data.json` | 34 | 0 |
| `a24b/legacy_equipment.json` | 19 | 0 |
| `legacy/stage5c1_validation.json` | 41 | 0 |
| `legacy/stage5c2_validation.json` | 22 | 0 |
| `legacy/stage5c3a_validation.json` | 39 | 0 |
| `legacy/stage5c3b_validation.json` | 41 | 0 |
| `legacy/stage5d1b_validation.json` | 72 | 1 |
| `legacy/stage4d3_validation.json` | 49 | 1 |
| `legacy/stage5a_validation.json` | 49 | 1 |

已知冻结失败：

- D.1-B：`D1A work assets AI config and scene layouts preserved`，SurvivorAnimator 与 ZombieController 的授权兼容接口修改导致，72/1。
- Camera：`Existing gameplay/layout/models/materials/config immutable`，PlayerController 与 SurvivorAnimator 的历史源码差异，49/1。
- Occlusion：`Prior gameplay/layout/models/materials/resources preserved`，相同两脚本历史源码差异，49/1。

原始文件 SHA-256（字节级，保留现有记录，不重新生成基线）：

| 脚本 | B.3-A 前 | B.3-A 后 |
|---|---|---|
| `scripts/ai/zombie_controller.gd` | `c9b0da583ffc287856a0715b6714a2c721901d39852b291cb1c1366a497b37e9` | `08e535b5588d79216e7f5fc05e241f4fa7964e4ac3ba2b234892fa70406bb3b5` |
| `scripts/combat/stage5c1_melee_attack_controller.gd` | `33ff6ab7d07fc6944b989687d317f8baecb33b59af9bc0d6e8a469d7d8a6f54c` | `0a8989f32831bdd526c3f229db182300abfe7afa1817c1f8ae127b30f4165b54` |
| `scripts/survivor_animator.gd` | `2a848cf90fd3413b6c07ffd2a6e1400e5d700d37b91cf5a0366df1833c516154` | `895f9493bd11c6f4843e93aaffe0a4957c17dc8609dd18e31d4792a934820c10` |

在 Godot 4.5.2 中打开工程并完成正常资源导入后，可运行：

```powershell
# 引擎路径通过公开参数指定；默认路径沿用现有本机启动配置。
powershell -ExecutionPolicy Bypass -File stage6b3a/tests/run_tests.ps1 -GodotBin "C:/path/to/Godot_v4.5.2-stable_win64_console.exe"
# 同时执行真实渲染测试；测试窗口运行期间不要抢鼠标或最小化。
powershell -ExecutionPolicy Bypass -File stage6b3a/tests/run_tests.ps1 -Render -GodotBin "C:/path/to/Godot_v4.5.2-stable_win64_console.exe"
```

`run_tests.ps1` 会明确区分这三项预期冻结失败与意外失败。原生资源/字体/PNG 需要 Godot 的正常导入缓存；不将 `.godot` 或本机缓存加入 Git。历史 SHA-256 测试是原文件字节级比较，改变换行符的克隆配置可能额外触发冻结失败，应先核对换行符，不能更新断言掩盖差异。

人工入口：根目录 `RunStage6B3A.bat`。若引擎不在启动脚本原路径，可直接运行 `Godot --path <工程目录> res://stage6b3a/scenes/gameplay.tscn`。A2.4-B 等基线启动入口继续保留。本次没有重新执行导入、图标生成、构建或玩法测试，避免改变已验收成果。

## Git 暂存格式检查

默认 `git diff --cached --check` 如实返回四条既有格式警告：`scenes/apartment/stage6a3a4_presentation.tscn`、`stage6a3b_floor_extension.tscn`、`stage6b1_item_interaction.tscn`、`stage6b2a_inventory_equipment.tscn` 的第 56 行均为文件末尾空行。为保留已验收场景的原始字节，本次不修剪这些文件。排除 `blank-at-eof` 规则后的独立检查无其他空白错误；这不等同于默认检查全绿。
