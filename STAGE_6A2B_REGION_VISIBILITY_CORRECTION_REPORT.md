# Stage 6-A.2-B 区域可见性修正

2026-11-16，Godot 4.5.2.stable.official.6ce3de25a，Vulkan Forward+。

**已实现并完成自动检查、真实渲染复核；玩家人工验收待执行。** 本次以用户图1、图2的区域展示原则修正图3，保留原图3版本场景和截图供追溯。本轮不提交、不推送 Git。

## 1. 根因与构件分类

上轮把“本层顶面不渲染”当作主要规则，却仍展示整层占位轮廓；区域标识只辅助射线，并没有真正约束邻区的暴露范围。这是上轮方案判断错误，不能以此前101项技术检查通过当作目标视觉通过。

| 真实对象 | 类型、用途 | 图3问题 |
|---|---|---|
| `Corridor/Ceiling/Panel0～4` | 5块顶面Mesh，带查询代理 | 已隐藏，不是本次空腔的来源 |
| `NeighborRooms/Room502～504/RoofXX` | 24块顶面Mesh | 已隐藏，本轮继续隐藏，没有用其他平面代替顶面 |
| 各邻户 `ClosedVolumeFloor` | 原地板Mesh，另有独立StaticBody3D/CollisionShape3D | 上轮改为暗色但仍显示，成为大面积黑色“坑底” |
| 各邻户 `North/South/Outer` | 每户3组周边墙，含Lower/Upper/Skirting | 9组墙与3块暗地板共同勾出完整空盒子；共30块非顶面Mesh |
| `Corridor/Architecture`、`Corridor/Portal###`、门组件 | 真正面向可玩楼道的边界、门洞、门框、门牌 | 应继续展示，不能随占位根节点整体隐藏 |
| `WallCollision`、各地板碰撞、门叶碰撞 | 原生StaticBody3D及形状 | 与渲染分离，无须删除或禁用 |

原控制关系：`floor5_visibility_policy.gd`最终写建筑visible/cast_shadow；C检测器提供多点命中和计时；Stage 5-A只写自己的轮廓拷贝；`floor5_visibility_main.gd.update_cutaway`为空钩子，不争抢墙体。上轮没有证据表明共享材质污染导致空腔；问题来自展示范围。本次没有新增第二套独立射线系统或材质控制器。

## 2. 当前显示规则

| 玩家区域 | 501内部 | 公共楼道及房门 | 502～504 |
|---|---|---|---|
| 501生活区/卫生间 | 完整显示家具、地板、窗和墙；实际挡住人物的墙段仍动态剖切 | 保留连接楼道、门与边界，可见部分随相机视野决定 | 只展示现有临楼道立面和门框门牌，不展示占位地板、远侧空壳 |
| 公共楼道/楼梯入口前区 | 收起内部家具、室内地板、远侧围护的展示；501临楼道共用墙、门、门框保留 | 当前可玩空间优先可读；仅实际挡住人物时局部剖切 | 同上，门后保持未知，不生成内部内容 |
| 门口边界 | 沿用0.10m边界余量及0.12s区域稳定时间；确定区域后以0.22s过渡 | 门与共用立面始终保留，不随501家具一起淡出 | 固定不展开，不因门口抖动反复显示 |

屋顶29块在活动五楼始终不显示。没有添加封盖、黑色遮罩、上层楼板替代物或房间填充体。未开放空间不再有底面和远侧围墙画出的完整空腔；背景本身未更换颜色。

“保留墙体”分为两种职责：临当前可玩区域的立面、门洞和共享墙保持渲染，只有实际遮挡才局部剖切；邻户远侧占位围护和非当前501内部归属区域展示，不渲染时仍完整保留场景节点与实体碰撞。不是永久删除外墙，也不是把未知区域改成可通行空地。

本轮没有把全栋楼低透明化。短暂过渡仅作用于501所属的非共用构件，以每个GeometryInstance3D的transparency执行；不修改共享Material。进入稳定状态后，非当前内部完全退出绘制，不在屏幕上保留一片透明家具。

F7仅对比当前展示边界的实际墙体剖切，不会展开邻户或非当前501；F8调试、F9人物轮廓、F1/F2/F5/F6、滚轮/Home、R和E均保留。

## 3. 实现与修改文件

统一流程：原楼层/墙段决策 → 区域展示约束 → 一次最终提交 → 原Stage 5-A读取最终可见源。每个构件只有一个最终决策，区域与墙体没有两个组件反复改visible。

### 修改的原有文件

