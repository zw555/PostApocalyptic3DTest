# Stage 5-D.1 收尾、回归审查与本地检查点

审查日期：2026-11-16（Asia/Shanghai）。本轮只审查、复测和整理检查点，没有开发新功能。

## A. Git 与改动归属

实际初始分支为 main，HEAD 为 93f9282；git log 显示上一个基线为 edc9a4b。起始暂存区为空，工作区有五份已跟踪脚本修改和本阶段新增文件。

已执行 git status、git branch --show-current、git log -5 --oneline、git diff --stat、git diff --check 和 git diff --name-status；格式检查通过。

五份既有源码的归属：

| 文件 | 归属及实际用途 |
|---|---|
| scripts/ai/zombie_controller.gd | D.1-A：ATTACK 在有效距离外可按原导航追近，保留前摇、恢复、方向锁定、冷却和 1.7m 防抖退出 |
| scripts/combat/stage5c1_melee_attack_controller.gd | D.1-B：默认关闭的左键长按准备、松开攻击和共享冷却，复用原命中/伤害路径 |
| scripts/combat/stage5c1_character_attack_visual.gd | D.1-B 与过渡修复：实际姿态快照、共享挥击轨迹及手部握点 |
| scripts/combat/stage5c3b_player_feedback.gd | 原唯一上身姿态写入者接入融合姿态，受击与死亡优先 |
| scripts/player_controller.gd | 可选准备移动倍率，基础速度不变 |

其余新增内容均属于本阶段：两个启动 BAT、两个继承 C.3-B 的验证场景、三个实验/统计脚本、三个验证脚本、三个测试入口、四份阶段报告（含本报告）和 23 张 Godot 视口 PNG。

未发现无法确认归属或与本阶段无关的改动。D.1-A、D.1-B 和姿态修复均完整保留，没有删除、重置、清理或覆盖人工资源。

提交范围明确排除 tests/results/、.godot/、日志、历史失败复现备份、临时 SHA 快照、导出物及机器运行数据；这些继续由已有忽略规则排除。候选文本扫描未匹配私钥、GitHub token、常见 API/AWS 凭据模式；同时审阅了实际文件清单，未发现敏感信息混入。模式扫描不等同于对任何任意格式秘密的数学保证。

## B. 功能审查结论

### D.1-A

- 1.49/1.51/1.69/1.71m 边界、1.5～1.7m 击退后追近、攻击恢复后追近、冷却不可绕过均通过原专项行为断言。
- 修复只让非前摇/非恢复的真实近战僵尸在攻击距离与退出距离之间导航接近；超过退出距离仍走原 CHASE 转换。
- 保留原追逐 1.6m/s、HP 30、伤害 10，以及原攻击时间和碰撞。没有移动货架或修改导航资源。
- 实验统计为观察器，复用既有信号与计数；重复观察不改战斗结果。R 位移会标记该实验样本无效。

### D.1-B

- 只在独立 D.1-B 入口显式启用，旧 C.1/C.2/C.3 默认入口行为保留。
- 左键短按松开后普通攻击：0.20s 命中；保持 0.30s 到 READY，松开后快攻：0.08s 命中。
- READY 不自动攻击，不增长伤害、范围、击退或暴击；共享最小起手间隔 0.65s。
- PREPARING/READY 目标速度 2.4m/s，正常 3.2m/s；取消和松开不修改基础速度。
- 冷却中释放不排队补刀；重复按下/释放不返还冷却。GUI 消费释放、受击、死亡、搜刮和失焦均正确清除准备。
- 受击/死亡仍高于攻击，死亡后输入门禁及相机观察行为保持。

### 姿态融合

起手捕获实际右臂、前臂、武器和上身姿态；不先恢复默认角度。普通与快攻共用当前姿态到命中、收势及回到步态基底的轨迹，分别按原 0.20/0.08s 前摇采样。原准备残余权重覆盖普通挥击的路径已移除。受击/死亡保留最终姿态优先级，没有第二套伤害系统或 AnimationTree。

本轮未修改上述实现、玩法配置、素材或旧测试预期。

## C. 本轮重新执行的自动检查

实际执行入口：tests/run_pose_blend_tests.ps1 -Capture。该入口依次运行姿态专项、D.1-B、C.1/C.2/C.3、十组兼容性套件、D.1-A 和死亡专项，不跳过失败项。

实际引擎为 Godot 4.5.2.stable.official.6ce3de25a。脚本解析、headless Smoke、相关主场景加载通过。姿态和 D.1-B 专项均分别在 headless 与实际 Vulkan 渲染下执行，真实截图刷新；未将历史 C.3-B 31 项像素测试冒充本轮执行结果。

