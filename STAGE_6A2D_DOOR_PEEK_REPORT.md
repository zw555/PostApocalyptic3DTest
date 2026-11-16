# Stage 6-A.2-D：501房门与公共楼道的局部视野

2026-11-16，Godot 4.5.2，GodotPhysics3D / Vulkan Forward+。

**已实现；逻辑、真实渲染与相关回归已执行；D阶段玩家人工验收待执行。** 玩家对C阶段“整体效果良好”的反馈已记录，不能把它当作D阶段已经验收。

## 1. 根因

读取实际C代码后确认，邻区并非始终无条件隐藏，也不是Area3D配置错误；C已有局部裁剪，但用错了观察者。

- `floor5_connected_visibility.gd.portal_allows / could_see_through_portal` 和 `portal_view.gdshader` 都沿**相机平行方向**把表面投到门平面，而非从玩家观察点判断视线。
- F1/F2/F5的相机方向与西侧门面接近平行，分母接近0时直接排除；F6反向看501时常得到负的投影距离，同样被排除。于是玩家实际能看见的内容，相机裁剪规则却禁止绘制。
- C缓存只关注相机方向、开/关布尔值及楼层变换，没有跟随玩家位置与门扇角度重算通视范围。
- C靠普通相机深度判断门板遮挡，没有玩家到目标的原生视线检测。之前少量相机像素检查只证明特定点的画面变化，没有覆盖玩家移动、四视角和反向观察。

楼道已有有效验证物体：502房门/门牌、配电箱、快递纸箱、墙边设施和地板；本轮没有为了截图新增物品。501与楼道的原关联 `connects_regions = [apartment_501, corridor_f05]`、门洞位置/宽高继续使用，未把世界坐标写入视野算法。

## 2. 新关系：三种判断分离

| 层次 | 实现 | 不等同于 |
|---|---|---|
| 允许参与绘制 | 当前区域、连接区域、未开放状态、玩家门洞锥体与Mesh包围盒 | 不能据Node.visible=true宣称整个物体可见 |
| 玩家实际通视 | 玩家观察点、真实门洞、当前门板Box、原生物理射线和片元裁剪 | 不用相机方向替代玩家视线 |
| 相机能否拍到 | 原Camera3D视锥/深度，以及已有墙段局部剖切 | 玩家看得见不代表屏幕每一部分都无遮挡 |

观察点位于玩家上方1.50m，可配置；邻区最大观察距离5.0m，可配置。它不是战斗发现距离，不影响移动、攻击或AI。

### 关闭、部分开启、完全开启

- **关闭**：邻区权限立即关闭，非当前区域过渡权重也归零；不保留关门后的透视尾巴。
- **部分开启**：采用真实门板当前变换及原BoxShape3D尺寸；Shader在线段上做门板包围盒相交检查，物理射线也包含门板。不是看到“open=true”就放开全门洞。
- **完全开启**：允许从玩家位置穿过门洞的局部锥体观察邻区，仍受墙、家具和距离约束。
- **反向观察**：使用同一个连接、同一组门洞配置和射线规则，不另造楼道→501专用坐标分支。

相机仰俯角、滚轮缩放不改变玩家的物理视线；它们只改变构图、实际深度遮挡和需要处理的前景墙。

## 3. 原生遮挡与局部绘制

复用C的材质缓存、区域优先级、统一最终决策和Stage 5-A查询代理。

- 没有整组打开邻区根节点。大地板/墙体仍保留原Mesh，以片元方式裁剪，避免只显示/隐藏一个巨大Mesh就展开整条走廊。
- 从玩家到门洞采样12×8条确定性射线，使用原生物理层1，并排除玩家自身。采样保存最近物理命中的平面到一张小型浮点纹理；片元沿自己的实际方向计算遮挡距离，避免平地在相邻射线之间被切成格子。
- 门板另有按当前原生碰撞姿态的精确Box线段检查，不依赖稀疏采样判定门板开口。
- 大物体由包围盒锥体筛选和多射线/片元遮挡共同处理，不只看一个中心点。标签文字另用原生视线许可，不只按门洞几何范围显示。
- 玩家移动或门旋转时按物理步刷新；静止时约每0.10s复核。地图没有探索记忆，关门即恢复隐藏。
- 镜头对“玩家已经允许观察”的目标仍可能被墙挡住，因此从现有Stage 5-A代理层独立检测相机到这些目标的遮挡，只处理命中的既有墙段Upper；门扇不做虚化。只检测相机视锥内目标，缩放变化也会重新判断。
- 新功能仍在同一策略内、最终提交前决定visible/cast_shadow。没有另起脚本争抢墙材质；没有增加Camera3D、SubViewport、门内第二场景、模糊效果、战争迷雾管理器或新物理碰撞体。