- `scripts/apartment/floor5_visibility_policy.gd`：增加提交前约束钩子和按变化提交的队列；原B规则默认行为保留。统一提交visible、cast_shadow与必要的实例透明度，减少每帧重复属性检查。
- `RunStage6A2.bat`：启动新修正场景，不改正式默认入口。
- `STAGE_6A2B_VISIBILITY_REPORT.md`：增加“旧版本已被否定”的历史说明，保留原内容。

### 新增文件

- `scripts/apartment/floor5_region_builder.gd`：从已有B shell派生，只添加展示归属元数据，不生成新几何或碰撞。
- `scripts/apartment/floor5_region_presentation.gd`：继承原策略，约束未开放外壳与501内部展示；复用区域防抖、真实身体射线和恢复计时。
- `scripts/apartment/floor5_region_main.gd`：替换策略工厂和HUD说明。
- `scenes/apartment/stage6a2b_regions_shell.tscn`、`stage6a2b_regions_floor5.tscn`：独立修正版本。
- `tests/validate_stage6a2b_regions.gd`：107项真实场景连接、原生碰撞通行、展示恢复检查。
- `tests/capture_stage6a2b_regions.gd`：同条件前后截图和多帧采样。
- `tests/check_stage6a2b_region_images.gd`：分析真实Godot PNG的12处旧地板/周边墙像素。
- `tests/run_stage6a2b_regions_tests.ps1`：导入、解析、Smoke、专项、实际渲染和可选旧回归。
- `screenshots/stage6a2b_regions/`：22张真实截图；本报告及ignored `tests/results/stage6a2b_regions_*`证据。

家具仍是原PackedScene，Mesh总数481、光源3个；没有将模型拆成新独立商品Node。保留原A/B/C/A2及上轮B场景、资源和截图。

开发首轮检查捕获了PackedScene继承子网格元数据未被保存，导致家具残留；已在实例根节点登记归属并向子网格继承。另补充“返回房间恢复原投影标志”检查，避免把收起状态的OFF错误当作家具原始状态。最终专项、真实渲染和截图均在这些修正后重跑，没有降低断言。

## 4. 自动验证与真实渲染

| 检查 | 本轮实际结果 |
|---|---:|
| Godot导入、相关脚本解析、120帧修正场景Smoke | 通过 |
| 新区域专项headless | **107/107** |
| 同专项真实Vulkan运行 | **107/107** |
| 最终真实PNG像素检查 | **12/12** |
| 原B策略专项（提交优化后重跑） | **101/101** |
| 原A2 | **104/104** |
| 原A1、A1-B、A1-C | **54/54、70/70、84/84** |
| C1、C2、C3-A、C3-B | **41/41、22/22、39/39、41/41** |
| D1-B、姿态融合 | **73/73、54/54** |
| 原滚轮缩放 | **20/20** |
| 原相机预设、人物遮挡 | 各**49通过、1历史源码冻结失败** |

历史冻结失败仍指向 `scripts/player_controller.gd`、`scripts/survivor_animator.gd`；本次未修改。完整旧回归门禁返回非零，不能称整体全绿。保留其原始日志、测试和manifest，未删除、豁免或修改预期。旧战斗六套件270项通过，不代表本轮新增任何战斗功能。

新专项覆盖四种正交视角下的501、楼道、卫生间、返回恢复；29顶面隐藏；邻户所有非顶面Mesh退出绘制；门牌/门框/门叶存在可见；真实完整胶囊move_and_slide出门返回、连续三次往返、边界20次抖动；中间淡化值连续；家具阴影恢复；共享材质不替换；视觉变化不改变碰撞；501开关门/防夹、邻门锁闭反馈、楼梯封闭；轮廓和缩放。60fps固定步的区域权重最大单帧变化约0.0758，没有一帧从0直接跳到1。

像素检查读取真实Godot截图，按相同F1相机投影定位502～504各自地板中心及三面远侧周边墙：修正前与背景有差异，修正后12处与背景一致。这证明空盒子表面不再渲染，不是仅把地板染得更黑；仍不能代替真人对视效和操作手感的验收。

主要证据：`tests/results/stage6a2b_regions_validation.json`、`stage6a2b_regions_render_validation.json`、`stage6a2b_regions_pixel_validation.json`、`stage6a2b_regions_regression_summary.json`、`stage6a2b_regions_final_run.stdout`。最终保留检查见 `stage6a2b_regions_final_audit.json`。

## 5. 同条件实际截图