| 套件 | 通过 | 失败 | 失败类别 |
|---|---:|---:|---|
| 姿态融合专项 | 54 | 0 | 无 |
| D.1-B 左键方案 | 73 | 0 | 无 |
| D.1-A | 51 | 1 | 旧源码范围保护 |
| C.1 | 41 | 0 | 无 |
| C.2 | 22 | 0 | 无 |
| C.3-A | 39 | 0 | 无 |
| C.3-B 逻辑 | 41 | 0 | 无 |
| C.3-C 集成 | 84 | 1 | 旧源码范围保护 |
| 僵尸死亡姿态 | 28 | 1 | 旧源码范围保护 |
| 原始场景验证 | 42 | 0 | 无 |
| 第二轮视觉 | 21 | 1 | 历史 SHA 冻结 |
| 滚轮缩放 | 20 | 0 | 无 |
| CAD 布局/通行 | 44 | 1 | 历史 SHA 冻结 |
| 全店搜刮 | 86 | 1 | 历史 SHA 冻结 |
| 稀缺物资/高亮 | 21 | 0 | 无 |
| 中文本土化 | 16 | 1 | 历史 SHA 冻结 |
| 相机预设 | 49 | 1 | 历史 SHA 冻结 |
| 遮挡轮廓 | 49 | 1 | 历史 SHA 冻结 |
| 僵尸导航/AI | 50 | 1 | 历史 SHA 冻结 |
| **不同套件各计一次** | **831** | **10** | **十项均为源码冻结断言** |

headless 与 Vulkan 重复执行不重复累计。完整历史门禁仍返回非零，**不是全绿**。本轮没有无法执行的所列自动套件；逐项核对未发现新增功能断言失败，不据此保证所有可能操作均不存在缺陷。

原始证据均在忽略目录，未提交：

- tests/results/stage5d1_closeout_full_run.log：本轮完整执行输出。
- tests/results/stage5d1_closeout_audit.json：19 组 JSON 的汇总与全部失败原文。
- tests/results/pose_blend_validation.json、pose_blend_render.log：融合与渲染。
- tests/results/stage5d1b_validation.json、stage5d1b_render.log：左键操作及渲染。
- tests/results/stage5c3c_legacy_runs.json：十组旧套件的原始退出码。
- tests/results/stage5c2_runs/ 下本轮独立目录：C.2 原结果。

## D. 十项源码冻结失败的具体审查

这些断言均将当前文件字节 SHA 与某个旧阶段快照比较，要求差异列表为空，而非执行相应玩法再判断行为。逐项失败原因如下：

| 断言位置及名称 | 原基线 | 本次差异及分类 |
|---|---|---|
| tests/validate_visual_upgrade.gd:99 — Original assets/movement preserved except authorized camera/HUD/shelf extensions | round2_baseline_manifest.json | .gitignore、project.godot、Run.bat、player_controller.gd；七项历史失败之一 |
| tests/validate_cad_store.gd:268 — Pre-stage resources/main/controllers preserved by SHA256 | cad_baseline_manifest.json | 上述四项及 survivor_animator.gd；历史失败 |
| tests/validate_store_loot.gd:171 — Existing CAD/models/camera/colliders preserved | baseline_stage4d/manifest.json | player_controller.gd、survivor_animator.gd；历史失败 |
| tests/validate_art_localization.gd:68 — Old source models textures and core controllers preserved | baseline_stage4d2/manifest.json | 同上；历史失败 |
| tests/validate_camera_presets.gd:103 — Existing gameplay/layout/models/materials/config immutable | baseline_stage4d3/manifest.json | 同上；历史失败 |
| tests/validate_player_occlusion.gd:120 — Prior gameplay/layout/models/materials/resources preserved | baseline_stage5a/manifest.json | 同上；历史失败 |
| tests/validate_zombie_ai.gd:197 — Only authorized shared occlusion code changes among old resources | baseline_stage5b/manifest.json | 同上；历史失败 |
| tests/validate_stage5c3c_integration.gd:223 — No existing asset/config/source changes outside documented melee fix | results/stage5c3c_start_hashes.json | 玩家移动、僵尸控制器、攻击视觉、玩家反馈；白名单只认识此前命中反馈与尸体修复，不认识 D.1-A/B |
| tests/validate_stage5d1a.gd:208 — Only authorized existing zombie controller source changed | results/stage5d1a_start_hashes.json | 玩家移动、近战控制器、攻击视觉、玩家反馈；仅放行 D.1-A 僵尸控制器，故后续 D.1-B 授权改动失败 |
| tests/validate_zombie_death_pose.gd:134 — No other production source resources layout or parameters changed | results/zombie_death_fix_start_hashes.json | 五份本阶段既有源码；旧尸体修复检查仅放行 zombie_visual.gd |

