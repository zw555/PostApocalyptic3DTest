# Stage A2.4-B：武器装备与角色持握

日期：2026-11-17。

**Stage A2.4-B 开发完成，等待玩家人工验收。**

前置状态：玩家已确认 A2.3、A2.4-A 人工验收通过。本阶段新增主手持握表现及独立入口，复用原背包和装备事务；不接入攻击，不修改武器模型本体。

## 1. 只读审查结论

| 检查项 | 工程实际情况 | 本阶段处理 |
|---|---|---|
| 当前玩家 | `scenes/player/player_visual_v2.tscn`，CharacterBody3D + `survivor_visual.tscn` | 原场景不改 |
| 角色组成 | 分批网格；Visual 下有 UpperBody、左右手臂、前臂、腿与脚；无 Skeleton3D | 复用右前臂层级 |
| 手部 | 手套几何已合并到 `RightArm/Forearm/Batch_survivor_leather`；不是独立手指骨骼 | 在手掌中心增加 Node3D 挂点 |
| 现有动画 | `survivor_animator.gd` 每帧写手臂与前臂的步行摆动 | 新适配器在其后写静态持握姿态，不改原动画脚本 |
| 主手装备 | `equipment_model.gd` 已有 MAIN_HAND、装备/交换/卸下、原子事务、变更信号 | 全部复用；表现层只读装备 ID |
| 背包 UI | A2.4-A 图标面板；I/Esc、选中、装备、卸下均已实现 | 原脚本、图标、容量、UI 原样保留 |
| 武器资源 | 棒球棍与短刀均为可独立实例化的纯视觉 PackedScene，已有 GripReference | 直接实例化资源，不重新运行建模器 |
| 移动与转身 | `player_controller.gd` 用相机相对方向移动，旋转 Visual；住宅楼使用移动朝向 | 武器挂在 Visual/右前臂下，自动继承移动、转向和高度 |
| 鼠标瞄准 | 旧 Stage 5 战斗场景有独立 AimController；住宅楼入口未装配该组件 | 不新增瞄准，不改变现有转向方式 |
| 近战控制器 | 旧 `stage5c1_melee_attack_controller.gd` 使用既有攻击判定及临时武器表现，没有读取本次 EquipmentModel | 不接入或修改；留待单独授权阶段处理 |
| 住宅楼战斗状态 | 当前继承入口的 `player.combat_component` 为 null；既有战斗系统存在于其他场景 | 不为了持握而新增战斗、敌人或动画 |

不存在必须修改背包事务、角色骨架或伤害核心的架构冲突。需要的最小扩展仅为：装备 ID → 持握配置 → 源模型实例，以及原步态之后的右臂局部姿态。

## 2. Git 与成果保护

