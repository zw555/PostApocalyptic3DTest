# Stage 5-B：单僵尸 AI 与货架追逐验证

项目：`E:/GameProject/PostApocalyptic3DTest`；Godot：`4.5.2.stable.official.6ce3de25a`。本轮到 Stage 5-B 为止，不继续正式战斗开发。

## 1. 状态与启动

- **已实现**：单只普通僵尸、程序化人形与动画、五状态 AI、双高度视线检测、原生导航与实体移动、无伤害挥击反馈、复用的敌人遮挡轮廓、F10 调试。
- **自动验证结果**：见第 7 节，脚本逻辑/原生物理与真实渲染分别计数。
- **人工验收通过：无。Stage 5-A 的 A–F、Stage 5-B 的 A–G 全部待玩家实际操作确认。** 截图与脚本驱动的运行不计作人工验收。
- 不包含武器、生命值、伤害、死亡、掉落、敌人群体、声音传播、正式存档或新背包功能。

通过 [RunZombie.bat](E:/GameProject/PostApocalyptic3DTest/RunZombie.bat) 启动新验证场景，默认 **F6：45°、yaw 35°、正交 size 13.8**。原 `RunLoot.bat`、旧 CAD 场景和 `project.godot` 启动入口均保留。

## 2. 执行前检查及保留内容

目录不是 Git 工作区：`git status --short` 返回 `not a git repository`。修改前保存 `tests/baseline_stage5b/manifest.json` SHA-256 清单，用于验证已有源码、场景、材质、数据和资源。原有文件仅修改 `scripts/occlusion/player_occlusion.gd`，使其支持复用；其余实现采用新增文件和继承场景。

玩家继续使用原 CharacterBody3D、半径 0.27 m / 高度 1.72 m 的胶囊与独立 Visual。建筑与家具仍为原 StaticBody3D / CollisionShape3D，没有移动货架、扩大通道或缩小角色碰撞。场景原本没有 NavigationRegion3D。本轮烘焙复用了原碰撞几何。

16 个容器、全店 12 份初始物资、稳定商品 ID / 槽位、MultiMesh、搜索 UI 和事务逻辑保持不变。四种视角、滚轮、Home、WASD、E/Esc、R、F3/F4、F7/F8/F9 保留。没有修改其他工程，没有提交或推送 Git。

Stage 5-A 补充了敌人复用、双方同时遮挡的实际像素对照以及 F9 联动检查；原 5-A 的 50 项逻辑和 54 项渲染检查仍执行。原来未完成的人工走位、轮廓手感、85° 完全遮挡、不同 DPI 下 HUD 适配等并未因此变为人工通过。

## 3. 僵尸模型和动画

复用现有截面 Loft 建模器与幸存者人形结构，在独立实例上更换共享材质：灰绿色皮肤、灰褐色旧外套、暗灰裤鞋，去掉背包，增加小块磨旧布料。原玩家 Mesh 和材质资源没有被覆盖或就地改色。没有外部模型、贴图、插件或付费素材。

视觉与物理分离；UpperBody 微驼背、双臂略抬，保持成人头身比例。使用独立 ZombieVisual，复用原有腿段解析摆放，步态按实际物理速度推进，支撑期脚相对身体向后移动，摆动期轻抬脚。Idle 小幅呼吸，Walk / Chase 随速度改变步频，Attack 单次双臂前挥。停止受碰撞时使用实际速度减弱步态。

这些是无骨骼、无 IK 的节点动画。脚底轨迹受约束，但转角、加减速、动作辨识度和滑步程度仍需人工判断，不能用节点变换测试代替动画美术验收。

## 4. AI 状态与集中参数

配置：`data/zombie_validation.json`。

