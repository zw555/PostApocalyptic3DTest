# Stage 5-C.3-B 玩家受伤、HP 与死亡反馈

## 交付状态与入口

本轮只实现 C.3-B，未进入 C.3-C。项目 Godot `4.5.2.stable.official.6ce3de25a`。既有 C.3-A 未提交修改均保留，没有暂存、提交或推送 Git。

双击 [RunStage5C3B.bat](E:/GameProject/PostApocalyptic3DTest/RunStage5C3B.bat)，打开 **可交互游戏窗口**，加载 `scenes/combat/stage5c3b_feedback_validation.tscn`。该场景继承 C.3-A 及其核心结算顺序；原 C.3-A、C.1、C.2 入口与默认行为保留。

F6 默认 45° 斜视，F1/F2/F5/F6 切换视角，滚轮/Home 缩放，鼠标瞄准/左键攻击，E/Esc 搜刮。**F12** 开关硬直/无敌剩余时间调试，默认关闭。僵尸位于店铺左下方，需进入其正前方视线。死亡后保留镜头观察，重新开始需关闭并重新启动场景，不提供复活。

**自动测试通过、真实渲染检查通过；本轮玩家人工验收尚未完成。** 用户已确认之前 C.3-A 僵尸能造成伤害，不将该确认扩展成 B 的视觉/手感验收。

已实际调用 B 的 BAT 入口，确认启动 GUI 版 Godot、命令行指向 B 场景且不含 `--headless`，产生有效原生窗口句柄；交互窗口已保留供玩家操作。这仅验证启动方式，不记作人工验收。

## A. 实际修改文件

| 文件 | 本轮作用 |
|---|---|
| `scripts/combat/stage5c3b_player_feedback.gd`（新增） | 玩家私有材质、闪红、保护亮度、最终姿态优先级 |
| `scripts/combat/stage5c3b_health_hud.gd`（新增） | HP 数字/条、保护状态、死亡提示、F12 调试 |
| `scripts/combat/stage5c3b_validation_main.gd`（新增） | B 场景装配、有效受伤同步关闭搜刮、死亡隐藏 E 提示 |
| `scenes/combat/stage5c3b_feedback_validation.tscn`（新增） | 继承独立 C.3-A 场景，显式启用 B 功能 |
| `RunStage5C3B.bat`（新增） | 启动 GUI Godot 的交互场景，不是测试脚本 |
| `scripts/survivor_animator.gd`（小改） | 新增默认关闭的外部 UpperBody 姿态所有权开关 |
| `scripts/combat/stage5c1_character_attack_visual.gd`（小改） | 同一开关下不再写 UpperBody，武器挥击轨迹照常推进 |
| `tests/validate_stage5c3b.gd`、`tests/stage5c3b_capture.gd`、`tests/run_stage5c3b_tests.ps1`（新增） | B 专项、原生输入、真实图像与完整回归入口 |
| `screenshots/stage5c3b/`、本报告（新增） | 真实 Godot PNG、结果与人工清单 |

C.3-A 的玩家战斗参数、HealthComponent、僵尸伤害组件与结算逻辑没有改动。没有修改布局、货架、物资、相机预设、导航数据或共享材质资产文件。

## B. C.3-A 核心补充检查

未发现需要通过延长硬直或无敌来处理的核心缺陷，参数仍为 **硬直 0.20 s、无敌 0.45 s**。

- 在实际 B 场景中发送原生移动与左键输入，硬直期间位置与攻击次数不增加；场景自身的物理计时器推进后，输入恢复，并仍处于剩余无敌期。
- 无敌期间重复伤害被拒绝，不扣血、不重启闪红、不刷新硬直或无敌时间。
- 死亡继续拒绝移动、攻击、搜索、迟到拿取和 R 位移；相机四预设及滚轮仍可用。
- 关闭搜刮面板虽然恢复原 UI 的 `controls_enabled`，但不能绕过统一的战斗许可，因此不会解除硬直或死亡锁。

## C. 新增表现与联动

### 玩家材质隔离

仅遍历玩家 Visual 使用的实际 StandardMaterial3D，按源材质实例 ID 缓存私有副本。覆盖 material_override，必要时设置该玩家的 surface override；不修改共享 Mesh 的表面材质。原颜色、发光开关、颜色与能量均保存快照。

有效伤害信号触发约 0.10 s 红色反馈；随后用低强度、无闪烁的灰绿色发光表现剩余保护期。保护结束恢复全部原属性。被拒绝的伤害不发信号，因而不会重触发视觉。

初版尝试提亮 albedo，但部分贴图材质的颜色乘数本来为白色，提亮白色不会产生保护反馈。因此改成私有材质低能量发光，而不是把无效表现靠修改测试预期掩盖。测试同时检查材质隔离、属性恢复与真实可见像素变化。

### 姿态优先级

`死亡 > 受伤 > 攻击 > 普通移动`。

B 场景启用外部 UpperBody 所有权后，原步态和攻击视觉不再写该部位旋转；新反馈组件在两者之后、遮挡蒙版同步之前写入最终姿态。普通步态与挥击仍使用原参数。受击约 0.2 s 轻微后仰，死亡持续保持简单上身失衡/武器下垂姿态；不改变角色位置、胶囊或增加物理击退。

### HP 和死亡 UI

