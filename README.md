# AFTER HOURS — Godot 4.5.2 独立 3D 美术验证

12m × 10m 废弃便利店，原生 Mesh、GDScript、GodotPhysics3D。无插件、下载模型、外部素材或 Blender 运行依赖。此项目位于 `E:\GameProject\PostApocalyptic3DTest`，与现有游戏目录并列。

## 开始运行

本机直接双击 `Run.bat`。或在 Godot **4.5.2** 项目管理器导入本目录的 `project.godot`，按 F6 运行 `scenes/main.tscn`，或按 F5 运行项目。默认采用 Forward+ / Vulkan；本机已用 RTX 4060 Laptop GPU 运行并截图。

项目交付的是完整 Godot 源工程，不是导出的独立 EXE。`Run.bat` 优先查找本机已安装的 Godot 路径，移动到其他电脑后可通过 Godot 编辑器直接打开。

| 操作 | 功能 |
| --- | --- |
| WASD | 沿相机水平投影方向移动，斜向归一化 |
| F1 | 正交 85° 俯视 |
| F2 | 正交 65° 斜俯视，默认模式 |
| F3 | 开关两盏局部灯光 |
| F4 | 开关全部三盏光源的动态阴影 |
| 滚轮向上 / 向下 | 平滑拉近 / 拉远正交视野；UI 已消费的滚动不触发相机 |
| Home | 平滑恢复启动时的默认缩放 |
| R | 返回出生点，重置平滑相机位置 |

角度相对水平地面。两种模式保持相同目标点，默认正交视野高度为 13.8m；滚轮调整后在 F1/F2 之间保留当前缩放。为完整观察店内，跟随目标有固定偏移 `(0, 0.75, -2.3)`；没有自由旋转或透视缩放。85° 下竖直人体会自然缩短为接近头顶的轮廓，这属于真实投影变化。

门洞在东侧 `X=6, Z=2.8`，净宽 1.2m。墙体与货架是真实静态碰撞体。门外只有一小块验证平台，使用 R 可随时返回；本轮没有室外地图。

## 在编辑器中搭建

- 打开 `scenes/environment/convenience_store.tscn`，移动或复制 `Furniture` 下的独立 PackedScene 实例即可搭建。
- `shelf.tscn` 是 2.4m 货架；`shelf_long.tscn` 是 3.2m 货架。地面均为 Y=0，家具原点在底部，不需要逐个猜测高度。
- 选中货架根节点，在 Inspector 调整 `shelf_width / shelf_depth / shelf_height / shelf_levels / product_seed / stock_density`。`@tool` 脚本会重建自己的 `Geometry`，不修改兄弟节点。参数在实例中覆盖后，重新加载时也会校验并重建。
- 尺寸范围：宽 0.8–5m，深 0.45–1.4m，高 1–2.8m，2–6 层。层间距较小时商品自动等比缩小以免穿层；正式美术建议使用 1.8m / 4 层附近的比例。
- 不要手工修改货架的 `Geometry` 后又修改生成参数：重新生成会替换该子树。特殊手工资产应复制为独立场景并移除生成脚本。
- `modular_wall.tscn` 及 `wall_*` 是完整可编辑墙模块，可调整长度、高度、厚度和 `cutaway`。南墙、东墙启用固定淡化，保留完整墙体、踢脚线、碰撞和专用不透明阴影代理。不是运行时按遮挡自动淡出的系统。
- 共享材质全部位于 `materials/`。`surface.gdshader` 使用世界坐标噪声、低对比瓷砖缝和木纹。每类材质只保存一份 `.tres`，不为每个商品创建独立材质。
- 冰柜有简化透明展示面和顶面，以便俯视检查内部商品；没有折射、真实玻璃厚度和镜面反射。

## 重建场景

现有 `.tscn` 已烘焙，不需要先运行生成器。所有资源引用均使用 `res://`。

若修改程序化搭建规则，可在 PowerShell 运行：

```powershell
$godot = 'E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe'
& $godot --headless --path 'E:\GameProject\PostApocalyptic3DTest' --script res://scripts/procedural/environment_builder.gd
```

生成器会**重写本项目的场景和共享材质**。在编辑器中手工调整布局后，应直接保存场景，避免再次烘焙覆盖调整。需要长期维护的程序化布局可修改 `environment_builder.gd` 中的 `build_store()`。

## 自动验证与截图