| 状态 | 行为与转换 |
|---|---|
| IDLE | 出生区域待机、面向预设朝向。连续看到玩家 0.20 s 后进入 CHASE 或 ATTACK |
| CHASE | 追向最后看见的位置；只有实际视线成立才更新该位置。失去视线持续 0.45 s 后进入 INVESTIGATE |
| INVESTIGATE | 前往最后发现位置或其可通行投影；到达后等待 3 s，再 RETURN。无法到达时启用超时处理；重新发现玩家可立即重追 |
| RETURN | 以较慢速度返回出生区域，距原点约 0.4 m 内 IDLE；途中也可重新发现玩家 |
| ATTACK | 1.2 m 内且视线无遮挡时挥击；1.45 m 外退出，墙体阻挡也立即禁止挥击。1.5 s 冷却，动作约 0.7 s，只发可见反馈 |

| 参数 | 默认值 |
|---|---:|
| 固定出生点 | `(-5.4, 0.02, 2.5)`，店铺左下方 |
| 视距 / FOV | 6 m / 120° |
| 眼高 | 1.50 m，考虑驼背 |
| 调查/返回速度 | 0.85 m/s |
| 追逐速度 | 1.60 m/s，低于玩家原速度 3.2 m/s |
| 思考间隔 | 0.10 s |
| 常规重寻路间隔 / 目标位移阈值 | 0.35 s / 0.40 m |
| 无效路径或卡住后的重试 | 最多约每 1 s 一次 |
| 胶囊 / 导航安全半径 | 0.27 m / 0.32 m |

只有一只僵尸。出生点距玩家入口超过视距；进入场景不会立即攻击。搜索面板只冻结玩家输入，AI 继续运行，但不会扣血。状态转换记录最多保留 256 条用于调试，非正式存档。

## 5. 视线和导航

### 视线

先检查水平距离和朝向，再从僵尸眼部向玩家头部约 1.62 m、躯干约 1.05 m 发射少量物理射线，mask 为原建筑/家具与玩家层，排除自身 RID。墙体阻挡两条视线时不能发现玩家；中央货架的连续背板在当前眼高下形成实际遮挡。

低冷柜与收银台不是凭类型强制完全遮挡。成年人可从低柜上方看到露出的头部；低位射线仍被柜体挡住，自动检查分别覆盖这两种情况。沿用原结构碰撞作保守近似，不对每件商品或网格三角形单独判断。

失去视线后的导航目标只取储存的 last_seen，不会继续读取隐藏玩家的位置用于追踪。攻击再次独立检查射线和范围，并有冷却保护；不调用伤害接收接口。

### NavigationAgent3D

`assets/navigation/store_navigation.tres` 是 Godot 原生静态碰撞烘焙得到的 155 个地面多边形，资源约 11 KB。cell size 0.04 m、cell height 0.05 m、agent radius 0.32 m、agent height 1.75 m，最大台阶约 0.05 m。烘焙后剔除高于 0.2 m 的货架/柜台顶部，避免把家具表面当作路线。

加载时校验实际静态碰撞签名，并匹配导航 map 的体素尺寸；至少等待导航同步后才移动。几何变化导致签名不符时停止 AI 并报错，不使用过时网格。需要重新烘焙时运行：

```powershell
& 'E:/Godot_v4.5.2-stable_win64.exe/Godot_v4.5.2-stable_win64_console.exe' --headless --path . --script res://scripts/ai/build_navigation.gd
```

寻路目标投影到可通行区域；路径结束后停止继续推进，避免终点抖动。无效路径/卡住会限频重试，不传送、不穿模。NavigationAgent 只提供路径；实体运动仍由 CharacterBody3D 的 `move_and_slide` 完成。僵尸放在能被玩家原 mask 检测到的层上，原玩家无需改变碰撞配置。

本轮原生路径实验从货架 02 一侧到另一侧，实际绕行约 4.96 m，路径记录逐帧检测结构穿入；没有通过挪货架或缩小胶囊解决通行问题。冰柜之间原有约 0.236 m 的维修缝不是通道，不会强行穿过。