- 数字/血条初始 100/100，伤害信号同步更新为 90/100，死亡显示 0/100。
- 右下方 HP 区避开底部交互提示；所有 HUD Control 均忽略鼠标，原生点击和滚轮测试验证事件仍到达攻击/相机。
- 死亡提示位于上方中央，避免遮住玩家姿态；提示不暂停 SceneTree、不阻止相机操作。
- 使用原项目的等比例视口缩放。在 1000×700、800×600 窗口，内容区域分别为 1000×694、800×555，余下为留边；截图与布局检查按实际内容坐标核验，不把逻辑坐标误当窗口像素。

### 搜刮联动

在接受伤害、核心锁定已经设置后，同步关闭面板；死亡同时隐藏 E 提示。已提交的拿取事务和商品视觉不回滚、不复制。后续拿取请求仍经过原 C.3 许可入口校验，硬直或死亡时拒绝。

现有库存事务是同步调用；本轮没有引入新的异步交易/存档系统。

## D. 自动测试与渲染

执行入口：`./tests/run_stage5c3b_tests.ps1 -Capture`。

| 检查类别 | 真实结果 |
|---|---|
| C.3-B 专项逻辑/原生输入 | 41 通过 / 0 失败 |
| C.3-B 真实渲染与像素对照 | 31 通过 / 0 失败 |
| C.3-A 核心回归 | 39 通过 / 0 失败 |
| C.1 原回归 | 41 通过 / 0 失败 |
| C.2 原回归 | 22 通过 / 0 失败 |
| 合计 | 174 通过 / 0 失败 |
| B 范围 7 脚本解析及场景 Smoke | 通过 |
| 玩家人工验收 | 尚未完成，待玩家确认 |

日志：`tests/results/stage5c3b_final_run.log`；B 逻辑与图像结果分别为 `stage5c3b_validation.json`、`stage5c3b_render.json`。最终保护状态图像补充检查日志为 `stage5c3b_render_console.log`。C.1 测试继续使用 A 阶段已说明的零伤害几何夹具，未删除或放宽原断言。

真实渲染使用本机 RTX 4060 Laptop GPU、Forward+ / Vulkan，拍摄相同位置、镜头和光照的正常/闪红/保护/恢复对照。三视角均检查人物像素确实变化、采样墙面像素不变、结束后恢复。场景材质检查另覆盖其他建筑、货架与僵尸实例。截图内 FPS 在诊断采样中可能冻结，不是性能测试数据。

截图索引：

| 内容 | 文件 |
|---|---|
| 45° 闪红与后仰 | [F6_hurt.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/F6_hurt.png) |
| 45° 无敌保护 | [F6_protected.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/F6_protected.png) |
| 恢复原外观 | [F6_restored.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/F6_restored.png) |
| 65° / 85° 受伤 | [F2_hurt.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/F2_hurt.png)、[F1_hurt.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/F1_hurt.png) |
| 搜刮受伤关闭 | [search_before_hit.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/search_before_hit.png)、[search_closed_on_hit.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/search_closed_on_hit.png) |
| 死亡与 0 HP | [death45.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/death45.png) |
| 小窗口死亡反馈 | [death_800x600.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3b/death_800x600.png) |

这些是脚本驱动的实际 Godot 输出，不是 AI 生图，也不等于玩家人工验收。

## E. 已知限制与风险

- 死亡是简单上身姿态，不是倒地布娃娃；胶囊仍保留原位，肩臂衔接、手感和动作幅度需人工判断。
- 无敌亮度刻意克制，是否足够明显需在实际显示器、缩放和光照下由玩家确认，可用 F12 对照剩余时间。
- 全局原有视口等比例缩放可能使小窗口文字偏小；边界检查通过不等于主观可读性通过。没有重做原调试 HUD 或全局 UI。
- 原生输入测试通过场景树分发事件；实际鼠标/键盘、连续操作与系统 DPI 仍待玩家测试。
- 本轮未作长时间性能基准，不宣称性能提升或所有硬件无回退。材质副本在初始化时创建，不每帧重建 Mesh 或材质。
- 不含复活、物资惩罚、存档、正式武器、掉落、多僵尸或 Stage C.3-C 内容。

## F. 玩家实际验收：全部待确认

1. 双击 B 入口，站在僵尸正面让它命中：确认 HP 100→90、约 0.1 s 闪红、短后仰和保护亮度；F12 对照 0.2/0.45 s。漏测风险：逻辑正确但反馈难以辨认。
2. 受伤同时按移动和左键，等待恢复后继续操作；确认不是长期锁定。漏测风险：输入锁残留或打断表现异常。
3. 打开货架并先拿一件，受到攻击后面板应关闭、已拿物资保留；重新打开检查剩余与商品视觉。漏测风险：界面与事务不同步。
4. 检查伤害时墙、地板、货架、僵尸不变红，保护结束恢复。漏测风险：共享材质污染或反馈残留。
5. 连续受击直到 HP 为 0：不能移动/攻击/E/R/拿取，面板关闭、死亡提示和姿态清楚；视角、滚轮、Home 仍可观察。漏测风险：死亡后输入或交易绕过门禁。
6. 在 F1/F2/F5/F6、近远缩放、1000×700 和 800×600 窗口检查 HP、不挡交互、动作与姿态。漏测风险：某视角或窗口裁切/不可读。

没有登记任何新的“玩家人工验收通过”。完成本轮后停止，等待玩家反馈，不继续 C.3-C。