```powershell
# 导入、逐个脚本语法、主场景加载、42 项技术检查
& 'E:\GameProject\PostApocalyptic3DTest\tests\run_tests.ps1'

# 同时启动原生图形窗口，生成 7 张真实截图并检查渲染像素变化
& 'E:\GameProject\PostApocalyptic3DTest\tests\run_tests.ps1' -Capture

# 自定义已安装的 Godot 路径
& '.\tests\run_tests.ps1' -GodotPath 'D:\Tools\Godot4.5.2.exe' -Capture
```

测试无需 Python 或 Blender。截图使用运行场景的 Godot Viewport 保存 PNG，不使用 AI 图片，也不把截图作为场景背景。图形截图需要可用的显示器和 GPU；纯 headless 模式无法生成有效画面。`screenshots/.gdignore` 避免将验证图片导入为游戏资产。

结果见 `tests/results/test_run_summary.json`、`validation.json`、`render_validation.json` 和相应 `.log`。短时渲染监视器数据见 `render_metrics.json`，其中 FPS 包含采样窗口影响，不代表持续性能基准。

| 截图 | 用途 |
| --- | --- |
| [01_ortho_85.png](screenshots/01_ortho_85.png) | 85° 俯视 |
| [02_ortho_65.png](screenshots/02_ortho_65.png) | 65° 斜俯视 |
| [03_lights_shadows_on.png](screenshots/03_lights_shadows_on.png) | 局部光与动态阴影开启 |
| [04_dynamic_shadows_off.png](screenshots/04_dynamic_shadows_off.png) | 同机位关闭动态阴影 |
| [05_local_lights_off.png](screenshots/05_local_lights_off.png) | 同机位关闭局部灯光 |
| [06_occlusion_behind_shelf.png](screenshots/06_occlusion_behind_shelf.png) | 人物在货架后方 |
| [07_occlusion_in_front.png](screenshots/07_occlusion_in_front.png) | 人物在货架前方 |

场景、材质、输入和相机代码均为本轮原生生成。技术结论、视觉边界和后续资产建议见 [3D_VALIDATION_REPORT.md](3D_VALIDATION_REPORT.md)。

## 第二轮视觉升级（2026-11-13）

当前主场景已使用新的截面网格幸存者、独立 Idle/Walk 程序动画，以及六组固定位置的环境叙事细节。操作、相机、三组货架和主通道沿用原版。第一轮报告保留为历史记录，当前结果请看 [VISUAL_UPGRADE_REPORT.md](VISUAL_UPGRADE_REPORT.md)。

- 新人物：`scenes/player/survivor_visual.tscn`；身体包装：`player_visual_v2.tscn`。原 `player.tscn` 保留。
- 动画：`scripts/survivor_animator.gd`。只读取角色速度并操作视觉节点，不写碰撞体或 CharacterBody3D 位置。
- 环境：`scenes/environment/environment_story.tscn`，包含六个命名分组；购物篮和垃圾桶另有独立 PackedScene。
- 共享材质：`materials/upgrade/`。`*_recipe.tres` 提供材质族、底色、粗糙度、磨损、积灰、锈蚀和噪声尺度；修改配方后调用 `bake()` 重新保存对应 StandardMaterial3D。地板与墙面连续污渍使用单独 Shader。
- 非破坏外观层：`EnvironmentStory.finish_enabled` 开启时，在运行中替换指定材质并隐藏旧污渍贴片，保留原资源与碰撞。原便利店场景在编辑器中仍显示旧地板；最终地板与墙面效果以 F5 运行画面为准。

新增资产的重建命令（只重写本轮生成资源；不会重新烘焙原便利店）：

```powershell
$godot = 'E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe'
$project = 'E:\GameProject\PostApocalyptic3DTest'
& $godot --headless --path $project --script res://scripts/procedural/visual_upgrade_builder.gd
& $godot --headless --path $project --script res://scripts/procedural/story_generator.gd
& $godot --headless --path $project --script res://scripts/procedural/build_finish_materials.gd
& '.\tests\run_tests.ps1' -VisualCapture
```

不要运行第一轮的整场景烘焙器来更新第二轮，它会把主场景入口重新接回旧资源。对本轮生成资产的长期修改应优先修改生成脚本；手工制作变体请另存资源，避免被重建覆盖。

公平比较截图均为 1440×1000、原 Camera3D、原正交尺寸、相同人物位置、145° 固定人物朝向和相同灯光。朝向统一后重新拍摄了原人物，因此可直接比较人物结构。对比过程有独立 JSON 参数记录和自动检查。

| 阶段 | 65° | 85° |
| --- | --- | --- |
| 原始 | [before_65](screenshots/round2/before_65.png) | [before_85](screenshots/round2/before_85.png) |
| 人物升级 | [character_65](screenshots/round2/character_65.png) | [character_85](screenshots/round2/character_85.png) |
| 环境升级 | [environment_65](screenshots/round2/environment_65.png) | [environment_85](screenshots/round2/environment_85.png) |
| 完整优化 | [final_65](screenshots/round2/final_65.png) | [final_85](screenshots/round2/final_85.png) |

