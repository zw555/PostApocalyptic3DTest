# Stage A2.4-A：背包物品图标与 UI 可视化

日期：2026-11-17。状态：**等待玩家人工验收**。

玩家已确认 A2.3 人工验收通过。本阶段仅新增图标生成、贴图缓存、背包表现层和独立入口。没有修改任何已有文件；六种模型、A2.3 入口、物品定义、库存、装备、输入仲裁、门、相机、楼梯、可见性和战斗脚本均保留。

## 1. 实施前只读检查

- Git 分支 `main`，HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127`。
- tracked diff、staged diff 均为空。已有 **1,102 个 untracked 文件**，均作为历史成果保留。
- `evidence/initial_workspace.json` 记录实施前完整状态及 **8,558 个文件**的 SHA-256（排除 `.git`、`.godot` 缓存）。其中包括历史证据及未跟踪文件，并非仅检查 Git tracked 文件。
- 六种 `data/items/*.tres` 已有稳定 ID、名称、分类和堆叠上限。`ItemDefinition.icon` 为可选 `Texture2D`，当前六种定义均未配置图标；本阶段不改写它们。
- `InventoryModel` 是唯一数量来源，12 槽、快照隔离、变更信号和原子转移均已实现。
- `EquipmentModel` 已支持主手装备、交换、卸下及失败回滚。本阶段沿用，不接入持握模型或实际攻击。
- 原 `inventory_equipment_panel.gd` 生成 4×3 文字按钮，订阅库存和装备变更信号。新增面板继承其选择、详情、装备按钮和操作逻辑。
- B.2-A 已有 I/Esc、模态输入隔离与恢复；B.1 E Broker 和三个配置化容器继续复用。
- A2.3 入口已包含三个物资箱及罐头、水瓶、电池的游戏内表现；本阶段继承它，不新增地面掉落或场景摆放。

## 2. 图标来源与生成方式

全部使用项目已验收的实际 PackedScene 实例，不执行原建模脚本，不修改网格、材质、UV 或模型原点。

| ID | 背包名称 | 实际模型路径（res://） | 图标俯角 / 构图 |
|---|---|---|---|
| combat_knife | 短刀 | item_art_a1/combat_knife/model/combat_knife_visual.tscn | 65°，对角线 |
| baseball_bat | 棒球棍 | item_art_a2_1/baseball_bat/model/baseball_bat_visual.tscn | 70°，对角线 |
| bandage | 绷带 | item_art_a2_2/models/bandage/bandage_visual.tscn | 55°，显示卷芯 |
| battery | 电池 | item_art_a2_2_r1/models/battery/battery_visual.tscn | 32°，显示正极与主体 |
| water_bottle | 瓶装水 | item_art_a2_2_r1/models/water_bottle/water_bottle_visual.tscn | 28°，显示蓝盖与标签 |
| canned_food | 罐头 | item_art_a2_2_r1/models/canned_food/canned_food_visual.tscn | 45°，显示平放拉环与包装 |

输出：`stage_a24a/icons/<item_id>.png`，共六张 **128×128 RGBA、透明背景** PNG。

生成器采用 Godot 4.5.2 的独立 SubViewport：512×512、4× MSAA、统一环境光和两盏方向光、Filmic 色调映射，无地面、无背景模型。扫描源 Mesh 的变换后顶点，投影到相机坐标系，自动适配正交相机并预留约 8% 边距。长条武器旋转相机画面构图，不改变模型。

最终由 Godot Image 使用 Lanczos 缩小至 128×128，再写 PNG；运行时只加载这六张图片，不为槽位创建实时 3D 渲染。

重复执行：双击 `stage_a24a/GenerateIcons.bat`，或在工程目录运行：

```powershell
& 'E:/Godot_v4.5.2-stable_win64.exe/Godot_v4.5.2-stable_win64_console.exe' --path . --resolution 512x512 --script res://stage_a24a/tools/render_icons.gd
```

生成需要 GPU 渲染，不能使用 `--headless`。输出及相机参数见 `evidence/icon_manifest.json`。两次完整生成的六张 PNG **逐字节哈希一致**，见 `evidence/icon_repeatability.json`。

总览背景棋盘格仅用于检查透明边缘，不存在于正式图标内。六张图标 alpha 范围均为 0–255，四角 alpha 均为 0，alpha > 16 的轮廓均未触及边界，约保留 10–14 像素边距。

![六种实际模型生成的图标](evidence/icons_overview.png)

## 3. UI 与数据关系

- 新入口继承 A2.3 场景，在首帧之前用图标面板替换原文字面板；使用**同一份**运行时 `player_inventory` 和 `equipment` 对象。
- 仍是 4×3、12 个原有 Button。增加 100×100 的等比例 TextureRect、名称、右上数量、槽号和统一空槽背景。
- 图标和文字子控件忽略鼠标事件，点击继续由原 Button 处理；没有拖拽、拆分、快速转移或新增堆叠规则。
- 每次库存/装备变更时读取原快照刷新。UI 不维护独立数量，不从 HUD 文本反推数据。静止时不会每帧刷新。
- `icon_library.gd` 优先采用定义中已有的 `icon`；为空时按稳定 ID 从本阶段图标目录加载并缓存。当前六种定义无需修改，保留 A2.3 资源依赖。
- PNG 缺失或解码失败时缓存统一占位图，同时保留物品名称和数量；不会导致整个 ItemDefinition 加载失败。
- 当前工程直接使用 Godot Image 解码 PNG 并创建 ImageTexture，因此无需先运行全工程导入。没有外部图片服务或运行时第三方依赖。
- 主手装备、交换和卸下仍由原 EquipmentModel 事务执行。I/Esc、UI 点击阻断世界行为、E 仲裁均来自原入口。

## 4. 实际修改文件清单

**已有文件修改：0。** 下列均为本阶段新增：

| 路径 | 用途 |
|---|---|
| `RunStageA24A.bat` | 独立游戏入口 |
| `stage_a24a/GenerateIcons.bat` | 可重复执行图标批处理 |
| `stage_a24a/tools/icon_sources.gd` | ID、实际模型路径及取景配置 |
| `stage_a24a/tools/render_icons.gd` | Godot 离线批量渲染 |
| `stage_a24a/icons/combat_knife.png` | 短刀图标 |
| `stage_a24a/icons/baseball_bat.png` | 棒球棍图标 |
| `stage_a24a/icons/bandage.png` | 绷带图标 |
| `stage_a24a/icons/battery.png` | 电池图标 |
| `stage_a24a/icons/water_bottle.png` | 瓶装水图标 |
| `stage_a24a/icons/canned_food.png` | 罐头图标 |
| `stage_a24a/scripts/icon_library.gd` | 图标缓存和安全占位 |
| `stage_a24a/scripts/icon_inventory_panel.gd` | 原面板的图标表现扩展 |
| `stage_a24a/scripts/gameplay.gd` | A2.3 场景装配扩展 |
| `stage_a24a/scenes/gameplay.tscn` | 新入口场景 |
| `stage_a24a/tests/validate_icon_ui.gd` | 图标、空槽、数量、缓存及回归检查 |
| `stage_a24a/tests/legacy_journey_ui.gd` | 原 B.2-A 用例副本，仅重定向场景和输出路径 |
| `stage_a24a/tests/legacy_data.gd` | 原库存用例副本，仅重定向输出路径 |
| `stage_a24a/tests/legacy_equipment.gd` | 原装备用例副本，仅重定向输出路径 |
| `stage_a24a/tests/audit_workspace.py` | 只读工作区哈希与测试副本核对 |
| `stage_a24a/STAGE_A24A_INVENTORY_ICON_UI_REPORT.md` | 本报告 |
| `stage_a24a/evidence/*` | 初始状态、日志、测试结果、截图和审计证据 |

逐文件完整列表见 `evidence/workspace_audit.json`。不在上述目录中新增业务文件。未暂存、提交、推送或执行 reset/clean。

## 5. 自动验证与真实渲染

执行环境：Godot **4.5.2 stable**，真实渲染为 Vulkan Forward+ / NVIDIA RTX 4060 Laptop，游戏截图 **1440×1000**。

| 验证 | 结果 | 证据 |
|---|---|---|
| 六种实际模型加载与离线图标渲染 | 6/6 | `render_icons.log`、`icon_manifest.json` |
| 图标重复生成 | 六张 SHA-256 完全一致 | `icon_repeatability.json` |
| 尺寸、RGBA、透明四角、未裁切 | 6/6 | `icon_pixels.json`、运行测试 |
| 原库存数据回归 | **34 PASS / 0 FAIL** | `legacy_data.json` |
| 原装备事务回归 | **19 PASS / 0 FAIL** | `legacy_equipment.json` |
| Headless 完整交互/UI 行程 | **298 PASS / 0 FAIL** | `journey_ui_headless.json` |
| 真实渲染完整交互/UI 行程 | **298 PASS / 0 FAIL** | `journey_ui_render.json` |
| 独立入口启动 | 通过，无脚本错误 | `entry_smoke.log` |
| 旧文件、Git HEAD/索引保护 | 8,558 个已有文件哈希不变 | `workspace_audit.json` |

覆盖：空背包；12 个槽位；六种 ID/名称/数量/图标；实际五→四→三楼容器领取；满包原子拒绝；重复 E 不复制；图标自动更新；实际鼠标点击选择、装备短刀、交换棒球棍、卸下；满包卸下不丢物；连续点击；I/Esc/关闭按钮及反复开关；模态移动/E/鼠标攻击探针阻断；关闭后恢复；门、卫生间门、楼梯往返；F1/F2/F5/F6；缺失图标占位与恢复；缓存复用；背包 UI 不创建 SubViewport。

旧用例中的攻击接收器仅为测试探针，不是新增或接入战斗系统。原测试断言未更改；审计脚本逐字验证副本只替换入口及输出路径。历史两项冻结哈希失败记录未覆盖、未改为通过，也未冒称本轮重新验证通过。

首轮 headless 与渲染各有 **297 PASS / 1 FAIL**：新增断言误检查整个游戏子树是否无 SubViewport，将原场景的既有功能计入。本阶段仅要求**背包 UI**无实时 3D 视口，因此将此条新断言范围修正为 UI 子树。未修改实现掩盖问题，随后完整重跑通过。首轮原始结果和日志保存在 `initial_journey_*` 中。

重跑命令（工程根目录，两个行程测试依次执行）：

```powershell
$godotBin = 'E:/Godot_v4.5.2-stable_win64.exe/Godot_v4.5.2-stable_win64_console.exe'
& $godotBin --headless --path . --script res://stage_a24a/tests/legacy_data.gd
& $godotBin --headless --path . --script res://stage_a24a/tests/legacy_equipment.gd
& $godotBin --headless --path . --script res://stage_a24a/tests/validate_icon_ui.gd
& $godotBin --path . --resolution 1440x1000 --script res://stage_a24a/tests/validate_icon_ui.gd
python stage_a24a/tests/audit_workspace.py
```

运行时仅缓存六张 128×128 RGBA 图，像素数据合计约 **384 KiB**（不含驱动开销）；绘制使用普通 Control。未进行严格 FPS A/B 基准，不以截图中的瞬时 FPS 作性能结论。

## 6. 游戏运行截图

共 18 张真实游戏运行截图，文件与当时库存/装备状态在 `journey_ui_render.json` 的 `captures` 中记录。均来自住宅楼运行入口，不是美术预览。

- `pause_door.png`：501 门口空背包。
- `pause_slope.png`：楼梯上暂停、已领取水与绷带。
- `01_six_items.png`：三楼领取完成，六种物品、原始配置数量。
- `02_knife_equipped.png`、`03_bat_equipped.png`、`04_unequipped.png`：原装备流程。
- `05_full_refused.png`：通过测试公共库存接口填满背包，卸下失败且数据不变。此填充仅存在于测试，不是游戏奖励。
- `06_missing_icon_safe_fallback.png`：测试临时失效图标目录后的安全占位。
- `07_six_icons_selected_knife.png`、`08_reopened_inventory.png`：详情选择及重开后的状态。
- `inventory_F1/F2/F5/F6.png`、`world_F1/F2/F5/F6.png`：原相机视角回归。

![住宅楼实际运行，领取六种物品后打开背包](evidence/01_six_items.png)

## 7. 人工验收步骤及已知限制

1. 双击根目录 `RunStageA24A.bat`。在 501 按 I：确认 12 个统一空槽，Esc 或关闭按钮可关闭。
2. E 开门，五楼领取水和绷带；四楼领取电池和罐头；三楼领取短刀和棒球棍。每处开关背包，确认图标、名称、数量刷新。重复领取不会增加数量。
3. 六种原始数量应为：水 2、绷带 2、电池 3、罐头 2、短刀 1、棒球棍 1。单击各物品，确认详情与选择目标一致，轮廓在正常窗口下可辨认。
4. 装备短刀，再交换棒球棍，再卸下；确认图标随物品转移而变化，不丢失或复制。此阶段主手只显示文字状态，角色不持械。
5. 打开背包时按 WASD、E、点击物品和空槽；确认人物静止，不误开门或领奖。关闭后立即移动和交互，再快速开关数次。
6. 在门口及楼梯平台重复操作，并检查 F1/F2/F5/F6 下返回游戏是否正常。
7. 满包与缺图案例已自动验证，可查看 `05_full_refused.png`、`06_missing_icon_safe_fallback.png`；完整重现运行上述验证脚本。正常入口不额外提供测试物资或调试面板。

已知限制：

- 小图以轮廓和材质识别为主，中文包装细字及细微磨损在 100px 槽位显示下不能完整阅读；本阶段不重绘或放大模型细节。
- 验证分辨率为 1440×1000，沿用旧面板固定最小尺寸；极小窗口及不同系统 DPI 的可读性尚待人工确认。
- 当前工程运行与 PNG 源文件读取已验证；发布导出包尚未验证。未来导出时需要保留图标 PNG 原文件，或使用 Godot 导入后的 Texture2D 加载路径。
- 自动测试不能替代玩家对图标辨识度、明暗、名称字号和操作手感的判断。跳过装备交换和 UI 输入验收，可能遗漏未来战斗接入时的误操作问题。

完成范围止于 A2.4-A。未新增持握、攻击、动画、掉落、拖拽、拆分、存档或其他玩法。**等待玩家人工验收，不自动推进下一阶段。**
