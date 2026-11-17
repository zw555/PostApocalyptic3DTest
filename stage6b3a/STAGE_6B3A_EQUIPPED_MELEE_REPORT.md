# After Hours · Stage 6-B.3-A：装备驱动真实近战攻击

交付日期：2026-11-18。**人工验收：PASS。玩家于 2026-11-18 确认开发、自动化测试及人工验收完成。**

本阶段完成独立住宅楼验证入口中的“主手装备 → 配置快照 → 单目标攻击 → 合法性筛选 → 伤害 → 受击/击退/死亡”链路。未进入 B.3-B，未接入住宅楼追逐导航或正式遭遇。

## A. 实施摘要与保护范围

实施前重新确认：原 A2.4-B 只有装备持握；旧近战创建 TemporaryCrowbar，默认动画与命中分别计时；玩家攻击候选清零 Y；C.3-A 有手动调度依赖。这些事实与 B.3-0 审查一致。

Git 初始状态：`main`，HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127`，tracked/staged 均无改动，**1,243 个历史 untracked 文件**。记录了 **8,721 个已有文件**的 SHA-256（排除 `.git`、`.godot` 与本阶段新增目录）。

本轮仅修改 3 个已有脚本，另新增 `stage6b3a/` 和 `RunStage6B3A.bat`。其余 **8,718 个已有文件哈希不变**，包括 InventoryModel、EquipmentModel、UI、全部物品模型/图标、玩家移动控制器、门、楼梯、碰撞、可见性、相机、旧场景和历史测试结果。

`project.godot` 默认入口未改变，仍是历史 C.2 场景。A2.4-B 原入口保留。未执行 Git 暂存、提交、推送、reset、clean 或 checkout。完整证据见 `evidence/initial_workspace.json`、`workspace_audit.json`；三份原始脚本备份位于 `evidence/originals/`，均与初始哈希完全一致。

本阶段与最终玩法的区别：

- 两个测试僵尸位于五楼楼道侧边，不追逐、不还击；复用现有僵尸模型、HP、硬直、击退及死亡。
- 保留原角色和背包初始化，不赠送武器、不修改物资箱。正常运行需按原流程到三楼取得武器后返回五楼。
- 采用普通左键按下攻击，不启用 D.1-B 长按准备/松开攻击手势；D.1-B 原入口仍保留。
- 两武器共享通用挥击。没有最终专属短刀/棒球棍动作，没有连招或群体攻击。

## B. 文件变更清单

### 修改已有文件

| 文件 | 最小修改及原因 |
|---|---|
| `scripts/combat/stage5c1_melee_attack_controller.gd` | 增加 `create_attack_visual()`、`attack_candidates()`、`candidate_is_eligible()`、`apply_target_damage()` 扩展点；默认实现保持旧行为。保留扇形、最近目标、射线、窗口跨帧和单次结算算法 |
| `scripts/ai/zombie_controller.gd` | `apply_damage()` 增加可选第四参数击退速度，旧三参数调用仍使用原 1.2m/s；将原硬直/碰撞移动块抽为 `advance_hit_response()`，原 AI 在相同位置调用，状态机未重写 |
| `scripts/survivor_animator.gd` | 增加默认 false 的 `external_right_arm_pose`；接管时跳过右臂/前臂写入，腿和左臂继续原步态，避免以处理优先级覆盖来争夺最终姿态 |

原脚本差异合计 **43 行新增、13 行删除**。完整前后 SHA-256 在 `workspace_audit.json` 的 `core_hashes`。

### 新增文件

| 文件 | 用途 |
|---|---|
| `RunStage6B3A.bat` | 独立人工验收入口 |
| `stage6b3a/scenes/gameplay.tscn` | 继承 A2.4-B 场景 |
| `stage6b3a/scripts/gameplay.gd` | 预注册测试靶、组件装配、唯一物理调度及验证 HUD |
| `stage6b3a/scripts/weapon_combat_profile.gd` | 静态武器配置、时间约束和快照接口 |
| `stage6b3a/data/knife.tres` | 短刀候选参数 |
| `stage6b3a/data/bat.tres` | 棒球棍候选参数 |
| `stage6b3a/data/training_targets.json` | 两个测试靶的位置、所属区域和允许活动范围 |
| `stage6b3a/scripts/equipped_melee.gd` | 继承旧近战，连接装备、快照、取消、间隔与有限候选集 |
| `stage6b3a/scripts/combat_domain.gd` | 真实区域、Portal 内容权限、高度和可攻击状态过滤 |
| `stage6b3a/scripts/aim_adapter.gd` | 复用旧鼠标瞄准；模态、死亡和硬直时拒绝更新 |
| `stage6b3a/scripts/action_visual.gd` | 读取物理时间的通用挥击及携带/受伤/死亡最终姿态 |
| `stage6b3a/scripts/feedback_adapter.gd` | 继承旧私有材质和受伤闪色；将姿态职责交给 ActionVisual |
| `stage6b3a/scripts/training_zombie.gd` | 继承旧僵尸；只推进原碰撞受击响应，不推进 AI/寻路 |
| `stage6b3a/tests/validate_combat.gd` | 新链路、非法目标、UI、击退与楼层移动验证 |
| `stage6b3a/tests/validate_live_input.gd` | 正常自动调度、实际 GUI 装备与鼠标攻击验证 |
| `stage6b3a/tests/capture_pose_details.gd` | 实际住宅楼相机近景检查，不是独立武器展示 |
| `stage6b3a/tests/run_tests.ps1` | 复现测试，明确区分预期冻结失败和意外失败 |
| `stage6b3a/tests/audit_workspace.py` | 允许文件、原备份、旧断言及冻结门禁前后对照 |
| `stage6b3a/tests/validate_stage5c1/5c2/5c3a/5c3b/5d1b.gd` | 旧回归副本，实际文件分别使用完整原名称 |
| `stage6b3a/tests/validate_camera_presets.gd`、`validate_player_occlusion.gd` | 旧冻结回归副本 |
| `stage6b3a/tests/a24b/{legacy_journey_ui,legacy_icon_ui,validate_hold,legacy_data,legacy_equipment}.gd` | A2.4-B 回归副本 |
| `stage6b3a/evidence/*` | 初始快照、原文件备份、日志、JSON、截图及汇总 |
| 本报告 | 实施与验收记录 |

旧测试副本仅重定向输出/继承路径，D.1-B 保留原哈希清单输入路径；未修改断言。精确映射见 `regression_fixture_map.json`，审计逐字验证。完整逐文件清单见 `workspace_audit.json`。

## C. 战斗连接与规则

```text
原背包按钮
  → EquipmentModel.equip_from / unequip_to（原子事务不变）
  → MAIN_HAND
  ├─ changed → 原 MainHandVisual → 唯一真实模型 / GripReference 掌心对齐
  └─ 起手读取 ID → WeaponCombatProfile → 本次攻击深拷贝快照
       → EquippedMelee（继承 Stage5C1MeleeAttackController）
       → 有限候选集 + 战斗空间/高度/状态过滤
       → 原扇形 + 最近合法目标 + 原实体遮挡射线
       → 原窗口跨帧检测与 attack_resolved_once
       → apply_weapon_damage → 原 apply_damage / HealthComponent
       → 原硬直、碰撞击退、受击反馈与死亡
```

### 配置与时间约束

| 参数 | 短刀 | 棒球棍 |
|---|---:|---:|
| ID | combat_knife | baseball_bat |
| 伤害 | 12 | 18 |
| 水平攻击距离 | 1.15m | 1.75m |
| 半角 | 32.5° | 47.5° |
| 前摇 | 0.12s | 0.32s |
| 命中窗口 | 0.12～0.24s | 0.32～0.48s |
| 收招 | 0.22s | 0.42s |
| 攻击间隔 | 0.46s | 0.90s |
| 击退初速度 | 0.55m/s | 2.10m/s |

击退单位是**初始水平速度**，不是承诺移动距离；实际距离取决于原 0.25 秒硬直、速度衰减和真实碰撞。

配置要求数值有限、距离/伤害为正、前摇结束等于窗口起点、窗口终点晚于起点、收招非负、间隔不短于“窗口终点＋收招”。两种候选值分别满足 `0.24+0.22=0.46`、`0.48+0.42=0.90`。实际参数只在两个资源中定义，测试中的期望值不是第二套运行配置。

起手只读取一次主手 ID。`attack_snapshot()` 返回副本，运行配置后来变化或调用者修改返回字典不会影响当前攻击。空手拒绝并显示明确提示，不使用旧默认武器造成伤害。

### 唯一时间来源和取消

- 入口 `combat_step()` 依次推进 PlayerCombat、攻击、测试靶响应；旧近战自动物理回调和训练靶 AI 回调关闭。
- 入口与控制器均检查物理帧编号，同一帧重复调用不会重复推进。
- `attack_elapsed` 只在物理驱动中推进；表现只读取该时间，不累加自己的攻击时钟。
- 保留旧窗口交叉检测：大 delta 跳过整个窗口也结算一次；仍为窗口首次交叉时单次查询，不是武器网格连续扫掠。
- 攻击间隔使用物理时钟上的绝对 deadline。装备变化、开背包、受伤和取消均不清零 deadline。
- 装备变更信号覆盖非 UI 路径：取消未命中攻击，已生效伤害不回滚；保留原快照但不得补发伤害。
- 姿态接管在装备/取消事件及物理状态更新时明确同步。旧入口保留历史默认表现和时间路径；统一计时是 B.3-A 的 opt-in 装配，不强改旧动作时序。

### 唯一表现职责

| 部位/职责 | B.3-A 所有者 |
|---|---|
| 实际模型生命周期、装备 ID | 原 MainHandVisual |
| 携带/攻击/受伤/死亡时右臂、前臂、上半身旋转 | ActionVisual；原步态通过显式开关退出对应部位 |
| 健康空手步态 | 原 survivor_animator，ActionVisual 交还控制 |
| 腿和左臂步态 | 原 survivor_animator |
| 握点内的通用攻击旋转 | ActionVisual，围绕同一掌心转动原实例 |
| 受伤材质、闪色 | 旧反馈类的适配器，只负责外观，不再写姿态 |
| 场景物体最终显隐 | 原 Coordinator；受击代码不抢 Mesh.visible |

不创建 TemporaryCrowbar；取消后回到携带/空手，受伤优先于挥击，死亡优先于受伤。死亡仍保留玩家拥有的手持物品，不做掉落或自动卸装。握点位置误差验证小于 0.00001m。

### 合法目标与场景保护

- 仅两个预配置测试靶进入候选集；不每帧扫描所有楼层或全场景敌人。
- 靶在 Coordinator 初始化之前注册，仍由原 Portal/Coordinator 管理显示。
- 玩家与目标必须同时处于靶配置的同一个实际 VisibilityZone；区域需 playable，Portal 内容权限需允许。
- 目标需在作者配置的三维活动范围内，未死亡且 attackable；根部高度差不超过 0.65m。
- 0.65m 比旧僵尸攻击的 0.75m 更保守。验证同域 0.60m 根部差仍有胶囊重叠可接受，0.70m 与上下层 3m 拒绝；真实上下楼后也因不处于同一战斗域而拒绝楼道靶。它不是通用楼梯追逐许可。
- 原水平距离、角度和实体射线在域过滤之后继续执行。相机剖切、Mesh.visible、轮廓或阴影状态均不作为攻击许可。
- 501 不属于靶的战斗域；即使开门或相机能看到楼道，也不能从安全屋内部伤害楼道测试靶。
- 靶沿楼道侧边放置，不改建筑碰撞；活靶保留原胶囊碰撞，击退使用原 move_and_slide。训练尸体保留显示并关闭其碰撞，避免阻碍探索；T 可以重置靶，不改变库存或攻击间隔。
- 旧 NavigationAgent 子节点仍由原角色创建，但训练步进不推进 think、路径查询或追逐；没有移植便利店 NavigationRegion 或导航网格。

## D. 测试结果

环境：Godot 4.5.2 stable / Vulkan Forward+ / RTX 4060 Laptop。真实游戏截图 1440×1000。

| 测试 | 结果 | 证据（evidence/） |
|---|---|---|
| 新链路 headless | **96 PASS / 0 FAIL** | `combat_headless.json` |
| 新链路真实渲染 | **96 PASS / 0 FAIL** | `combat_render.json` |
| 正常自动调度＋GUI＋鼠标 headless | **10 PASS / 0 FAIL** | `live_headless.json` |
| 正常自动调度＋GUI＋鼠标真实渲染 | **10 PASS / 0 FAIL** | `live_render.json` |
| A2.4-B 原入口 headless | **519 PASS / 0 FAIL** | `a24b/journey_ui_headless.json` |
| A2.4-B 原入口真实渲染 | **519 PASS / 0 FAIL** | `a24b/journey_ui_render.json` |
| 原库存 / 装备事务 | **34/0、19/0** | `a24b/legacy_data.json`、`legacy_equipment.json` |
| Stage5 C.1 / C.2 / C.3-A / C.3-B | **41/0、22/0、39/0、41/0** | `legacy/stage5c*_validation.json` |
| D.1-B | **72 PASS / 1 FAIL** | `legacy/stage5d1b_validation.json` |
| 旧 camera_presets | **49 PASS / 1 FAIL** | `legacy/stage4d3_validation.json` |
| 旧 player_occlusion | **49 PASS / 1 FAIL** | `legacy/stage5a_validation.json` |

覆盖要点：两种实际参数及范围/角度边界、空手、配置/返回快照隔离、前摇非 UI 换装取消、命中后换装、间隔保留、快速点击、单目标单次、大 delta、重复物理推进拒绝、实体墙、现有 501 门、跨楼层、不同战斗域、不可攻击/死亡目标、可选击退及旧三参兼容、撞墙击退、三次短刀击杀原 30HP 僵尸、UI 禁止瞄准/攻击及不补发、受伤/死亡优先、唯一真实模型、同钟动作、原生楼梯与 E 物资箱。

新入口原生行走验证了五楼经原楼梯到四楼、三楼，携带装备保持；五楼和四楼 E 领取数量不变、重复领取不复制。A2.4-B 回归另覆盖原三容器、完整上下楼返回、501/卫生间门、装备交换和满包卸下。

确定性测试使用真实场景、物理射线/碰撞、实际 HP 接收器，在受控物理时刻采样。`validate_live_input.gd` 另使用入口正常自动调度和真实 GUI/鼠标事件完成两种攻击，排除只在手动推进夹具中工作的情况。两类证据不能混称为玩家人工验收。

### 已知失败：明确区分既有与新增

1. **既有两项冻结失败**：camera_presets 与 player_occlusion 各一个旧 SHA-256 断言失败，前后路径均为 `player_controller.gd`、`survivor_animator.gd`，没有新增不匹配路径。其余各 49 项行为断言通过。
2. **本轮新增一个 D.1-B 严格冻结断言失败**：它的初始清单本轮前无不匹配，本轮后新增 `survivor_animator.gd`、`zombie_controller.gd` 两个路径，分别对应明确授权的姿态接管接口和可选击退/响应复用接口。72 项行为断言通过。这个门禁仍然失败，未扩大白名单、未改断言，也未计作通过。
3. 旧 C.3-C 的已保存 84/1 及更早 legacy 冻结记录保持字节不变；本轮没有重跑 C.3-C 长整合套件，不宣称它当前全绿。
4. 初次 D.1-B 测试副本重定向输出时误重定向了清单输入，产生 JSON 读取错误/超时；保留 `legacy/d1b_input_redirect_failure.log`，只将副本输入改回原清单后完成上述 72/1。原断言和原证据未修改。

当前最终运行日志没有新的脚本/资源错误。完整汇总见 `validation_summary.json`。结论是**行为验证通过，保留三项源码冻结失败**，不是“全部测试全绿”。验收后若需建立新冻结清单，应另行审阅，本轮不处理。

### 复现

```powershell
# 工程根目录；含已记录的冻结失败，脚本会单独识别，不将其伪装为通过。
powershell -ExecutionPolicy Bypass -File stage6b3a/tests/run_tests.ps1 -Render
python stage6b3a/tests/audit_workspace.py
```

Runner 做过语法检查；本轮各套件已按等价命令执行，未再无收益地重跑整轮。它输出原始退出码、失败断言及 unexpected 分类。不要直接运行会改写历史证据的原套件。

## E. 真实渲染与人工验收

已保存：新链路 **17 张**、正常自动运行 **2 张**、近景姿态 **12 张**，以及 A2.4-B 回归 **57 张**实际游戏截图。新链路列表带有当时装备、快照、攻击时间、间隔和目标 HP。均来自住宅楼运行实例，不是独立美术预览。

| 文件 | 内容 |
|---|---|
| `combat_knife_hit_F5/F2/F1.png` | 短刀 45°/65°/85° 命中，目标 30→18 |
| `baseball_bat_hit_F5/F2/F1.png` | 棒球棍相同三角度，目标 30→12 |
| `*_windup_65.png`、`*_recovery_65.png` | 前摇与收招 |
| `gear_change_before_hit.png`、`inventory_switch_cancels_attack.png` | 非 UI 与 UI 换装取消 |
| `controlled_zombie_death.png` | 原 30HP 测试靶被短刀击杀 |
| `attack_interrupted_by_hurt.png`、`carry_after_hurt.png` | 攻击中受伤及恢复 |
| `death_with_owned_weapon.png` | 玩家死亡、停止攻击，保留拥有的武器 |
| `B3A_carry_third_floor.png` | 新入口实际走到三楼 |
| `live_*_normal_65.png` | 正常自动调度下的实际攻击 |
| `detail_*_{carry,windup,impact}_F2/F6.png` | 原相机预设的游戏内检查近景 |

正常截图使用原相机预设；detail 只在测试中临时缩放到正交尺寸 3.0，不修改正式相机参数。截图夹具通过公共库存接口准备两件武器，并设置几何测试起点，不把这些摆位宣称为玩家连续搜刮；正常入口不提供额外物品。

![棒球棍实际前摇近景](evidence/detail_baseball_bat_windup_F2.png)

![棒球棍正常视野命中](evidence/baseball_bat_hit_F2.png)

![短刀正常视野命中](evidence/combat_knife_hit_F2.png)

### 人工运行与预期结果

1. 双击根目录 **`RunStage6B3A.bat`**。原 A2.4-B 入口不进入本阶段战斗。新运行库存按原初始化；若为空，按原路线到三楼领取武器，返回五楼。
2. I 打开背包，选中短刀/棒球棍，点击装备，关闭背包。主手模型只出现一件，UI 与角色一致。空手左键应提示先装备，不能伤害靶。
3. 五楼公共楼道侧边有两个定点测试僵尸。鼠标指向目标，左键单击：短刀每击 12、范围较短、节奏较快；棒球棍每击 18、范围较大、节奏较慢、击退明显。靶初始 30HP，短刀三击、棒球棍两击死亡。
4. 用 **T** 重置测试靶；只重置靶的 HP/位置/显示状态，不补充库存、不刷新攻击间隔。测试靶不追逐或攻击玩家。
5. 在前摇中按 I 并换装/卸下，关闭背包后不得补发。命中后换装不恢复靶 HP，也不能立即绕过原间隔再攻击。快速连点不能多结算。
6. 打开背包移动鼠标、点击 UI、按 E/WASD；不应产生新瞄准、挥击或世界交互。关闭后控制恢复。
7. F5=45°、F2=65°、F1=85°，观察前摇、命中、收招、转身；通过楼梯后不能攻击五楼靶；隔墙/隔闭门不能伤害目标，501 内部不能刷楼道伤害。
8. 攻击中按 **H**，通过旧玩家受击接口自测 10 点伤害，应中断攻击并显示受伤。保护时间内重复伤害会拒绝。按 **J** 自测致死，死亡后不能攻击/E 交互；武器保持拥有状态。死亡后关闭窗口重新运行，不增加复活或存档系统。
9. 回到原 A2.4-B 入口，复查携带、交换、卸下、门、容器和楼梯；该入口仍保持原行为，不出现测试靶。

H/J/T 是独立验证入口的测试操作，不是正式战斗技能或奖励。测试期间不要将 UI 点击误认为攻击；真实渲染自动测试运行时避免人工抢鼠标/最小化测试窗口。

不充分验收的后果：跳过换装可能遗漏延迟伤害/冷却利用；跳过楼梯和门口可能遗漏跨层攻击或非法空间授权；跳过多角度和受伤/死亡可能遗漏手部错位、遮挡及姿态接管问题。自动化不能证明玩家认可动作节奏和接触感。

## F. 剩余问题与停止范围

### 本阶段阻塞问题

没有发现阻断八项完成标准的行为问题；新链路、计时、换装/UI、非法目标及旧入口行为验证通过。**严格源码冻结门禁未全绿**，其中 D.1-B 新增的接口哈希差异明确保留，不能自动重建基线或隐瞒。

### 可留到 B.3-B 的动作问题

- 两武器仍共用通用挥击，未制作各自专属轨迹、精细手指或双手握棍。
- 实际伤害仍为原扇形/射线判定，不是武器网格扫掠；动画接触感、接触距离和各方向节奏需人工反馈后细化。
- 短刀真实尺寸较小，命中时可能被靶身体遮挡；F6 近景也可能被原门叶/墙体遮挡。未修改相机或建筑来改善截图。
- 未做贴墙收棍、武器环境碰撞或挥击避障；棍端靠墙可能穿入环境。角色和击退本体仍遵守原物理碰撞。

### 可留到 B.5 的遭遇问题

- 测试靶没有追逐、还击或跨区活动，不代表住宅楼僵尸导航已经接入。
- 当前战斗域保守限制在配置的同一楼道区域，楼梯战斗及跨区敌人尚未开放。
- 动态敌人换区、导航、安全屋完整遭遇边界、尸体管理和关卡投放仍需独立设计验证。
- 未实现存档、耐久、体力、暴击、流血、群攻、新敌人类型或新楼层。

本轮未做严格性能 A/B 基准，不用截图瞬时 FPS 宣称性能结论；旧入口无新增靶或调度开销，有限靶候选不扫描全部楼层。

**B.3-A 人工验收已通过，在此停止，不自动进入 B.3-B。2026-11-18 玩家另行授权阶段性 Git 整理、提交和安全推送；归档范围与复现说明见 `VERSIONING_NOTES.md`。**