[Idle 预览](screenshots/round2/idle_preview.webp) / [实际移动与 Walk 预览](screenshots/round2/walk_preview.webp) 均由 Godot 游戏相机原始帧无损编码得到。对应逐帧 PNG 保存在 `screenshots/round2/motion/`。320×320 和 220×230 小图是原分辨率画面的像素裁切，没有另加近景相机或放大模型。

测试入口现在检查 22 个 GDScript、42 项原有回归、22 项视觉资产/动画/空间检查；`-VisualCapture` 另执行 20 项公平比较与绘制开销检查。历史截图与原始资源备份保存在 `tests/baseline_round2_20261113.zip`（源码、场景和材质，不含缓存、测试、截图）及 `screenshots/round2/before_*`。

## 鼠标滚轮缩放（2026-11-13）

启动时以现有 `view_size` 初始化 `Camera3D.size`，再记录为本次运行的 `default_size`，当前值为 **13.8**。最近/最远使用相对默认值的 **0.6 / 1.8**，即 **8.28–24.84**。每格滚轮按 **1.1** 倍缩放目标，`size` 按指数插值平滑接近目标；Home 也平滑恢复默认。

Inspector 可配置 `closest_size_ratio`、`farthest_size_ratio`、`zoom_step_factor` 和 `zoom_smooth_speed`。只调整正交 `size`，不改变 FOV、观察点、相机偏移、角色移动或光照。滚轮和 Home 使用 `_unhandled_input`，尊重 UI 消费；Home 经检查无原有功能冲突。

HUD 中 `ZOOM = default_size / current_size`，默认 **1.0×**，拉近倍率上升。当前上下限约为 **1.67× / 0.56×**；显示的一位小数按实际过渡中的尺寸计算，而不是直接显示目标值。

运行 `tests/run_tests.ps1` 会包含新的 **20 项缩放检查**，结果在 `tests/results/camera_zoom_validation.json`。既有视觉升级保护测试仅额外允许本次授权的相机/HUD 文件修改，仍检查原模型、材质和角色移动文件的哈希。

**人工验收待执行：** 店中央连续滚轮的平滑感；最近距离的人物裁切；最远距离的渲染；65°/85° 切换后倍率保留；移动中连续缩放的跟随稳定性。自动测试通过不代表这些交互与画面体验已完成人工验收。

## Stage 4-A：CAD 便利店布局

- **旧场景**：双击 `Run.bat`，或 F5。默认主场景保持 `scenes/main.tscn`。
- **CAD 新场景**：双击 [RunCAD.bat](RunCAD.bat)，或打开 `scenes/cad_convenience_store.tscn` 按 F6。
- 新场景出生点在右上入口内侧；R 返回该出生点。WASD、F1/F2、F3/F4、滚轮和 Home 沿用现有控制。
- [完整 CAD 布局报告](CAD_STORE_LAYOUT_REPORT.md) 记录尺寸来源、家具位置、通道、密度、性能及人工验收清单。

图纸原件已保存在 `references/cad_store_plan.png`，不作为游戏背景。建筑外框 **13.16×8.75m**，净空 **12.68×8.27m**，墙厚 **0.24m**；右侧两处门洞按尺寸链保留为 **1.70m / 1.89m**。家具位置与多数规格是按图比例估算，不是矢量 CAD 精确测量。

布局权威是 `scripts/cad/store_layout_data.gd`。`store_layout_builder.gd` 复用货架、墙体、商品与收银台，生成独立 CAD PackedScene；不会重写旧主场景。修改布局数据后运行：

```powershell
$godot = 'E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe'
& $godot --headless --path 'E:\GameProject\PostApocalyptic3DTest' --script res://scripts/cad/store_layout_builder.gd
& '.\tests\run_cad_tests.ps1' -Capture
```

CAD 货架新增可选的单面陈列、四段支架、窄墙架及分组密集商品模式，旧货架默认行为保留。商品用 15 个共享 SKU 网格合批，保存显式实例变换以兼容 headless 烘焙；实际画面有 1560 件陈列商品，占位率约 84.6%。

**编辑注意：** CAD 场景以数据驱动烘焙为主。修改货架位置、尺寸或密度后必须重建布局，使全场商品合批同步；只手动移动已放置的货架会使全局商品停在原位。单独复用 CAD 货架模板时，可在 Inspector 将 `stock_visible` 开为 true 显示其本地商品。131 个本地商品缓冲保留为模块资产数据，完整 CAD 场景只绘制 15 个全局合批。