502～504的远侧占位及内容继续隐藏。墙体剖切不会改变其物理阻挡，也不会生成邻户内部。

## 4. 实际修改文件

唯一修改的既有文件：

- `scripts/apartment/floor5_connected_visibility.gd`：增加Shader选择和观察上下文失效钩子；C默认仍使用原相机裁剪Shader与原缓存条件，供D最小扩展。

新增：

- `scripts/apartment/floor5_player_peek.gd`：玩家门洞锥体、原生视线采样、门板姿态绑定、标签许可、相机遮挡独立检查。
- `scripts/apartment/floor5_player_peek_main.gd`：D策略工厂及简短HUD说明。
- `materials/apartment/player_portal_view.gdshader`：玩家视线、门板相交和物理遮挡片元裁剪。
- `scenes/apartment/stage6a2d_floor5.tscn`：复用**原C shell**，不派生新建筑/家具布局。
- `RunStage6A2D.bat`：独立交互入口，原B/C入口与正式默认入口保留。
- `tests/inspect_stage6a2d.gd`、`validate_stage6a2d.gd`、`capture_stage6a2d_views.gd`、`capture_stage6a2d.gd`（简短入口）、`run_stage6a2d_tests.ps1`。
- `screenshots/stage6a2d/`、本报告；原始结果在ignored的`tests/results/stage6a2d_*`。

`floor5_safe_door.gd`、C门扇场景/尺寸/铰链、玩家胶囊、相机、战斗、布局及原材质资源均未修改。最终保留检查见 `stage6a2d_final_audit.json`。

## 5. 自动与真实渲染验证

| 检查 | 实际结果 |
|---|---:|
| Godot导入、相关脚本解析、D场景120帧Smoke | 通过 |
| D逻辑与真实场景组件专项headless | **84/84** |
| 同专项真实Vulkan运行 | **84/84** |
| 实际栅格渲染检查 | **25/25** |
| 原C安全门/区域专项headless | **111/111** |
| 原B区域 / B基础 / A2 | **107/107、101/101、104/104** |
| A1 / A1-B / A1-C | **54/54、70/70、84/84** |
| C1 / C2 / C3-A / C3-B | **41/41、22/22、39/39、41/41** |
| D1-B预备攻击 / 姿态融合 | **73/73、54/54** |
| 原滚轮缩放 | **20/20** |
| 原相机预设 / 人物遮挡 | 各**49通过、1历史源码冻结失败** |

历史失败仍是旧manifest对 `player_controller.gd`、`survivor_animator.gd` 的字节冻结，两文件本轮未改。旧回归运行器的非零结果继续保留，不删除断言、不更新预期、不称整体门禁全绿。本轮未声称重跑所有历史导航/物资专用套件。

D专项检验了：

- 同一合法站位下，闭门可见楼道地面样本0/240；开15°为42/240；全开为52/240。部分开口确实受到门板限制，不是只检查状态字符串。
- 靠近门口合法站位为74/240，远处更少；横向移动改变配电箱/纸箱的许可，并由原生射线确认。
- 门洞几何允许、但被真实墙体或床挡住的点会被拒绝。
- 四角度下玩家视线独立于相机，反向观察501成立；门关上后立即清除非当前内容，即使F7显示结构对照也不透视。
- 卫生间动态墙、原有屋顶规则、未开放区域、碰撞/门扇姿态、真实完整胶囊出门与返回4次都正常。
- 原C的20次开关、20次往返、低物理频率安全旋转等111项重新执行通过；门代码未被D改写。

### 真实渲染证明

渲染测试临时给**已有的邻区地板，及反向观察时已有的床等表面**着色，统计实际屏幕像素。原生几何、玩家视线、Shader和相机深度全参与；测试完恢复材质。没有添加新物体，没有用着色诊断图冒充美术截图。

| 视角 | 关门向外 | 开15°向外 | 全开向外 | 全开反向501 | 反向关门 |
|---|---:|---:|---:|---:|---:|
| F1 85° | 0 | 27444 | 35795 | 68149 | 0 |
| F2 65° | 0 | 24929 | 32528 | 57354 | 0 |
| F5 45°正向 | 0 | 20057 | 25989 | 44729 | 0 |
| F6 45°斜向 | 0 | 19114 | 24627 | 48226 | 0 |

另检查了床遮住更深处地面的实际像素，未出现目标地板透过床显示。以上是指定场景/采样的证据，不是对任意复杂模型逐像素光线追踪的承诺。

原始证据：`stage6a2d_validation.json`、`stage6a2d_render_validation.json`、`stage6a2d_raster_validation.json`、`stage6a2d_final_run.stdout`。完整旧回归见`stage6a2d_full_run.stdout`及`stage6a2d_regression_summary.json`。

