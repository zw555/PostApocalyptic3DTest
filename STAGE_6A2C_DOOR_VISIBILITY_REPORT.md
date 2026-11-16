# Stage 6-A.2-C：真实门扇、安全旋转与区域视野

2026-11-16。Godot 4.5.2.stable.official.6ce3de25a，GodotPhysics3D，Vulkan Forward+。

**已实现、自动与真实渲染验证通过；玩家人工验收待执行。** 不以本报告替代玩家对贴门操作、剖切范围和切换观感的认可。

## 1. 三项实际根因

### 501房门

旧 `floor5_door.gd` 在moving时直接拒绝E；受阻后停止，部分开启时再次E只重试原desired_open，不允许反向。实测玩家在(-4.05,0.02,1.05)时约开8.594°便受阻；第二次E仍朝同方向，角度不变。不是玩家胶囊过大，也不是必须禁用碰撞才能打开。

此外，旧门扇在门洞内偏向铰链侧：铰链Z=1.64、门板中心Z=1.15，门洞/门框中心Z=1.11。完整旋转包络检测发现铰链侧板角的墙体净空不足。曾验证沿墙厚移动会压缩床侧净空，因此最终**只沿门洞将铰链Z减0.04m**，把原门板居中；没有移动床、墙或门洞。

| 测量项 | 实际值 |
|---|---|
| 视觉门板 / 原生BoxShape3D | 都为0.98×2.10×0.045m |
| 旧铰链 → 新铰链 | (-4.48,0,1.64) → (-4.48,0,1.60) |
| 关闭yaw / 全开yaw | π/2 / 0.10rad，均保留 |
| 开启转角与方向 | 约84.27°，固定向室内+X方向，不能根据玩家位置换侧 |
| 角速度 | 原4.5rad/s不变 |
| 玩家胶囊 | 半径0.27m、直径0.54m、高1.72m；移动3.2m/s不变 |
| 门框Mesh之间可见净宽 | 约1.065m |
| 原门洞横向原生射线扫描 | Y=1m、排除门扇时Z约[0.550,1.664]，宽1.114m |

射线宽度仅是单条水平线的通透范围，不当成完整胶囊通行保证。门框网格原本没有各自独立的立柱碰撞，周围墙段和门楣约束结构门洞；本轮没有删除、缩小或禁用这些既有碰撞。实际可通行性另用完整胶囊查询及move_and_slide验证。

原始测量与复现：`tests/results/stage6a2c_measurements.json`、`stage6a2c_inspection.log`。

### 501内仍看到完整楼道

上一版 `floor5_region_presentation.gd` 仅收起非当前501和邻户远侧空壳，楼道始终是boundary；因此即使门关闭，楼道仍参与完整渲染。剖切墙体又会扩大观察范围。不是Area3D误触发；现有区域是楼层局部Rect2与节点元数据。

### 前景墙遮住活动区域

旧C/B检测复用Stage 5-A多点身体射线，只处理挡住头、胸、髋的墙，不检测整段楼道的地面可读性。只要人物没有被挡，遮住楼道其他部分的前景墙就保留。

旧A1固定半空间规则没有在当前B主场景同时运行，未发现两套材质脚本互相争抢的证据。但B中按房间ID/层级进行整组显示，确实不足以表达门洞视线。本轮保留场景内配置，运行算法不嵌入五楼绝对坐标或固定yaw=35°分支。

## 2. P0：门状态与安全旋转

新501门组件继承原门，沿用稳定door_id、门板、StaticBody3D、完整CollisionShape3D和E目标选择；只在独立C场景启用。原门脚本、邻户锁门、楼梯锁门及旧场景行为保留。

| 状态 | 行为与交互 |
|---|---|
| CLOSED | 保持完整实体碰撞，E开启 |
| OPENING | 每个物理步受控旋转；E立即反向关闭 |
| OPEN | 实体门板仍在全开位置，真实让出的门洞可通行；E关闭 |
| CLOSING | 同样执行扫掠检测；E立即反向打开 |
| BLOCKED_OPEN / BLOCKED_CLOSE | 停在最后安全角度；保留目标，每0.10s重试；让位后自动继续，E可反向 |

关键约束：

