# Stage 6-A.3-A.4：区域背景与视觉表现收口

状态：**已实现，自动验证及真实渲染检查已执行，等待玩家人工验收**。

本轮仅改区域表现配置及Coordinator提交前的必要决策。未修改建筑布局、家具、门碰撞/状态机、楼梯/坡面/护栏、玩家移动战斗、相机参数；没有开发三楼。

## 1. 浅灰平面的实际来源

只读运行旧A.3场景，逐个输出Mesh类型、世界变换/AABB、材质颜色、所属Zone和最终显示原因。原始证据：`tests/results/stage6a3a4_source_audit.json`及同名.log。

以下路径均以 `Apartment/` 为根，都是**已有BoxMesh**，不是本轮新增平面：

|路径|世界AABB起点|尺寸（米）|判定|
|---|---|---|---|
|NeighborRooms/Room502/ClosedVolumeFloor|(-15.55,-0.16,-2.10)|(9.20,0.16,4.20)|未开放邻户的原有底板|
|NeighborRooms/Room503/ClosedVolumeFloor|(-4.60,-0.16,2.25)|(9.20,0.16,4.20)|未开放邻户的原有底板|
|NeighborRooms/Room504/ClosedVolumeFloor|(-15.55,-0.16,2.25)|(9.20,0.16,4.20)|未开放邻户的原有底板|
|Corridor/Floor|(-6.50,-0.16,-2.10)|(2.05,0.16,10.80)|包含墙厚的实际楼道地板|
|Architecture/Floor|(-4.60,-0.16,-2.10)|(9.20,0.16,4.20)|实际501地板；从楼道看、无权限时也被换成浅灰背景|
|Architecture/BathFloor|(1.545,0,0.125)|(2.91,0.012,1.85)|实际卫生间地面|
|Stairwell/Landing05|(-7.10,-0.16,8.50)|(3.25,0.16,1.40)|五楼平台|
|Stairwell/Landing04|(-7.10,-3.16,8.50)|(3.25,0.16,1.40)|四楼平台；旧策略也可能从上层显示|
|Stairwell/FlightA/Upper|(-5.375,-1.716,9.835)|(1.35,1.646,3.425)|已有倾斜楼梯承托板，AABB包含倾斜后的高度|
|Stairwell/FlightB/Upper|(-6.925,-3.216,9.90)|(1.35,1.646,3.425)|同上|

旧A.3将23个承托/地面装饰记录归为StructureSurface，并统一设置 `structure_visible_from=zones.duplicate()`。未授权时全部套用独立、unshaded浅灰背景材质，albedo约(0.549,0.545,0.494)，源配置色为#8c8b7e。它消除了背景穿透，但把整片邻户底板及跨层支撑面也显著展示出来，形成浅灰大平面和空房间观感。

斜向边界的来源包含已有倾斜承托板及旋转相机下的矩形地板边缘，**没有证据表明旧逐片元扇形裁剪重新运行**。旧A.3的adapter/floor field已为空。未知空间的问题是显示范围与表现方式，而非材质共享污染、透明排序、DebugOnly泄漏或错误移动建筑。

本轮保留必要楼板和碰撞，没有删除这些Mesh来掩盖问题。

## 2. 最终显示规则与分类

|对象|旧A.3|新A.4|
|---|---|---|
|当前区域家具/地面|完整内容与原材质|保持完整；相机遮挡规则独立|
|未知邻区实际地板|浅灰unshaded背景，建筑家族内广泛可见|深色不透明背景，仅复用自己的几何范围，并检查配置高度|
|地板装饰接缝|被当作StructureSurface背景|改为RegionContent，无权限时隐藏，不在未知房间勾出装饰细节|
|水平楼板/平台|无门楼梯连通体获得授权后，上下层都可能显示|增加所在高程显示限制，避免五楼平台悬在四楼人物上方|
|倾斜楼梯承托|原坡面|保留原坡面，未知背景检查高度；已授权的跑梯继续使用现有相机遮挡|
|完整层高的区域外壳|建筑家族内持续显示|使用区域配置的高度范围，避免下层画面展开上层住宅外壳|
|门框/门/真实碰撞|原有逻辑|保留；既有门细节高度规则不变|
|GameInformation|区域权限+发现状态+真实LOS|完全复用，不因深色背景而增加任何授权|
|DebugOnly / Concealed|隐藏|继续隐藏，屋顶不恢复|

深色背景配置为#111a20。它表示**当前不可观察**，不是永久探索记忆，也不产生任何碰撞。背景使用独立材质实例，保留不接收/投射动态游戏阴影的处理。当前/已授权表面恢复原材质，不染黑共享资源。

门开启的60%授权阈值、50%保持阈值、0.22秒内容渐显、关闭意图立即撤销、直接邻区单跳合并、真实墙/门LOS，均沿用A.3。不开启递归邻区权限，不恢复地板或家具逐片元裁剪。

## 3. 架构与配置

调用链仍为：