实际根因证据：

1. 读取 93f9282 提交内的 STAGE_5C3C_INTEGRATION_REPORT.md，其中已记载七项历史 SHA 冻结失败，证明它们早于本次 D.1。
2. git diff 93f9282 对 .gitignore、project.godot、Run.bat、survivor_animator.gd 无差异：这些历史失败路径在 D.1 中根本没有改动。
3. 93f9282 以来既有源码只改五份，全部可对应 D.1-A/B 及姿态融合；配置、场景资产和稀缺物资数据没有混入变化。
4. 旧测试、manifest 和原 SHA 快照未修改；冻结断言外的距离/导航/战斗/库存/材质/相机行为仍执行并通过。
5. 姿态专项对本轮视觉修复前快照检查，确认仅两份视觉源码变化；D.1-B 对其阶段起点检查，确认 D.1-A、AI、数据、资源和布局保留。

因此，本轮没有发现需要为这十项冻结失败修复的实际玩法问题；它们是“此前阶段只允许改某些源码”的检查策略与后续授权实现不兼容，不能当作已通过，也不能直接删掉。

建议后续由玩家确认策略后处理：保留历史检查作为对应历史基线的审计；为当前阶段另设明确、可版本追踪的授权差异清单及参数/碰撞/资源行为不变量。不要批量把当前 SHA 覆盖成预期，也不要让新功能通过扩大白名单自动掩盖失败。results 中运行快照是本机历史数据，fresh checkout 初始化行为可能不同，不能当作跨机器的权威版本基线。本轮只记录建议，没有实施迁移。

## E. 人工验收与未逐项确认的覆盖

**玩家反馈已通过**：本轮任务中明确确认 D.1-B 左键预备攻击与短按姿态融合修复人工验收通过。此结论来自玩家反馈，不来自脚本、截图或自动 JSON。

此前报告及自动结果中的 PENDING 是当时状态或固定输出字段。本收尾记录更新上述人工结论；没有改写自动日志为“人工通过”，也没有据此推断以下操作已经逐项执行：

| 尚未逐项确认的人测操作 | 当前证据 | 跳过的具体风险 |
|---|---|---|
| D.1-A 在不同墙角、货架及窄通道反复诱导挥空/击退 | 边界、原生导航、碰撞和追近自动检查通过；没有逐路线人工记录 | 局部路径卡住、边缘转向/追近手感可能遗漏 |
| 实际键鼠连续两分钟混合短按、长按、搜索、受击 | 120s 脚本压力及各门禁通过；玩家已确认动作体验，未声称完成特定时长脚本清单 | 个别输入组合的卡住、误释放或节奏问题可能遗漏 |
| 低帧率、移动急转、不同缩放与显示器下的动作 | 60Hz 局部连续性、三视角渲染和相机回归通过；玩家确认修复 | 0.08s 快攻帧数少，峰值转动与屏幕轨迹仍可能显得集中 |

这是尚未逐项记录的覆盖范围，不是已复现未修复缺陷。现有自动核心门禁与玩家反馈支持建立可回退的原型检查点；不据此宣布正式发布质量或所有视觉环境验收通过。

## F. 检查点决策与提交范围

审查结论：未发现真实功能回归、已复现未解决的高风险缺陷、归属不明改动、凭据误提交或测试结果与收尾结论矛盾，满足用户授权的本地检查点条件。

仅通过明确列出的路径暂存本阶段五份源码、实验/验证资源、入口、测试、报告和 23 张原生渲染 PNG。不使用 git add -A 或 git add .，不提交缓存、日志、机器快照或旧右键试验备份。

检查点提交信息：

feat(combat): complete stage 5d1 melee timing and ready stance

本报告随该检查点提交；最终 Commit ID 和提交后 git status 在交付回复中给出，并记录到本地忽略的审查回执，避免在报告中预写不存在的提交哈希。未进行 push，也没有更改远端配置或仓库。

## G. 是否具备进入 Stage 5-D.2 的条件

具备继续进行下一阶段原型设计和独立验证的条件：D.1-A 距离修复、D.1-B 输入/时间规则与动画融合均有当前代码、复测和玩家反馈支撑，检查点可用于回退对照。

限制必须保留：完整历史门禁仍有十项源码冻结失败；迁移策略需另行确认。未来若要求统一 CI 全绿，应先处理测试基线职责，而不是隐藏失败。上述未逐项确认的人测项目也应继续补充。本轮未开发 D.2、新武器或特殊敌人，完成后停止。