自动验证通过不代表已经人工试走。尤其需要检查 **1.303m 的收银台前区域**、**0.855m 的员工操作区**、座椅旁转弯和两种缩放极限下的遮挡。

实际截图：[旧场景 65°](screenshots/cad/original_65.png)、[CAD 65°](screenshots/cad/cad_65.png)、[CAD 85°](screenshots/cad/cad_85.png)、[人物近景](screenshots/cad/cad_character_close.png)、[全景](screenshots/cad/cad_overview.png)。

## Stage 4-B：末日陈列与搜索联动

双击 [RunLoot.bat](RunLoot.bat)，或打开 `scenes/looted_convenience_store.tscn` 按 F6。F5、Run.bat 和 RunCAD.bat 的入口保持原样。此场景在运行时生成新陈列，编辑器静态画面不能代表最终缺货状态。

默认固定种子 **41027**，`PARTIALLY_LOOTED` 实际 **725/1848（39.23%）**。集中配置在 `data/loot_display_profiles.json`；场景根节点下的 `LootDisplay.preset` 可切换 STOCKED / PARTIALLY_LOOTED / HEAVILY_LOOTED。每次重新运行恢复同一初始布局与库存，本轮不保存会话。

唯一可搜索对象是**中央第二列货架（02）**，中心世界坐标 X=-2.10、Z=0。靠近后按 E，打开界面不会领取；点击“取 1”或“全部取走”才获得物资并移除绑定的可见商品。默认可领取瓶装水×2、食品罐头×1、盒装食品×1。Esc 关闭；离开范围自动关闭。其余可见包装视为空瓶、过期或受损品。WASD、R、F1/F2、F3/F4、滚轮和 Home 沿用原功能；在搜索面板上滚轮不会缩放场景。

新陈列采用稳定槽位数据与共享 MultiMesh；领取时只更新目标货架受影响的 SKU 缓冲。视觉更新失败会拒绝领取并回滚，不会增加测试物资记录。

```powershell
$godot = 'E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe'
$project = 'E:\GameProject\PostApocalyptic3DTest'
# 仅需在修改本轮生成器后重建，运行项目无需这些步骤。
& $godot --headless --path $project --script res://scripts/loot/packaging_builder.gd -- phase=atlas
& $godot --headless --path $project --editor --import
& $godot --headless --path $project --script res://scripts/loot/packaging_builder.gd -- phase=models
& $godot --headless --path $project --script res://scripts/loot/build_loot_scene.gd
& "$project\tests\run_loot_tests.ps1" -Capture
```

只重建本轮生成资产；人工变体请另存名称。报告、原始 CAD/缺货/商品近景/领取对比和性能采样见 [STAGE_4B_LOOT_VISUAL_REPORT.md](STAGE_4B_LOOT_VISUAL_REPORT.md)。截图来自真实 Godot 渲染；美术质量与实际搜索手感仍待人工验收。

## Stage 4-C：可玩的搜刮闭环

继续使用 **RunLoot.bat** 或打开 `scenes/looted_convenience_store.tscn` 按 F6（基于 CAD 的可玩搜刮场景）。原 RunCAD.bat 仍是未接交互的 Stage 4-A 对照入口，F5 也保持原入口。

沿通道靠近中央第二列货架 02，按 E 打开双栏面板：左侧货架，右侧临时背包。打开时锁定移动输入，Esc/关闭恢复之前的移动状态；重复 E 不会再次打开。点击“取 1”或“全部取走”才转移物资并移除对应商品；打开/关闭不会扣库存。面板内滚轮不缩放世界，场景区域滚轮与 F1/F2/F3/F4 保留。

交互距离按角色胶囊表面至货架边缘计算，当前 1.25m，射线阻止隔墙搜索。仅货架 02 可搜刮；同一运行会话内数据保留，重新加载场景会重置。Stage 4-C 接替上方 Stage 4-B 关于“面板打开仍可移动”的历史说明。

验证：`tests/run_stage4c_tests.ps1 -Capture`。详见 [STAGE_4C_LOOT_INTERACTION_REPORT.md](STAGE_4C_LOOT_INTERACTION_REPORT.md)，含真实截图、测试结果及待人工验收清单。

## Stage 4-D：全店搜刮与一致商品状态

入口仍为 **RunLoot.bat** / `scenes/looted_convenience_store.tscn` 按F6。三列中央架、西墙/南墙货架、北侧/岛式冷柜、收银台共16个容器可搜刮。E提示显示当前目标名称，距离与朝向共同决定目标；面板打开后固定目标、锁定移动，Esc关闭恢复。