## 6. 实际截图与性能

最终自然截图清单在`stage6a2d_before_render.json / after_render.json`的`natural_screenshots`，共32张配对图。目录还保留13张开发预览；40张临时着色图只放在ignored的测试结果目录，不作为美术验收图。

- [关闭](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_closed.png)、[部分开启15°](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_partial_15.png)、[完全开启](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_open.png)
- [门内一侧](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_left.png)、[门内另一侧](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_right.png)、[远离门口](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_far.png)
- [反向观察：原C](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/before_reverse_open_F6.png) / [本轮D](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_reverse_open_F6.png)、[反向关门](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_reverse_closed.png)
- [85°](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_open_F1.png)、[65°](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_open_F2.png)、[45°正向](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_open_F5.png)、[45°斜向](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2d/after_inside_open_F6.png)。

均为Godot实际渲染，由脚本定位，不冒充玩家操作。配对保持1440×1000、相同相机、角度、缩放、玩家位置、门角度与灯光。

性能固定条件：RTX4060 Laptop，F6 size9.2，玩家(-5.475,0.02,3.3)，门全开，灯光/阴影同状态，VSync关、无固定渲染FPS，预热180帧，每版至少6秒、3窗口。

| 指标 | C版 | D版 |
|---|---:|---:|
| 样本帧数 | 3355 | 3336 |
| FPS | 559.03 | 555.97 |
| 平均 / 中位帧耗时 | 1.789 / 1.618ms | 1.799 / 1.640ms |
| P95 | 2.928ms | 2.957ms |
| 三窗口FPS | 534.04 / 559.32 / 586.16 | 555.56 / 571.84 / 541.37 |
| Draw Calls | 308 | 367 |
| Mesh / 光源数 | 481 / 3 | 481 / 3 |

新增可见邻区内容使Draw Calls增加59，未增加Mesh/光源。平均帧耗时约增加0.010ms，短测不足以保证所有移动状态/机器都无退化。扇形一次更新约1.043ms（该次完整捕获平均，包含纹理更新，独立于帧平均）；静止约10Hz复核，移动与门旋转时更频繁。另有独立相机遮挡查询，不能把扇形耗时冒充全部开销。两分钟实际移动与狭窄开口抖动仍需人工观察。

## 7. 人工验收入口

双击 [RunStage6A2D.bat](E:/GameProject/PostApocalyptic3DTest/RunStage6A2D.bat)。保留原B/C入口及正式默认入口。

以下均为 **待玩家人工验收**：

1. 在501关门，确认门后内容不透视。
2. 按E开门，观察从小开口到全开时邻区内容进入视野，不能整条楼道突然展开。
3. 在门内靠近、远离、左右移动，尝试观察配电箱、502门及另一侧纸箱；不同位置不应固定显示同一片内容。
4. 进入楼道后反看501，检查床/入口附近局部可见，不能一并展开完整公寓。
5. 从两侧关门，确认内容立即隐藏；门板碰撞与安全反向行为保持C版。
6. F1/F2/F5/F6和近远缩放下重复；相机自身可能遮住部分玩家可见内容，检查局部墙段剖切是否适度。
7. 进出卫生间，再连续开关门/进出至少两分钟，重点观察门槛区域的切换、裁剪边缘、帧时间与残留状态。

跳过人测可能遗漏关门透视、极小开口漏显、开门看不到内容、整片区域闪烁、门板与视线不一致或裁剪观感生硬。自动84项与25项渲染检查不等于人工验收通过。

## 8. 已知限制

- 当前只处理已配置的一处501—楼道连接，不递归连接其他房间；没有探索记忆、完整战争迷雾或门内第二相机。
- 除门板精确Box检查外，其他遮挡使用有限物理采样和平面近似；很小/很薄遮挡物、复杂曲面或遮挡边缘仍可能有保守裁剪或少量漏显，需要人工确认。已实际检查现有墙、床与门；不能泛称任意未来资产都精确通过。
- 剖切粒度沿用原Upper墙段，较长墙仍可能整段降为低墙。局部视野边界呈锥体/距离截断，部分家具可能出现裁切截面或黑背景间隔；没有为观感擅自加入地面记忆、模糊或新装饰。
- 门槛附近继续沿用C的区域稳定与短时过渡；连续穿越时的细微闪动、标签整字显隐和边缘质量仍是人工项目。
- 眼高是当前站立角色原型值，未开发蹲伏或姿态联动。
- Git为main / 1346664；原未提交内容保留，无暂存、提交、推送。本轮完成后停止，等待D阶段反馈。