导航实现参考：[Godot 4.5 NavigationMesh](https://docs.godotengine.org/en/4.5/tutorials/navigation/navigation_using_navigationmeshes.html)、[NavigationAgent 路径跟随](https://docs.godotengine.org/en/4.5/tutorials/navigation/navigation_using_navigationagents.html)。

## 6. 遮挡与调试复用

Stage 5-A 的 `initialize` 增加可选共享检测器与参数覆盖；原调用方式保持有效。玩家和僵尸使用同一个脚本与同一对深度 Shader，敌人借用玩家已建好的 51 个查询 RID，未再建一套结构代理。蒙版只复制角色 Mesh，不改商品 MultiMesh，也不复制搜刮系统。

敌人轮廓为低饱和红橙 `#BD7666`；玩家仍为暖白 `#E9DEC5`；容器为原琥珀 `#E6A23C`。轮廓只填人物受挡边缘，正常可见表面保持原材质。敌人还受有效发现记录与 6 m 距离限制，避免无缘无故揭示全店敌人；这不是独立的隐藏发现玩法。

- F8：原玩家遮挡调试，默认关闭。
- F9：同时控制双方轮廓，关闭后不会遗留敌人轮廓。
- **F10：AI 调试**，默认关闭。显示状态、目标、最后发现位置、LOS、路径有效性、重算次数及 AI/导航耗时；以缓存 ImmediateMesh 显示实际路径和按配置生成的视野扇形，受普通深度遮挡，不每帧新建材质。

## 7. 自动化结果和实际运行记录

入口：`./tests/run_stage5b_tests.ps1 -Capture`。详细日志：`tests/results/stage5b_final_run.log`；本轮数据：`stage5b_validation.json`、`stage5b_render.json`；原 5-A 及上游结果也保留。

自动化结果：`stage5b_validation.json` 为 **51 通过、0 失败**；覆盖状态机、双射线视线、墙体/货架遮挡、导航绕行、攻击冷却、搜刮并行、16 个容器与 12 份物资守恒、相机快捷键、滚轮缩放、共享遮挡资源及原碰撞资源保护。`stage5b_render.json` 为 **31 通过、0 失败**，生成 17 张真实 Godot PNG，包含发现→追击→攻击→调查→返回、货架绕行、双方轮廓、四视角和搜索面板。此前 `stage5b_final_run.log` 还保留了 Stage 4-D/4-D.1/4-D.2/4-D.3、5-A 回归的成功记录。

原生物理检查包括：真实北墙遮挡、货架遮挡、低柜上下射线、发现/丢失/调查/返回/再发现、攻击冷却、导航同步前不移动、投影到货架外、最后位置在障碍内时结束调查、真实实体绕行无穿入、面板打开时 AI 持续运行、单件物资事务与视觉不变量、原碰撞资源/层/变换一致。

真实渲染脚本运行了发现→追击→挥击→失去视线→调查→返回的完整序列，另有货架绕行、双方轮廓开关像素对照、四视角和攻击时搜索面板。绕行实验为了独立检验导航，初始 last_seen 用明确的测试夹具赋值；后续移动、视线、再发现与攻击都是原生运行。它不代替人工“隔货架引怪”的过程。

当前验收链全部执行；目录内已被新阶段替代的旧固定库存/旧镜头脚本不作为当前验收链。任何脚本成功都没有登记为人工成功。

## 8. 性能

同机 RTX 4060 Laptop GPU、Forward+ / Vulkan、1440×1000、F6 45° yaw 35°、size 13.8、灯光/阴影开启、UI 关闭，玩家位置固定 `(-2.1, 0.02, -2.25)`。每条件预热 180 帧，3 窗口 × 600 帧。

四组玩家均保持正常 Idle 动画；僵尸也使用正常动画和物理更新。无僵尸组实际加载原无敌人场景。追击组循环重放短追击片段：接近玩家前将敌人放回片段起点，保持测量期为 CHASE，重置次数与状态采样写入 JSON；不把这种微型压力测试当作完整追逐体验。双方轮廓组使用已知敌人待机位置，AI 与动画仍运行。

| 条件 | 平均帧间隔（3窗口均值） | FPS（3窗口） | P95（3窗口） | 平均 Draw Calls | AI μs | 导航 μs |
| --- | ---: | --- | --- | ---: | ---: | ---: |
| 无僵尸 | 4.988 ms | 205.7 / 226.6 / 175.7 | 7.059 / 6.317 / 7.508 ms | 3188.8 | 0 | 0 |
| 僵尸待机 | 5.302 ms | 197.9 / 173.1 / 197.3 | 7.667 / 8.162 / 7.093 ms | 3340.1 | 107.84 | 2.89 |
| 僵尸追击重放 | 4.911 ms | 197.7 / 212.5 / 201.9 | 7.644 / 6.946 / 7.425 ms | 3358.3 | 133.65 | 17.62 |
| 双方轮廓待机 | 4.760 ms | 208.3 / 208.5 / 213.6 | 7.900 / 7.774 / 7.273 ms | 3371.2 | 95.59 | 2.47 |

这组数据说明本机短窗口没有出现超过 16.7 ms 的帧；追击状态的导航开销约 17.62 μs。它不能解释用户此前约 54 FPS 的现场问题，也不能替代用户在相同分辨率、驱动和窗口模式下复测。

AI 耗时包含导航与移动开销，导航列是其中一部分，不能相加。Draw Calls 是 Godot 总视口监控，包含阴影与角色蒙版；表中使用每窗口逐帧均值。动画会影响阴影更新成本，因此没有用冻结玩家动画的旧 5-A 数字直接比较。FPS 由完整窗口平均耗时换算，截图 HUD 的瞬时值不作为性能结论。

这是短时采样，不能证明所有硬件、窗口状态与长时间运行都没有卡顿；之前约 54 FPS 的使用环境仍需按相同条件由玩家复测。

## 9. 截图索引（真实 Godot PNG）

| 内容 | 文件 |
|---|---|
| 45°、1.0× 人物区别 | [model_compare45_1x.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/model_compare45_1x.png) |
| 65° 人物对比 | [model_compare65_1x.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/model_compare65_1x.png) |
| 原生追击 | [native_chase.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/native_chase.png) |
| 无伤害挥击 | [native_attack.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/native_attack.png) |
| 失去视线后的调查 | [native_investigate.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/native_investigate.png) |
| 返回 | [native_return.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/native_return.png) |
| 绕行前 / 转角 / 到达 | [route_before.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/route_before.png)、[route_turn.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/route_turn.png)、[route_after.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/route_after.png) |
| 双方轮廓开 / 关 | [dual_occlusion_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/dual_occlusion_on.png)、[dual_occlusion_off.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/dual_occlusion_off.png) |
| 85° / 65° / 45° 正向 / 45° 斜向 | [F1](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/two_actors_F1.png)、[F2](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/two_actors_F2.png)、[F5](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/two_actors_F5.png)、[F6](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/two_actors_F6.png) |
| 受攻击反馈时搜索 | [loot_during_attack.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5b/loot_during_attack.png) |

没有 AI 生图。截图为脚本操作的游戏相机结果，不能据此宣称人手操作验收完成。

## 10. 人工验收清单

启动 RunZombie，默认 F6；按 F10 查看状态/路径。僵尸在店铺左下方，默认朝北。沿主通道接近其北侧，让玩家进入其正前方视线；攻击只演示，不扣血。R 仍只重置玩家位置，不重置僵尸或会话库存；需全新初始状态时重启验证场景。

| 项目 | 实际操作与判断 | 结果 |
|---|---|---|
| A 货架绕行 | 先在僵尸正前方露面，再绕中央货架端部逃离；检查实体沿通道绕行，没有直接穿货架 | 待人工验收 |
| B 视线中断 | 躲到货架背板或墙后，再改变位置；F10 的 last_seen 应停在最后见到的位置 | 待人工验收 |
| C 调查 / 返回 | 保持隐藏，观察到达最后位置后约 3 s 的调查与返回；重新出现测试重追 | 待人工验收 |
| D 动画 | 45° / 65°、1.0× 下检查 Idle、Walk、Chase、Attack、停止与拐弯，判断滑步/旋转是否明显 | 待人工验收 |
| E 遮挡 | 双方同时在货架后，观察暖白与红橙区别，再按 F9 对照；检查墙体、不同缩放、无遮挡部位 | 待人工验收 |
| F 搜刮干扰 | 僵尸接近时 E 搜索、取一件、全部取走、Esc；确认 UI、目标高亮与玩家输入恢复，物资不复制 | 待人工验收 |
| G 相机 | F1/F2/F5/F6、滚轮、Home，移动中切换并观察导航、轮廓与目标提示 | 待人工验收 |

没有人工通过项，也没有被掩盖的人工失败项：本轮未执行人手验收。Stage 5-A 原人工清单仍维持待验收。

## 11. 修改文件与已知限制

| 文件 | 用途 |
|---|---|
| `scripts/occlusion/player_occlusion.gd` | 唯一改动的旧源码；增加共享 RID、独立配色与主开关联动 |
| `scenes/zombie_chase_validation.tscn`、`scripts/ai/chase_validation_main.gd`、`RunZombie.bat` | 继承原场景、新验证入口、单敌人装配与演示反馈 |
| `scripts/ai/zombie_controller.gd` | 五状态、视线、NavigationAgent、实体运动与冷却 |
| `scripts/ai/zombie_model.gd`、`zombie_visual.gd` | 共享原建模结构的新实例与独立动画 |
| `scripts/ai/zombie_debug.gd` | F10 文本、视野与路径 |
| `scripts/ai/store_navigation.gd`、`build_navigation.gd` | 地面导航加载、同步、校验、重烘焙 |
| `data/zombie_validation.json`、`store_navigation_manifest.json`、`assets/navigation/store_navigation.tres` | 集中参数、几何签名、原生烘焙资源 |
| `tests/validate_zombie_ai.gd`、`stage5b_capture.gd`、`run_stage5b_tests.ps1` | 自动验证、实际渲染/性能、回归入口 |
| `tests/baseline_stage5b/manifest.json`、`tests/results/stage5b_*`、`screenshots/stage5b/` | 基线、真实结果与截图 |

已知限制：

1. 单敌人只验证当前固定布局；没有动态障碍导航更新、多人群体避让或多层导航。家具位置发生变化必须重新烘焙，不能把 155 个多边形视为任意场景通用导航。
2. 视线以结构碰撞与两条身体采样射线为近似，不模拟货架小孔、透明玻璃光学或商品间隙；柜台上方可见头部是预期行为。
3. 敌人轮廓复用大型障碍查询；人物互相挡住的小区域未单独增加遮挡代理。正常可见部位受深度保护，已发现敌人的 6 m 内提示不等于正式潜行发现系统。
4. 返回区域若因未来新增障碍而不可达，会停止/限频重试并显示路径无效，不会传送；当前出生点与主要通道已通过自动路线样本，未穷尽全部位置。
5. 程序化步态没有地形 IK、真实重心与骨骼动作。穿着层次较简单，动作美观与滑步仍需人工验收。
6. Stage 5-A 的近距底部 HUD 文字裁切/DPI 适配问题继续列为待核对，没有进行 UI 重构；首次加载/截图瞬时 FPS 也不是稳定性能数据。
7. 本次续跑在 2026-11-14 重新启动 Godot 4.5.2 原生进程时遇到 signal 11，随后窗口启动也显示 Godot 应用程序错误；这是当前机器上的引擎/进程环境阻塞，未覆盖或改写此前成功的 51/31 项结果。待关闭残留 Godot 进程或重启系统后，优先重跑 `tests/run_stage5b_tests.ps1 -Capture`。
8. 后续先完成 5-A / 5-B 人工清单并记录卡住或视线不合理的具体点，再调导航安全边距、视觉确认时间和步态。不自动继续武器、伤害、死亡或其他正式战斗系统。