`VisibilityZone三维归属/滞回 → AdjacentRegionPermissions → CameraOcclusion → Coordinator决策 → Presentation提交前调整 → 原唯一commit_decisions`。

新增的PresentationCoordinator继承旧Coordinator，只调整其**待提交字典**中的楼层视觉结果，然后调用同一个最终提交方法。没有第二个能够独立争写Mesh状态的控制器。

承托面列表在初始化时登记，提交前只遍历这些表面，不再重复扫描全部512条记录。当前场景按静态配置初始化，不提供运行中动态添加区域的管理框架。

配置字段：

- `background_footprint`：原Mesh局部XZ范围。
- `background_transform`：该Mesh的实际世界变换；旋转/平移不变成世界轴对齐巨型平面。
- `background_reference` / `background_height`：高度参考及容差区间，来自实际承托几何测量。
- `surface_storey_limit`：水平楼板在无门多高度空间中也遵守高程约束。
- 完整层高区域的壳体沿用已有 `height_reference/height_interval` 通用字段。

新区域只配置Zone、原始结构/内容成员、门连接并调用configure_presentation。测试区域使用不同ID、(24,-9,7)的位置及0.61rad旋转；核心脚本前后哈希相同，实际显示、真实LOS和敏感信息状态均被检查。详见 `scripts/visibility/REGION_PRESENTATION.md`。

## 4. 本轮文件

全部为新增文件，旧入口与已有工作区文件未覆盖：

|文件|作用|
|---|---|
|scripts/visibility/region_presentation_config.gd|颜色、成员分类、原Mesh范围及高度配置|
|scripts/visibility/region_presentation_coordinator.gd|唯一提交前的高程决策|
|scripts/visibility/REGION_PRESENTATION.md|配置说明|
|scripts/apartment/stairwell_presentation_main.gd|新入口接线及HUD标识|
|scenes/apartment/stage6a3a4_presentation.tscn|独立场景|
|RunStage6A3A4.bat|双击打开交互游戏窗口|
|tests/audit_stage6a3a4.gd|旧A.3实际Mesh与材质审计|
|tests/validate_stage6a3a4.gd|权限、实际Mesh状态、门槛/卫生间/原生LOS集成专项|
|tests/validate_stage6a3a4_presentation.gd|边界、高程、材质、原几何及碰撞专项|
|tests/validate_stage6a3a4_journey.gd|真实五楼↔四楼通行|
|tests/fixtures/presentation_visibility_extension.gd/.tscn|改变ID、朝向及高度的配置扩展|
|tests/capture_stage6a3a4.gd|8个位置×4种视角前后对照|
|tests/check_stage6a3a4_frames.py|实际帧颜色、机位一致性、外部背景检查与对照排版|
|tests/benchmark_stage6a3a4.gd|相同位置/分辨率前后性能采样|
|tests/run_stage6a3a4_tests.ps1|可重复运行的专项/渲染/回归入口|

配套Godot.uid、结果JSON/log、screenshots/stage6a3a4一并保留。生产场景仍为原512个Geometry，没有新增遮盖Mesh、Shader、灯光或碰撞。

## 5. 自动与真实渲染验证

|检查|真实执行结果|
|---|---|
|10个新增GDScript语法检查|通过|
|新场景headless Smoke、导入|通过|
|表现与跨层专项|26/26|
|集成专项headless|53/53|
|集成专项Forward+ Vulkan真实渲染|53/53|
|原生碰撞上下楼、相机、停走/往返|60/60|
|同机位图片与实际帧像素检查|72/72|
|旧A.3集成 / 结构 / 权限|53/53、10/10、10/10|
|旧A.2 / A.1|57/57、40/40|
|旧安全门C / 卫生间C|111/111、84/84|
|滚轮缩放 / C.3-B战斗|20/20、41/41|

原生通行仍采样2615个物理帧，离地0帧，脚底与视觉踏步最大偏差约0.089m；并非传送或直接设置Y伪造路线。门槛专项包括20次真实碰撞往返。

首轮把A.3检查复制到新入口时出现51/53：两项要求“从五楼持续显示四楼底板”的旧表现假设与本轮跨楼层收口相冲突。保留了 `stage6a3a4_initial_legacy_assumptions.log`。A.4新增检查明确验证“五楼承托保留、四楼未知底板不展开”；原A.3测试文件和断言没有修改，原入口重跑仍53/53。

**历史冻结门禁仍不是全绿**：camera_presets 49/50、player_occlusion 49/50，各自唯一失败仍是旧manifest对player_controller.gd、survivor_animator.gd的历史哈希断言。未修改manifest/断言。所有运行日志独立保留，不能把这些历史失败算作本轮通过。

## 6. 实际截图

八个位置每处均提供F2/F5/F6及F1，before/after共64张原生1440×1000截图。捕获脚本固定相同坐标、门角度、相机变换、size、focus；前后不通过换角度掩盖问题。