- 分支 `main`；HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127`。
- 实施前 tracked diff、staged diff 均为空，存在 **1,153 个历史 untracked 文件**。
- `evidence/initial_workspace.json` 记录完整初始 Git 状态及 **8,619 个已有文件**的 SHA-256，排除 `.git`、`.godot` 缓存及本阶段新增目录。
- 最终这些已有文件均未修改或删除。保护范围包括 A2.3、A2.4-A 全部文件、六种模型、PNG 图标、InventoryModel、EquipmentModel、UI、玩家、动画、门、E Broker、楼梯、可见性、相机、旧近战与僵尸代码。
- 只新增 `stage_a24b/` 及根目录 `RunStageA24B.bat`。没有 Git 暂存、提交、推送、reset 或 clean。

逐文件记录见 `evidence/workspace_audit.json`，可通过 `python stage_a24b/tests/audit_workspace.py` 只读复核。

## 3. 持握实现

新入口继承 A2.4-A 场景，复用相同的 InventoryModel、EquipmentModel、图标 UI 和三个容器。在玩家树中装配 `EquipmentPresentation`，并在 `Visual/RightArm/Forearm` 下建立 `MainHandSocket`。

挂点位于前臂局部 `(0, -0.275, -0.012)` 米，与现有手套掌心范围一致。源角色生成器中的手套范围约为前臂局部 Y=-0.217～-0.325 米；未改动手套几何。

| 配置 | 棒球棍 | 短刀 |
|---|---|---|
| 装备 ID | baseball_bat | combat_knife |
| 源场景 | `item_art_a2_1/baseball_bat/model/baseball_bat_visual.tscn` | `item_art_a1/combat_knife/model/combat_knife_visual.tscn` |
| 源握点 | GripReference，局部 Z=-0.045 米 | GripReference，局部原点 |
| 持握方式 | 右手低位单手持握，棍身朝前外侧，避免 65° 下过度缩短 | 右手正握，刀刃朝前外侧，调整腕部展示刃面 |
| 原始尺寸 | 长约 0.82 米 | 总长约 0.286 米 |
| 缩放 | 1:1 | 1:1 |

配置位于 `bat_hold.tres`、`knife_hold.tres`；仅保存展示场景、握点、手臂旋转和模型相对旋转，没有伤害、数量、耐久或存档状态。

同步规则：

1. 唯一事实来源为 `equipment.equipped_item_id()`，不读取 UI 文本或按钮状态。
2. 订阅原装备变更信号。装备事务完成后读取 ID，释放旧实例，再创建对应源场景。
3. 使用源 `GripReference` 的逆变换对齐掌心，保持 Mesh、材质及模型比例不变。
4. 相同 ID 的重复通知复用当前实例；空主手移除模型，恢复原空手姿态控制。
5. 挂点属于前臂子树；没有逐帧设置武器世界坐标，也没有独立插值追赶玩家，因此不会产生位置跟随延迟。
6. 局部持握适配器优先级 20，原步态为 0。装备时仅覆盖右臂/右前臂旋转，左臂、腿、身体步态及碰撞不变；卸下后继续由原动画驱动。
7. 适配器每帧只写两个局部旋转，不扫描场景、不查询库存、不重建模型。模型创建/替换发生在装备变更时。
8. 武器没有新增碰撞体、攻击区域或命中逻辑。它属于玩家装备表现，不作为静态楼层内容注册，不改变 Portal 或 Coordinator 权限。

适配器遇到已存在的 combat_component 时不会持续覆盖其手臂姿态。未来战斗接入仍需明确处理旧临时武器和最终姿态所有权；本阶段没有将这项兼容保护宣称为攻击系统集成完成。

## 4. 自动化验证

环境：Godot 4.5.2 stable；真实渲染为 Vulkan Forward+ / RTX 4060 Laptop；截图分辨率 **1440×1000**。

| 验证 | 最终结果 | 文件 |
|---|---|---|
| 独立入口、资源及语法加载 | 通过，无脚本错误 | `entry_smoke.log`、实际行程日志 |
| 原库存数据 | **34 PASS / 0 FAIL** | `legacy_data.json` |
| 原装备事务 | **19 PASS / 0 FAIL** | `legacy_equipment.json` |
| 完整 headless 行程与 UI/持握 | **519 PASS / 0 FAIL** | `journey_ui_headless.json` |
| 完整真实渲染行程与 UI/持握 | **519 PASS / 0 FAIL** | `journey_ui_render.json` |
| 修正后的拍照避障路线 | **3 PASS / 0 FAIL** | `photo_route.json` |
| 原文件与旧断言保护 | 通过 | `workspace_audit.json` |

完整行程从 501 出发，通过原 E 交互与真实 CharacterBody3D 移动下楼，领取原三个容器的六种物品，通过实际 UI 鼠标点击装备，再持棍从三楼返回四楼、五楼和 501。最终 501 对比图没有通过传送或发放武器伪造行程；使用原领取库存及原装备事务。

覆盖：

- 初始空手、装备棒球棍、换短刀、卸下恢复空手、重新装备。
- 装备时背包移出该武器；交换后旧武器回包；卸下后两种武器各一件；不存在的背包武器或错误 expected ID 被拒绝，显示和数据不变。
- 多次通知不创建重复实例；模型 ID 与真实装备一致，关闭/重新打开背包后保持。
- 原物品选择、六种图标、12 槽、数量更新、满包拒绝、重复领取、缺图占位、输入阻断/恢复及原 UI 装备原子事务。
- 移动、四方向转身、45°/65°/85° 镜头、三→四→五楼楼梯、返回 501。
- 501 门、楼梯门、卫生间门和跨楼层容器权限回归。
- 实例与原场景共享相同 Mesh/材质资源，内部 Mesh 变换不变，模型缩放为 1，无新增武器物理碰撞。

连续持握采样：

| 模式 | 持握采样帧 | 其中移动帧 | 最大握点偏差 | 最大同时实例数 |
|---|---:|---:|---:|---:|
| Headless | 5,624 | 3,166 | 0.000000954 米 | 1 |
| 真实渲染 | 9,346 | 5,443 | 0.000000477 米 | 1 |

原始指标见 `hold_metrics_headless.json`、`hold_metrics_render.json`。帧数随 GPU/调度变化；测试使用误差及状态约束，不要求两种模式帧数相等。握点误差检验不能替代所有角度下的视觉穿插检查。

保留的非通过记录：

- 首轮新增转向目标越过三楼后墙，原碰撞正确阻止：463 PASS / 1 FAIL，见 `initial_journey_*.log`。只调整测试的可通行目标，没有改建筑。首轮附加结果与继承测试的输出文件发生尾部混写，原文件仍保留；最终使用结束钩子统一输出结果及独立指标文件。
- 第二轮附加拍照路线直穿茶几，headless 为 516 PASS / 3 FAIL，见 `photo_route_first_journey_*`。仅将路线改为先绕茶几北侧，再沿西侧行走，三段独立路线检查及最终完整行程均通过。
- 中间一次真实渲染因测试窗口被最小化，等待出图而中断，日志见 `interrupted_minimized_render.log`。新增截图前恢复测试窗口的保护后重新完整运行；正式游戏窗口配置不变。
- 原有历史两项冻结哈希失败记录没有覆盖、没有更改旧断言制造通过，也不宣称本轮将其修复。

测试副本保留旧断言：数据/装备仅改输出目录；行程仅改入口/输出目录并增加结束钩子，以便追加真实游戏持握检查；图标测试仅改本阶段测试继承路径与输出目录。审计脚本逐字检查这些允许的差异，原测试文件均保持哈希不变。

复现（工程根目录）：

```powershell
$godotBin = 'E:/Godot_v4.5.2-stable_win64.exe/Godot_v4.5.2-stable_win64_console.exe'
& $godotBin --headless --path . --script res://stage_a24b/tests/legacy_data.gd
& $godotBin --headless --path . --script res://stage_a24b/tests/legacy_equipment.gd
& $godotBin --headless --path . --script res://stage_a24b/tests/validate_hold.gd
& $godotBin --path . --resolution 1440x1000 --script res://stage_a24b/tests/validate_hold.gd
python stage_a24b/tests/audit_workspace.py
```

真实渲染行程需要保持测试窗口可绘制，自动点击期间避免人为干预鼠标/键盘。原测试中的攻击接收器只是输入穿透探针，不是新增攻击功能。

## 5. 真实游戏截图

最终行程记录 **57 张**住宅楼运行截图，见 `journey_ui_render.json` 的 `captures`，包含当时装备、库存、区域、握点偏差及武器世界变换。所有下列主图均来自连续行程的最终 501 位置。

| 文件 | 内容 |
|---|---|
| `final_bat_501_normal_F5.png` / `F2.png` / `F1.png` | 棒球棍，45°/65°/85°，正常游戏视野 |
| `final_knife_501_normal_F5.png` / `F2.png` / `F1.png` | 短刀，同三个正常镜头角度 |
| `final_empty_501_normal_65.png` | 同一位置卸下后，65° 空手对比 |
| `final_bat_501_detail_65.png` | 65° 实际游戏相机近景，检查握柄/手掌关系 |
| `final_knife_501_detail_65.png` | 65° 实际游戏相机近景，检查刀刃方向 |
| `final_bat_501_reopened_ui.png` | 重开原背包，主手 UI 与角色装备一致 |
| `hold_06_turn_*.png` | 原平台上的原生移动转向 |
| `hold_07_up_fourth_*.png`、`hold_07_up_fifth_*.png` | 持棍通过楼梯返回上层 |

正常截图使用原相机预设与 view_size=9.2；detail 图只在测试中将游戏相机正交尺寸临时设为 3.0，随后恢复，未修改正式相机配置。独立 `inspect_*.png` 是早期真实关卡取景辅助，使用测试起始摆位/公共库存填充，不作为连续领取行程的证明；最终主图不依赖这些辅助图。

正常 65° 棒球棍：

![正常游戏视野手持棒球棍](evidence/final_bat_501_normal_F2.png)

游戏内近景对照：

![棒球棍持握](evidence/final_bat_501_detail_65.png)

![短刀持握](evidence/final_knife_501_detail_65.png)

![相同位置卸下恢复空手](evidence/final_empty_501_normal_65.png)

## 6. 修改文件清单

**修改已有文件：0。** 新增文件：

| 路径 | 用途 |
|---|---|
| `RunStageA24B.bat` | 人工验收启动入口 |
| `stage_a24b/scenes/gameplay.tscn` | 继承 A2.4-A 的场景 |
| `stage_a24b/scripts/gameplay.gd` | 挂点表现装配 |
| `stage_a24b/scripts/main_hand_visual.gd` | 装备信号、模型同步、局部持握 |
| `stage_a24b/scripts/weapon_hold_profile.gd` | 展示用 Resource 接口 |
| `stage_a24b/scripts/bat_hold.tres` | 棒球棍持握配置 |
| `stage_a24b/scripts/knife_hold.tres` | 短刀持握配置 |
| `stage_a24b/tests/validate_hold.gd` | 连续真实行程、装备与持握验证 |
| `stage_a24b/tests/legacy_journey_ui.gd` | 旧行程测试副本及追加结束钩子 |
| `stage_a24b/tests/legacy_icon_ui.gd` | 原图标 UI 用例副本 |
| `stage_a24b/tests/legacy_data.gd`、`legacy_equipment.gd` | 原数据/装备回归副本 |
| `stage_a24b/tests/inspect_hold.gd` | 游戏内早期取景辅助 |
| `stage_a24b/tests/validate_photo_route.gd` | 取景路线的独立碰撞检查 |
| `stage_a24b/tests/audit_workspace.py` | 原文件和断言保护检查 |
| `stage_a24b/STAGE_A24B_WEAPON_HOLD_REPORT.md` | 本报告 |
| `stage_a24b/evidence/*` | 初始审计、日志、结果、指标及截图 |

完整逐文件清单见 `workspace_audit.json`。未来整理 Git 时可将展示资源/脚本及入口作为一组、测试和报告作为另一组，逐路径审阅；本轮不执行暂存或提交。

## 7. 人工验收入口与步骤

运行根目录 **`RunStageA24B.bat`**。A2.3 和 A2.4-A 原入口继续保留原表现。

1. 新运行沿用原库存初始化，不额外赠送武器。如背包为空，按原路线到三楼器材箱领取短刀和棒球棍。
2. I 打开背包，单击棒球棍，点击“装备选中武器”，关闭背包。确认手中出现棍，握柄贴近右手，没有悬浮或明显穿身。
3. WASD 行走、停止、四向转身；切换 F5=45°、F2=65°、F1=85°。重点判断 65° 下棍身是否容易识别、跟随是否稳定。
4. 携带棒球棍上下楼梯，经过转角、门口、护栏和三层平台，返回 501；重新打开背包，核对主手与角色表现。
5. 将棒球棍换为短刀：旧棍回背包、手中仅一把刀，刀刃朝向合理；再换回棒球棍，重复数次。
6. 卸下武器：手中模型消失，物品回包，空手步态恢复；关闭再打开背包，状态保持正确。
7. 再检查 501、卫生间门的 E 交互、重复领取及背包模态输入，确认持握没有影响原功能。

## 8. 已知问题与后续建议

- 角色是现有分块程序化模型，手套没有独立手指。当前是掌心与握柄对齐的单手持握，不包含精细抓握手型或双手 IK。
- 武器保持真实尺寸。短刀在正常远景下像素较少，85° 或特定朝向会发生透视缩短；未放大模型弥补辨识度，需要玩家实际判断可接受程度。
- 没有增加武器环境碰撞、贴墙收棍或避障。贴墙/靠护栏时棍端可能被遮挡或穿入环境；首次门口取景已观察到这种遮挡。玩家本身仍由原胶囊碰撞保护。本阶段没有改变墙、护栏或碰撞来隐藏问题。
- 当前检查未观察到明显脱手或躯干穿插，但所有环境位置和视角仍需人工体验。不要把握点误差接近零等同于所有视觉问题都已验收。
- 旧近战控制器、临时武器和新装备显示尚未整合；本阶段不提供新的挥击、伤害差异或持握攻击。下一阶段若获授权，应先明确攻击时的姿态所有权和旧临时武器替换，再复用原判定，避免重复武器或两个系统同时写手臂。
- 未更改存档格式、装备规则或相机参数。未执行严格性能 A/B 基准，不用截图的瞬时 FPS 宣称性能结论。

跳过交换/卸下测试可能遗漏模型与装备状态不同步；跳过楼梯及转向测试可能遗漏挂点方向或环境遮挡问题。**本阶段在此停止，等待玩家人工验收。**