**完好商品全部可领取**，领取后变为TAKEN并隐藏。红褐压扁商品为DAMAGED、灰绿污染商品为SPOILED，两者不可领取；EMPTY无库存。每件模型明确对应1份物资。默认全店728件可见、450件可领取；货架02可领取83件，搜空只留7件损坏/12件污染，不再留无解释的完好水瓶。

集中配置仍在 `data/loot_display_profiles.json`。临时背包仅本场景运行会话，重新加载重置；没有正式存档。旧Stage4-B/C报告与单货架测试保留作历史记录，原“只有02可搜、只领4件”不再适用于当前版本。当前测试用 **tests/run_stage4d_tests.ps1 -Capture**。

详见 [STAGE_4D_STORE_LOOT_REPORT.md](STAGE_4D_STORE_LOOT_REPORT.md)，含执行前根因、每容器统计、真实截图、性能与待人工验收事项。

## Stage 4-D.1：稀缺物资与单目标高亮

继续使用 **RunLoot.bat** / `scenes/looted_convenience_store.tscn` F6。当前全店默认 **12份**：水3、食品6、其他3，分布在7个容器，9个容器初始无可领取物资。Stage4-D的450份、02的83份为历史配置；“本次获取”始终表示累计领取数。

集中配置位于 `data/loot_display_profiles.json` → `scarcity`。完好模型随配额一起减少，保持一件模型对应一份物资，不可用品仍是损坏/污染状态。当前目标用一个淡青色深度测试轮廓代理显示，UI打开时保留，搜空弱化，离开消失；没有逐商品描边或Stage4-E发现机制。

测试入口：`tests/run_stage4d1_tests.ps1 -Capture`。报告：[STAGE_4D1_LOOT_HIGHLIGHT_REPORT.md](STAGE_4D1_LOOT_HIGHLIGHT_REPORT.md)，包含逐容器前后数据、真实截图、原54FPS机位的前后实测与待人工验收清单。

## Stage 4-D.2：王家便利店

入口仍为 **RunLoot.bat** / `scenes/looted_convenience_store.tscn` F6。当前运行实例增加中文店招、店内标识、双凹陷水池与弯管龙头、收银设备细化和四类中文包装；旧CAD资源/碰撞保留。原F5及RunCAD历史对照入口不改。

描边颜色、alpha、宽度集中在 `data/art_localization.json`；默认暖琥珀 `#E6A23C`。**Stage4-D.1的12份稀缺配置文件完全不变**；boxed_food显示为桶装方便面，仍使用原稳定数据键。

字体随包为Noto Sans SC，SIL OFL1.1许可与来源在 `assets/fonts/`。完整字体约17.8MB，避免依赖本机系统字体；`export_presets.cfg`显式包含许可证并排除测试/截图。原生PCK验证产物在测试结果目录，不是正式发行版。

重建仅本轮生成资产（不重建CAD）：先运行 `python scripts/localization/build_textures.py`（使用已有Pillow），再用Godot导入、运行 `scripts/localization/build_products.gd`。运行项目无需Python。

测试入口：`tests/run_stage4d2_tests.ps1 -Capture`。报告：[STAGE_4D2_ART_LOCALIZATION_REPORT.md](STAGE_4D2_ART_LOCALIZATION_REPORT.md)。中文店名与包装为开发暂用设计，未做商标检索；实际美术/操作效果待人工验收。

## Stage 4-D.3：四种正交相机

RunLoot独立游戏窗口内：**F1 85°、F2 65°（默认）、F5 45°正向、F6 45°+水平35°**。F3/F4仍为灯光/阴影，滚轮/Home保留；**F7仅调试隐藏/恢复模块墙面，碰撞不变**。编辑器F5/F6仍是运行快捷键，验证时给游戏窗口焦点。

参数在 `data/camera_presets.json`，每套包含pitch、yaw、orthographic_size、follow_offset、target_offset。四套默认size13.8、缩放8.28–24.84，均观察玩家上方0.85m；原偏北2.3m构图改为玩家中心。WASD仍相对相机水平投影，不改角色控制器或世界坐标。

测试：`tests/run_stage4d3_tests.ps1 -Capture`。报告：[STAGE_4D3_CAMERA_COMPARISON_REPORT.md](STAGE_4D3_CAMERA_COMPARISON_REPORT.md)。40张真实截图和32个遮挡样本见报告；45°存在明显局部遮挡，暂不建议替代65°默认，人手移动/美术验收待完成。