|命名前缀|位置|
|---|---|
|01_home_closed|501室内、门关闭|
|02_home_open|501室内、门打开|
|03_hall_closed|楼道、501门关闭|
|04_hall_open|楼道、501门打开|
|05_bath_gate|卫生间门口|
|06_stair_gate|楼梯间门口|
|07_fifth_landing|五楼楼梯平台|
|08_fourth_landing|四楼楼梯平台|

路径为 `screenshots/stage6a3a4/before/前缀_F视角.png` 与 `after/前缀_F视角.png`。

对照排版图：comparison_01_home_closed_F6、comparison_03_hall_closed_F6、comparison_06_stair_gate_F6、comparison_08_fourth_landing_F6.png。四个contact_F*.png分别汇总对应视角的八个位置。排版只缩放/加标签，没有补画或生成场景内容。

帧检查包含：实际未知背景变暗；当前区域地面未被邻区覆盖；原本建筑外部的背景像素没有被新增平面填充。它不是只检查Mesh.visible。

## 7. 性能

最终同条件采样数据及解释见 `tests/results/stage6a3a4_perf_before.json`、`stage6a3a4_perf_after.json`。

|位置/视角|FPS A.3→A.4|平均帧ms A.3→A.4|P95 ms A.3→A.4|Draw Calls A.3→A.4|
|---|---|---|---|---|
|501/F6|272.50→261.83|3.670→3.819|5.224→5.712|661.0→661.0|
|楼道/F6|296.72→256.26|3.370→3.902|4.383→6.238|435.3→420.8|
|楼梯转角/F6|262.13→255.07|3.815→3.920|5.791→5.303|377.8→235.9|
|四楼/F2|276.68→267.96|3.614→3.732|5.251→5.503|333.7→184.5|

每位置预热80帧后采样240帧，1440×1000、size9.2，使用同一RTX4060 Laptop GPU、Forward+ Vulkan、相同初始门状态与位置。两个版本均以前台窗口、**关闭VSync**运行此独立基准，没有修改游戏默认配置。

新版平均帧间隔在此轮多出约0.106～0.532ms，不能宣称性能提升或零成本。Coordinator决策均值旧约2.181～2.525ms，新约2.476～2.747ms；相机检测旧0.113～0.157ms，新0.123～0.202ms（精确数值见原始JSON）。楼层收口减少了部分视角的Draw Calls，但CPU规则与渲染调用并非同一指标。

部分无焦点截图HUD曾显示6～8FPS，不能与此受控基准混用；最终采集脚本也采用前台、关闭VSync以避免后台窗口限速。最终未混用这些瞬时HUD值作为性能结论。这是短时单轮采样，不代表长期稳定性、GPU极限或保证性能提升，实际自由探索仍需玩家检查。

## 8. 已知限制与待验收

- 深色区域是原有地面高程上的背景，边界随建筑真实投影；不模拟严格门洞视锥，也不记录永久探索。背景色及与墙体的对比仍是人工美术判断。
- 水平楼板使用有限高度范围；通行已验证，但斜向视角中其他上层墙体/扶手的观感仍需实机自由移动确认，不能由固定截图完整保证。
- 当前活动区域立即完整；开门普通家具沿用渐显，关门内容立即撤销。是否存在可感知的亮度变化或门口闪烁需人工检查。
- 信息隔离接口已回归验证，未来正式敌人/物资/提示仍需明确注册并接入；没有新增AI、探索系统或战争迷雾。
- 没有新增区域或三楼；旧入口有意保留旧表现，验收应使用A.4。

## 9. 人工验收

双击 `RunStage6A3A4.bat`。WASD移动，E操作门，滚轮缩放、Home复位，F1=85°、F2=65°、F5=45°、F6=45°斜向；原调试与遮挡快捷键保留。

1. 在501关门/开门，确认当前家具完整、邻区为稳定深色背景；开门后内容按权限恢复。
2. 501与楼道连续进出，门口左右慢移及前后短按；反复开关门。
3. 进入/离开卫生间，确认无错误透视、透明残留或家具残缺。
4. 进入楼梯间，五楼走到四楼再返回，转角停走/转身，观察平台与墙体。
5. 四种相机与不同缩放重复，连续自由探索至少两分钟。

**以上均待玩家人工验收**。跳过会遗漏背景穿帮、跨楼层透视、门口闪烁、权限残留；这类问题可能在未来复制楼层时批量放大。自动化通过不等于人工验收通过。

## 10. Git与工作区

main / `e36215ec8006291864632d4bf755aeaa1c8b2127`。原有Stage6-A.3系列未提交内容完整保留，本轮未提交、推送、暂存、reset或clean。

起始记录559个已有源码/场景/材质/测试文件，最终哈希复核全部不变，见 `stage6a3a4_preservation.json`。tracked diff、cached diff与git diff --check均为空；工作区仍有保留的未跟踪阶段文件，不能说工作区干净。本轮新增独立入口、配置和测试，旧文件未覆盖，默认游戏入口未改变。

完成本轮后停止，等待玩家人工验收。
