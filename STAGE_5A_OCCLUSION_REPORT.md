# Stage 5-A：正交场景玩家遮挡处理

项目：`E:/GameProject/PostApocalyptic3DTest`；引擎：Godot `4.5.2.stable.official.6ce3de25a`。本轮只处理玩家可见性，未开展 Stage 5-B。

## 1. 交付状态

- **已实现**：独立遮挡查询层、多高度采样、被遮挡部分的人物轮廓、迟滞与渐变、四种镜头/缩放兼容、F8 调试、F9 开关对照。
- **自动验证**：结果见下文及 `tests/results/stage5a_final_run.log`，不以截图存在代替验收。
- **人工验收通过：无。** 本次由脚本运行真实 Godot 渲染并检查截图；尚无人逐项操作确认 A–F，均标为待验收。
- **未实现的可选项**：新增局部透明系统。保留场景原有前景墙淡化，未改变任何共享场景材质或阴影。

## 2. 检查发现与范围

启动仍使用 `RunLoot.bat` → `scenes/looted_convenience_store.tscn`。项目默认 `project.godot` 启动场景与旧 CAD 对照场景均保留。

玩家为 CharacterBody3D，胶囊半径 0.27 m、高 1.72 m；Visual 是独立程序化人形及动画组件，含 33 个 MeshInstance3D。家具、模块化墙体已有 BoxShape3D 碰撞。商品仍由 MultiMesh 批量绘制。入口细立柱原本只有视觉，没有移动碰撞。

45° 斜视时，中央货架会挡住腿部，入口立柱会挡住部分躯干/腿部；65° 也存在货架遮挡。前景东/南墙已具有原来的 0.94 transparency 与独立投影代理。本轮不把这些淡化墙或只投影网格误当作实心可见墙。

目录不是 Git 工作区：执行 `git status --short` 返回 `not a git repository`。因此无法提供 Git diff；已在修改前保存源码/场景/材质/数据/资源 SHA-256 清单 `tests/baseline_stage5a/manifest.json`。清单中的原有文件仅 `scripts/camera_controller.gd` 改动。未提交或推送 Git，未访问修改 Embermutation 工程。

## 3. 最终实现

### 查询层

使用 PhysicsServer3D 创建 51 个**仅查询**的静态 RID，放在第 9 层（mask `256`），响应 mask 为 `0`。已有大型/中型固定结构复用原 BoxShape3D 资源；入口高而细的建筑 BoxMesh 另建少量查询形状。原场景不增加 CollisionShape3D 节点，原有碰撞体、层、mask、形状资源、变换和 disabled 状态均保持原样。退出场景释放这些 RID。

注册依据为结构分区、节点类型、尺寸及已有碰撞，不通过商品/模型名称字符串判断遮挡。命中通过 RID 注册表映射到调试标签；标签使用场景路径只是方便查看。

每帧最多对 6 个头/胸/髋/腿及左右胸部采样点查询。正交相机使用 `unproject_position` → `project_ray_origin` 得到每个采样点的**平行视线**，而不是让所有射线汇聚到 Camera3D.position。排除玩家自身 RID；不向每个商品发射射线。跳过隐藏、极淡和只投影的几何，单条射线最多跳过 8 个无效命中。

### 仅遮挡部分的轮廓

一个独立 World3D 的 SubViewport 缓存 33 个玩家网格副本，复用原 Mesh，只覆盖其私有蒙版材质。按动画后世界变换同步，绝不写回原 Visual 或碰撞体。私有相机同步正交投影、变换、size、near/far、宽高规则及窗口大小。

私有蒙版记录玩家最前表面深度。主视口一个 Quad Shader 读取实际场景深度，只在“人物边缘且人物深度位于遮挡物后方”的像素绘制暖白轮廓。正常露出的头部和身体不重新着色，人物内部也不填充。为兼容主画面的 MSAA，在暴露人物表面周围保留一像素保护区。

Quad 使用 `depth_test_disabled` 是为了执行手动深度比较；**不代表无条件穿墙显示玩家**。每个输出像素仍通过场景/人物深度判定。无遮挡时 Quad 隐藏，私有视口停止渲染；关闭功能也立即清理显示状态。

设置进入/离开迟滞及淡入淡出。换预设或大距离 R 重置时清除旧状态后重新检测，避免上一镜头轮廓残留。角色/货架比例、场景布局、移动速度、搜刮数据和商品材质均未修改。