截图是实际运行渲染，由脚本定位生成，没有冒充真人操作。原图3策略为before，新规则为after；同分辨率1440×1000、同角色位置、同FOV/正交size、角度、门状态、灯光和阴影状态。原截图目录未覆盖。

- 楼道全景：[修正前](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/before_overview_F6.png) / [修正后](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/after_overview_F6.png)
- 门口近景：[修正前](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/before_corridor_501_502.png) / [修正后](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/after_corridor_501_502.png)
- [501室内](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/after_501_living.png)、[返回501](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/after_returned_501.png)、[卫生间](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/after_bathroom.png)
- [85°楼道](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/after_overview_F1.png)、[65°楼道](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/after_overview_F2.png)、[45°正向](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2b_regions/after_overview_F5.png)

## 6. 性能与代价

RTX4060 Laptop，1440×1000，F6 size9.2，玩家(-5.475,0.02,3.3)，灯光/阴影同状态，VSync关闭，预热180帧，各至少6秒，分三窗口。修正前在改动前采样；修正后在回归结束后采样，非独占硬件、非长期基准。

| 指标 | 图3旧B版本 | 最终修正版 |
|---|---:|---:|
| 采样帧数 | 3837 | 3554 |
| 总体FPS | 639.42 | 592.22 |
| 平均帧耗时 | 1.564ms | 1.689ms |
| 中位帧耗时 | 1.385ms | 1.514ms |
| P95帧耗时 | 2.488ms | 2.808ms |
| 三窗口FPS | 603.41 / 649.79 / 668.66 | 625.68 / 579.63 / 574.04 |
| Draw Calls | 667 | 307 |
| Mesh / 光源节点 | 481 / 3 | 481 / 3 |

Draw Calls减少360，但本次样本平均帧耗时增加约0.125ms，P95增加0.320ms，不能宣称无性能代价或稳定FPS提升。初版每帧重复重建静态家具决策的开销已去除：稳定状态只处理可能变化的墙/底面约束，最终属性按变化提交；淡化期间需要更新501各构件实例透明度，仍有CPU和短时透明排序开销。连续两分钟真实移动及低帧率过渡稳定性待玩家确认。

## 7. 人工验收入口

双击 [RunStage6A2.bat](E:/GameProject/PostApocalyptic3DTest/RunStage6A2.bat) 直接打开修正后的可交互场景。默认游戏入口未改，原战斗入口保留。

以下均 **待玩家验收**：

1. 站在501，确认家具、窗和卫生间完整；邻户不再展开，整体接近图1的区域展示原则。
2. E开501门走入楼道，确认效果接近图2：通道、门与边界可见，外侧没有整排空盒子，也没有浮在背景中的501家具。
3. 走近502～504，确认“门后未知”，锁门反馈与门牌正常；不要把未渲染的区域理解成可走空间。
4. 门口反复往返、小幅来回，检查0.22s过渡是否自然，是否有透明排序残影、阴影跳变或大面积闪烁；返回后家具不能永久隐藏。
5. 进入/离开卫生间，在45°、65°、85°和近远缩放下检查原动态墙体与人物轮廓。
6. 顶住剖切墙体、关门/开门，确认碰撞始终有效，不穿墙、不进入邻户或楼梯未完成区。
7. 连续自由走动至少两分钟，观察帧时间、相机、输入与区域恢复。

跳过这些项目可能漏掉门口显示错乱、透明排序、墙后人物长期不可辨认、家具阴影恢复不完整和隐藏构件造成的通行误判。自动与渲染验证不等于玩家已认可修正后的视觉目标。

## 8. 限制与边界

- 区域归属为现有五楼的轻量元数据，不是战争迷雾、探索记录或通用建筑生成器。
- 未开放房间保留完整物理/场景外壳，正常展示只留临楼道立面；远侧外墙将来对室外可见时，需要由相应室外区域展示规则接管，本轮没有街道。
- 在楼道中即使501门开着，501内部仍按非当前区域收起；没有开发开门视锥、门洞窥视或跨区域部分内容显露。
- 楼道在501内作为连接区域保留，未进一步按距离裁短，避免新增门口片段切换。
- 剖切颗粒度沿用原墙段，部分较长墙仍是整段处理；非渐变墙材质。过渡只用于区域内容，不替代真实多点墙体检测。
- 没有改变五楼布局、房屋大小、门位置、玩家碰撞体、相机参数、物资、战斗或导航；未增加邻户内部、楼层、NPC、僵尸、街道或新玩法。
- Git仍为main / 1346664，原未提交内容保留，无暂存、提交或推送。本轮到人工验收准备为止，不继续后续开发。