- 从未关闭门扇collision_layer或CollisionShape3D.disabled，没有玩家碰撞例外，没有改变胶囊，没有瞬移解围。
- 门板、碰撞体和原轮廓查询代理同步到同一旋转姿态；完整物理碰撞是原生门板，不是代理层。
- 单步转角再细分为最多0.012rad的区间。以区间中间姿态的OBB，加上旋转位移上界 `2R·sin(|Δ角|/4)` 的XZ扩展，包含整条旋转弧；不是只查最终姿态。
- 命中后7次二分求最后已验证安全的小角度，提交安全姿态并等待。不会把门提交到已知碰撞角度。
- 查询使用原门板完整高度，不再沿用旧检查盒的2cm高度缩减。只排除自身以及顶面与门底接触的既有水平支撑地板；墙、门楣、家具与角色继续参与。
- 仍有合理的物理让位要求，但原出生点附近存在真实净空，可自动恢复，不再只能重复“请退开后按E”。

### 原生接触容差与测试口径

玩家主动持续顶住缓慢旋转的门时，原生CharacterBody接触查询出现约5.534mm接触深度；这不等于穿过门板。项目未改动的GodotPhysics3D接触允许值为0.01m。[Godot 4.5对应配置说明](https://docs.godotengine.org/en/4.5/classes/class_projectsettings.html#class-projectsettings-property-physics-3d-solver-contact-max-allowed-penetration)。

早期“任何intersect_shape接触都算穿门”的断言因此失败。最终没有把碰撞关掉，也没有修改引擎容差：门旋转接近**静止**玩家仍严格要求无重叠；玩家主动顶门则同时校验仍在门板原侧、没有越过阻挡平面，接触深度不超原引擎值。原失败日志保留，最终结果记录实际接触样本和容差，**不宣称数学意义上所有帧绝对零接触**。

## 3. P1：当前区域、门洞与前景墙

### 区域与楼层

沿用六个区域ID、楼层ID、0.10m边界余量、0.12s区域稳定时间。当前五楼29块顶面继续隐藏；502～504的内容及远侧空壳仍不展开，临楼道门/门框/门牌继续存在。

### 501内

当前501保留原材质、家具、地板、北窗与卫生间。门关闭时不渲染非当前楼道。门打开后，相邻楼道只能出现在**相机平行视线穿过实际门洞矩形**的范围内，门板本身继续通过普通深度测试遮挡视线。不会因墙被剖切就看清整条楼道。

### 公共楼道内

楼道是完整活动区域，不要求每个地面点都落在人物身体射线上。配置在场景中的边界墙法向，与当前正交相机朝向比较：当前活动区域的前景墙Upper进入低墙剖切，保留Lower、边界和碰撞。非前景墙恢复原状态；85°近垂直视角不做不必要的整段区域剖切。F7仍可对比完整展示墙体。

501非当前内部也遵守门洞投影视野；不是关门/开门后无条件展示完整公寓。高角度或接近与门面平行的视角，可能看不到相邻地面，这是门洞几何关系，不强行增加固定展示补丁。

### 门洞裁剪的范围

整条楼道地板是一个原Mesh，仅切换Node.visible会再次展开全走廊，因此加入一个小型门洞Shader：按当前正交方向，把非当前表面的世界点投到门平面，超出门宽/高度或门在视线反方向时丢弃片元。包围盒先做保守筛选，减少不必要绘制。

当前区域稳定后恢复原StandardMaterial3D；非当前区域与短暂切换才使用按原材质缓存的门洞材质，保留基础颜色、贴图UV、粗糙度、金属度、发光及玻璃alpha。区域内容用0.22s稳定有序溶解过渡，材质不每帧创建，不修改共享原资源。字体标签用其中心位置保守控制，不替换字体Shader。

这不是战争迷雾或通用VisibilityManager，只处理当前一处501—楼道连接。门洞位置、宽高、连接区域、墙段法向和可读区域均来自场景配置；运行时转换至世界坐标。当前正交相机、滚轮与Home参数未改。

## 4. 显示控制关系

```text
楼层覆盖层隐藏 + 未开放内容隐藏
             ↓
当前区域 / 门洞局部视野
             ↓
活动区域前景墙剖切 + 原身体多点局部遮挡
             ↓
同一策略的最终决策表与一次显示提交
             ↓
原Stage 5-A人物轮廓读取最终可见源
```

策略继承已有 `floor5_visibility_policy.gd`，继续使用提交前约束钩子和统一visible/cast_shadow提交；自己的门洞材质/实例参数也由同一策略管理。主场景update_cutaway仍不写Mesh。门组件只负责物理/门姿态及查询代理，不负责隐藏建筑。

## 5. 实际文件

唯一修改的既有源文件：

- `scripts/apartment/floor5_main.gd`：门发现从“脚本完全相等”改为识别原门脚本继承链，旧门与安全派生门都可注册；旧入口默认行为不变。

新增：

- `scripts/apartment/floor5_safe_door.gd`：安全旋转、部分状态反向和受阻自动重试。
- `scripts/apartment/floor5_connected_builder.gd`：派生C shell，配置门洞与区域边界，门扇居中。
- `scripts/apartment/floor5_connected_visibility.gd`：门洞视野、前景墙和统一显示决策。
- `scripts/apartment/floor5_connected_main.gd`：C场景策略与HUD提示。
- `materials/apartment/portal_view.gdshader`：非当前区域门洞片元裁剪。
- `scenes/apartment/stage6a2c_shell.tscn`、`stage6a2c_floor5.tscn`：独立验证场景。
- `RunStage6A2C.bat`、`RunStage6A2CLowPhysics.bat`：普通与10Hz物理交互测试入口。
- `tests/inspect_stage6a2c.gd`、`validate_stage6a2c.gd`、`capture_stage6a2c.gd`、`check_stage6a2c_images.gd`、`run_stage6a2c_tests.ps1`、`run_stage6a2c_low_physics.gd`。
- `screenshots/stage6a2c/`：28张实际Godot前后PNG；本报告及ignored的`tests/results/stage6a2c_*`证据。

旧A1/A/B/C、A2/B场景、资源、截图和入口全部保留。原 `RunStage6A2.bat`、正式project.godot默认入口、玩家、AI和战斗代码均未改。

## 6. 自动与真实渲染结果

| 检查 | 本轮实际结果 |
|---|---:|
| Godot导入、相关脚本解析、C场景120帧Smoke | 通过 |
| 独立10Hz物理入口Smoke | 通过 |
| C专项headless | **111/111** |
| 同专项真实Vulkan运行 | **111/111** |
| 实际PNG像素检查 | **4/4** |
| 原B区域专项 / 原B基础专项 | **107/107、101/101** |
| 原A2 | **104/104** |
| 原A1 / A1-B / A1-C | **54/54、70/70、84/84** |
| C1 / C2 / C3-A / C3-B | **41/41、22/22、39/39、41/41** |
| D1-B / 姿态融合 | **73/73、54/54** |
| 原滚轮缩放 | **20/20** |
| 原相机预设 / 人物轮廓 | 各**49通过、1历史源码冻结失败** |

专项包含真实物理帧和查询：

- 从门内、门外开门，贴门受阻，运动中E反向，部分状态反向，退开后自动恢复，关门防夹。
- 关闭/30°原生完整胶囊路径不可通行；60°实际路径可以通过。不是仅依据角度变量得出结论。
- 20次完整开关循环、20次公寓—楼道往返；门板在采样中保持有效原生碰撞与视觉姿态一致。
- 30/10/5Hz下受阻与恢复；另在2Hz下构造“起点终点都安全、旋转弧中有玩家”的情况，仍停在中途安全角度，证明不是只检查终点。原生扫掠查询约7000次。
- 四种正交视角、当前区域恢复、卫生间动态墙、反向相机选择另一侧前景墙、未开放空间隐藏、原结构碰撞不变。
- 首次打开门也显式初始化裁剪实例参数，避免先前未发生区域切换时使用默认全可见值；有针对性回归。
- 真实截图证明远楼道由可见变为背景，门洞内实际地面仍绘制，关/开门像素发生变化。

原整体回归门禁仍不是全绿：两项旧manifest字节冻结指向 `player_controller.gd` 与 `survivor_animator.gd`，本轮未改它们。测试、断言、manifest均未删除或豁免。战斗六套件270项通过；本轮没有声称重跑所有历史导航、搜刮专用套件。

执行记录：先执行 `tests/run_stage6a2c_tests.ps1 -Capture -Regression`，旧回归完整运行并保留冻结失败；之后对最终显示缓存/首次门洞参数初始化重跑C专项、真实渲染与截图。最初像素取样点被已打开的门板遮住，不能作为地面证据，已换为实际门洞视线内、未被门板遮住的固定地面点，并用同一相机投影重新分析真实PNG。原失败记录保留，最终4/4在 `stage6a2c_pixel_validation.json`。

证据：`stage6a2c_validation.json`、`stage6a2c_render_validation.json`、`stage6a2c_final_run.stdout`、`stage6a2c_pixel_validation.json`；旧回归原文在`stage6a2c_full_run.stdout`与旧套件日志；文件保留检查在`stage6a2c_final_audit.json`。

## 7. 截图与性能

截图同为1440×1000、相同坐标/角度/缩放/灯光和对应门状态，非AI生成。由脚本定位，不冒充真人操作。

- [501观察：修改前](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/before_501_closed.png) / [修改后](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_501_closed.png)
- [楼道前景墙：修改前](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/before_corridor_501_502.png) / [修改后](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_corridor_501_502.png)
- [关门观察](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_aperture_closed.png) / [开门局部视野](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_aperture_open.png)
- [85°](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_overview_F1.png)、[65°](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_overview_F2.png)、[45°正向](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_overview_F5.png)、[45°斜向](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_overview_F6.png)、[卫生间](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6a2c/after_bathroom.png)。

性能：RTX4060 Laptop，1440×1000，F6 size9.2，玩家(-5.475,0.02,3.3)，相同灯光/阴影与开门状态，VSync关闭、不固定渲染FPS，预热180帧，各采样至少6秒，拆分3窗口。

| 指标 | 原B区域版 | 最终C版 |
|---|---:|---:|
| 样本帧数 | 3071 | 2952 |
| FPS | 511.76 | 491.82 |
| 平均帧耗时 | 1.954ms | 2.033ms |
| 中位 / P95 | 1.734 / 3.457ms | 1.835 / 3.311ms |
| 三窗口FPS | 550.99 / 516.58 / 473.67 | 543.00 / 451.75 / 489.13 |
| Draw Calls | 307 | 308 |
| Mesh / 光源数 | 481 / 3 | 481 / 3 |

平均增加约0.079ms，本短样本不能宣称性能提升或完全无退化。稳定状态已缓存静态家具决策，包围盒门户筛选只在视向、门状态或楼层变换改变时重算；原先每帧重复遍历全部静态材质的开销已去除。区域过渡与门运动会产生额外工作，长期移动和低配置机器仍待实测。

## 8. 人工验收入口与步骤

普通：[RunStage6A2C.bat](E:/GameProject/PostApocalyptic3DTest/RunStage6A2C.bat)。

低频物理：[RunStage6A2CLowPhysics.bat](E:/GameProject/PostApocalyptic3DTest/RunStage6A2CLowPhysics.bat)，单独测试进程10Hz，关闭窗口结束，不写项目配置。原B入口继续保留。

以下全部为 **待玩家人工验收**：

1. 门内贴近门板按E立即走门洞，门没有让出空间前不能穿过。
2. 站在旋转路径上，观察门是否安全停下；半开时再E应能反向。让开后确认可继续开启。
3. 门外返回、关门时占据运动范围，确认没有夹进墙体、位置跳变或碰撞提前消失。
4. 至少10次公寓—楼道往返，结合连续开关两分钟，检查是否存在状态死锁。
5. 501床边关门观察，确认看不到整条楼道；打开门，按实际相机视线观察门洞局部，不要求85°视角强行看穿垂直门。
6. 楼道中段观察较完整地面和通道；切换F1/F2/F5/F6，检查前景剖切会变化，非前景墙不无故消失。
7. 返回501后检查楼道剖切恢复；进入卫生间检查身体局部遮挡及人物轮廓。
8. 用10Hz入口重复贴门、反向、立即移动，观察门板与碰撞位置；墙被剖切时仍不能穿过。

WASD、E、滚轮/Home、R、F3/F4灯光阴影、F7墙体对比、F8遮挡调试、F9轮廓保持可用。未完成人测，不标记阶段最终验收通过。跳过测试可能遗漏逃生卡门、关门夹人、低频穿透、隔墙看清邻区、前景墙挡住未来交互目标和区域恢复异常。

## 9. 已知限制与保留边界

- 未开发邻户内部、其他楼层、楼道之外区域、NPC、僵尸、物资或新战斗。当前场景没有僵尸实例，不能声称已完成人与僵尸同时挤门的人测。
- 门被角色实际占据时仍需让出空间，物理上不能保证不让位也能开启；本轮提供真实让位净空、反向和自动重试。
- 门洞观察遵守固定正交视线；有些角度会被门扇自身挡住，正确深度遮挡保留，不保证开门后总能看见相邻地面。
- 门洞材质是当前StandardMaterial3D基础属性的轻量包装，不是支持所有未来复杂材质的自动转换器；当前区域恢复原材质。字体标签在门洞边缘用中心测试，可能有很小的整字显隐差异。
- 区域过渡使用短时有序溶解，不是复杂模糊。细微网格感、阴影切换观感和长墙剖切颗粒度仍需人工判断。
- 原生主动顶门存在毫米级接触容差，保留并如实记录，未通过改全局物理参数掩盖。
- Git为main / 1346664。所有旧未提交内容保留，仅增加独立C入口与必要门识别兼容；无暂存、提交或推送。完成本轮后停止，等待反馈。