实现参考：[Godot 4.5 深度后处理与 reverse-Z 文档](https://docs.godotengine.org/en/4.5/tutorials/shaders/advanced_postprocessing.html)、[SubViewport 更新模式](https://docs.godotengine.org/en/4.5/classes/class_subviewport.html)。实际图像验证使用本机 Forward+ / Vulkan，不宣称已验证其他渲染后端。

## 4. 文件与配置

| 文件 | 作用 |
|---|---|
| `scripts/camera_controller.gd` | 当前 Loot CAD 场景挂接独立组件；增加 F8/F9 操作说明；原预设、移动和缩放算法保持原样 |
| `scripts/occlusion/player_occlusion.gd` | 原生物理查询代理、检测、迟滞、蒙版同步、轮廓生命周期、调试信息 |
| `data/player_occlusion.json` | 统一参数 |
| `materials/player_occlusion_mask.gdshader` | 玩家前表面深度蒙版 |
| `materials/player_occlusion_outline.gdshader` | 屏幕边缘提取及实际遮挡深度裁切 |
| `tests/validate_player_occlusion.gd` | 自动逻辑/物理/搜刮回归 |
| `tests/stage5a_capture.gd` | 实际渲染、逐像素开关对比、性能采样 |
| `tests/run_stage5a_tests.ps1` | 当前回归链和本轮验证入口 |
| `tests/stage5a_baseline.gd`、`tests/baseline_stage5a/manifest.json` | 修改前基线采集与保护清单；源码变化后禁止覆盖原始基线 |
| `tests/stage5a_probe.gd` | 独立调试采样脚本 |
| `tests/stage4d3_capture.gd` | 仅锁定截图测试窗口尺寸/焦点，原检查断言未删除或放宽 |
| `screenshots/stage5a/`、`tests/results/stage5a_*` | 真实截图、原始测量与日志 |

引擎自动生成的 `.uid`、导入缓存及测试 PCK 不属于新美术资产。

| 参数 | 默认值 |
|---|---|
| 轮廓颜色 | `#E9DEC5`，区别于容器 `#E6A23C` |
| 强度 / 宽度 | 0.82 / 2 个视口像素 |
| 触发阈值 | 被挡比例 ≥ 0.16，即 6 点中至少 1 点 |
| 进入 / 离开确认 | 0.06 s / 0.14 s |
| 透明度平滑 | 0.10 s |
| 深度安全偏差 | 0.12 m，避免深度精度与 MSAA 边缘误画 |
| 蒙版深度区间 | 玩家观察中心前后各 2 m |
| 注册最小形状高度 | 0.45 m |
| 局部透明 | 不启用 |

F1/F2/F5/F6、滚轮、Home、WASD、E/Esc、R、F3/F4、原 F7 均保留。F8 显示/隐藏遮挡调试，默认关闭；F9 切换本轮功能，默认开启。未发现键位冲突。

## 5. 自动化验证

运行方式（在项目目录 PowerShell）：

```powershell
./tests/run_stage5a_tests.ps1 -Capture
```

| 检查 | 真实结果 |
|---|---|
| Godot 4.5.2 导入、75 脚本语法、主场景加载 | 通过 |
| 当前 Stage 4-D.3 及上游回归链 | 348 通过 / 0 失败 |
| 本轮遮挡逻辑检查 | 50 通过 / 0 失败 |
| 本轮实际渲染检查 | 54 通过 / 0 失败 |
| 断言合计 | 452 通过 / 0 失败 |
| 原生资源 PCK 导出与独立打包烟测 | 通过 |
| 人工 A–F | 未执行，待验收 |

最终完整命令退出码为 0。固定分辨率回归曾因窗口中途尺寸变化失败，已锁定测试窗口并全量重跑通过，没有放宽原有断言。

逻辑检查覆盖：无遮挡、遮挡与解除、八次预设切换清理、缩放 0.8×/1.0×/1.5×/允许最大约 1.667×、F8/F9、R、Home、原有碰撞资源和层完全不变、动画网格同步、货架 02 受挡时搜索/领取一瓶水/视觉事务不变量、16 个容器和 12 份总量守恒。

渲染检查对同一状态拍摄功能开/关截图，再用诊断材质分别取得人物实际可见区与无遮挡参考区；诊断材质仅用于测试且随即恢复。对比人物附近像素，检查轮廓确实增加、露出的人物不被覆盖、范围局限在人物边缘。该检查有少量轮廓边缘/抗锯齿容差，原始计数全部保存在 JSON；不将容差等同于全场景零瑕疵。

| 实店样本 | 功能开关变化像素 | 误覆盖正常可见人物像素 | 射线触发 |
|---|---:|---:|---|
| clear45 | 0 | 0 | False |
| shelf45 | 206 | 0 | True |
| shelf45_front | 294 | 0 | True |
| shelf65 | 150 | 0 | True |
| shelf85 | 0 | 0 | False |
| checkout45 | 229 | 0 | True |
| wall_post45 | 146 | 0 | True |
| zoom_0.80 | 162 | 0 | True |
| zoom_1.00 | 206 | 0 | True |
| zoom_1.50 | 316 | 0 | True |
| zoom_1.67 | 351 | 0 | True |

在 85° 的实店货架后方样本没有触发明显遮挡，因此对应画面是正常可见性对照，**不宣称完成“85° 完全遮挡”验收**。没有移动货架或伪造遮挡来生成截图。

当前验收链覆盖导入、75 个脚本语法检查、主场景、资源、PCK 打包、移动/缩放/四预设、灯光/阴影、全店搜刮、高亮与最新视角截图检查。目录内已被后续阶段替代的旧库存常量/旧镜头截图脚本未逐一执行，不能把本轮结果解释为所有历史脚本均运行。

## 6. 性能对比

硬件：NVIDIA GeForce RTX 4060 Laptop GPU；Forward+ / Vulkan；1440×1000；F6 45°、yaw 35°；size 13.8；同一玩家位置、固定 idle 位姿、灯光/阴影开启、UI 关闭，VSync 关闭。每个条件预热 180 帧，再测 3 窗口 × 600 帧。

历史基线在修改源码前实测；新增功能后又在同一进程分别测 F9 关闭/开启，以降低分批采样与缓存温度差异。`clear` 为历史测试点名，实际上该点也被旁侧货架局部遮挡；真正无不透明遮挡的条件为 `clear_aisle`。

| 条件 | 平均帧 ms | 三窗口 P95 均值 ms | FPS（平均耗时换算） | Draw Calls | 检测均值 μs |
|---|---:|---:|---:|---:|---:|
| 修改前 clear | 2.990 | 5.649 | 334.5 | 1890 | — |
| 修改前 shelf | 2.708 | 4.634 | 369.2 | 1929 | — |
| 当前 clear_off | 2.550 | 5.220 | 392.2 | 1890 | 0.00 |
| 当前 clear_on | 2.547 | 4.761 | 392.6 | 1924 | 79.77 |
| 当前 shelf_off | 2.206 | 4.148 | 453.2 | 1929 | 0.00 |
| 当前 shelf_on | 2.520 | 4.830 | 396.8 | 1963 | 89.47 |
| 当前 clear_aisle_off | 2.194 | 4.028 | 455.9 | 1845 | 0.00 |
| 当前 clear_aisle_on | 2.213 | 4.218 | 452.0 | 1845 | 69.61 |

节点从修改前 971 增至 1011（+40，主要为缓存的人物副本）；原有 CollisionShape3D 节点数量不变。所有条件仍为 53 个可见商品实例，库存保持 12 份。轮廓激活新增 34 Draw Calls（33 个玩家蒙版网格 + 1 Quad）；无遮挡条件不增加 Draw Calls。

同进程中央货架样本，开启功能平均约增加 0.31 ms，约 14%；这是可测附加成本，不能宣称零性能回退。真正无遮挡通道检测约 70 μs/帧，显示轮廓的货架样本检测约 89 μs/帧；这些只包含查询时间，不包含蒙版同步和 GPU 成本。原始三次窗口数据见 stage5a_render.json。历史基线和本轮关闭条件也有差异，体现分批采样/缓存/系统负载影响。

Draw Calls 为 Godot 全视口渲染监控值，包含蒙版与阴影等，不是单独主场景不透明 pass 的数目。FPS 使用整窗口平均帧耗时换算；截图 HUD 的瞬时 FPS 不用于结论。

这是当前硬件、静止位姿下的短时采样，未覆盖长期运行、集成显卡、移动过程或所有分辨率。不能据此解释用户之前约 54 FPS 的运行状态，也不宣称性能提升或所有设备无退化。轮廓有明确附加成本，是否可接受仍需实际游戏操作验收。

## 7. 真实截图

以下均为 Godot 主视口原始 PNG，未用生成图片替代。开关对照保持同一相机/位置/缩放/灯光/分辨率；截图中的测试静止位置不代表人工走位已验收。

| 内容 | 文件 |
|---|---|
| 45° 斜向，无不透明遮挡 | [clear45_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/clear45_on.png) |
| 45° 斜向，货架遮挡，功能关闭 | [shelf45_off.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/shelf45_off.png) |
| 45° 斜向，遮挡轮廓 | [shelf45_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/shelf45_on.png) |
| 45° 正向，遮挡轮廓 | [shelf45_front_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/shelf45_front_on.png) |
| 65° 货架遮挡 | [shelf65_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/shelf65_on.png) |
| 85° 同货架位置可见性对照（未触发明显遮挡） | [shelf85_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/shelf85_on.png) |
| 收银台后方遮挡 | [checkout45_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/checkout45_on.png) |
| 入口建筑立柱遮挡 | [wall_post45_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/wall_post45_on.png) |
| 近距离缩放 | [zoom_1.50_on.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/zoom_1.50_on.png) |
| 遮挡时搜索 UI | [search_occluded.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/search_occluded.png) |
| 遮挡调试 | [debug_occluded.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5a/debug_occluded.png) |

## 8. 人工验收：全部待验收

由用户通过 `RunLoot.bat` 实际操作。F8 查看射线状态，F9 做开关对照，测试后恢复 F9 开启、F8 关闭。以下不能以本轮脚本检查替代：

| 场景 | 操作与观察 | 状态 |
|---|---|---|
| A 中央货架 | F6，在中央货架 02 前后正常行走并返回；轮廓应只补被挡部位，无遮挡时消失，没有肉眼可见闪烁 | 待验收 |
| B 收银台 | 台前、台后移动；检查与琥珀色容器高亮有区分，人物不穿模 | 待验收 |
| C 墙体 | F6 沿左右/上方墙、入口立柱移动；确认能判断人物位置，原淡化墙状态不异常 | 待验收 |
| D 切换相机 | 受遮挡时连续按 F1/F2/F5/F6；检查旧轮廓不残留 | 待验收 |
| E 缩放 | 滚轮到 HUD 约 0.8×、1.0×、1.5×和最大约 1.667×；移动中检查稳定性，Home 恢复 | 待验收 |
| F 搜索 | 货架背后 E 搜索、单件/全部拿取、Esc；检查目标、UI、物资与对应商品变化均正确 | 待验收 |

另需人工判断暖白亮度/宽度、远处细节、遮挡处转向动画、不同显示器缩放与持续 FPS/帧耗时。没有填写任何“人工通过”。

## 9. 已知问题与后续建议

1. CPU 查询代理是家具整体体积的近似。货架空隙可能让射线判定遮挡，但真正轮廓仍由像素深度决定；调试的“射线遮挡”不等于每个像素都被遮挡。
2. 仅注册现有 BoxShape3D 大小结构和指定建筑区域的高细立柱，不处理任意新网格，也不检测每件商品的微小遮挡。未来新结构需显式加入注册范围。
3. 半透明玻璃/淡化墙的深度与不透明物体不同，本轮主要保证不透明货架、柜体、结构遮挡；保留现有淡化墙策略。
4. 0.12 m 深度安全偏差和一像素暴露保护可能使极贴近遮挡边缘的轮廓略有断开；用来避免覆盖正常人物。细立柱边缘和远距离效果仍需人工确认。
5. 快速切换预设会清除旧轮廓并重新进行短时确认。迟滞/渐变的手感尚未人工验收，必要时只调整集中参数。
6. 原生截图确认功能有效，不构成全地图可见性证明；85° 完全遮挡样本、全店持续走位及所有缩放下的感受均保留待验证状态。
7. 建议先完成 A–F 并记录具体遮挡位置，再决定是否需要仅针对少数结构的透明处理。现阶段不增加新玩法，不继续 Stage 5-B。
8. 近距离截图中底部快捷键/会话辅助文字出现局部边缘裁切，主 HUD 和 E 提示仍可见；窗口与系统 DPI 下的完整 HUD 适配需要人工核对。本轮未重构原有 UI，不把自动逻辑通过解释为界面视觉已验收。

