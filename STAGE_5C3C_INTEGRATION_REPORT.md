# Stage 5-C.3-C 双向战斗集成回归与最终验收准备

项目：`E:/GameProject/PostApocalyptic3DTest`；引擎：Godot `4.5.2.stable.official.6ce3de25a`；Git HEAD：`edc9a4b`。

## 1. 结论与验收边界

- 本轮完成集成验证，并修复 **1 个实际命中反馈缺陷**，未增加游戏功能或修改战斗参数。
- C.1/C.2/C.3-A/C.3-B：**174 项通过，0 失败**；新增真实场景集成：**85 项通过，0 失败**。
- 导航、AI、搜刮、布局、相机与遮挡的旧测试：**398 项通过，7 项历史源码 SHA 冻结断言失败**。这些失败没有删除、放宽或改成通过。
- 全部已执行断言合计：**657 通过，7 失败**。因此不能声称“所有历史测试全绿”。失败均为旧源码冻结基线与后续已开发阶段的差异，详见第 4 节。
- 用户已确认 **C.3-B 实际游戏体验通过**。本轮 C.3-C 的脚本驱动真实运行不是新的人工验收；最终人工确认仍待玩家完成。

## 2. 实际发现与最小修复

### 缺陷：命中提示读取上一击结果

复现：启动实际 C.3-B 场景，首次左键命中僵尸。实际 HP 30→20，但文字显示 `-0 HP`；第三击 HP 归零，文字仍不立即显示“死亡”。四种视角均复现。

根因：`stage5c1_melee_attack_controller.gd` 在写入 `last_damage_result` **之前**同步发出 `attack_resolved`。C.1 场景反馈回调立即读取该字段，读到上一击数据。

修复：只把 `last_damage_result = result` 移到发信号之前，并补充原因注释。未改命中计算、伤害、冷却、硬直、无敌、AI 或任何平衡参数。

针对性回归：每种 F1/F2/F5/F6 视角均检查首次命中立即显示 `-10 HP`、致死一击立即显示“死亡”，共 **8 个新断言**。修复前 8 项失败，修复后全部通过。

证据：`tests/results/stage5c3c_defect_repro.json`、`stage5c3c_defect_repro_console.log`；修复后的结果为 `stage5c3c_integration.json`。本轮没有发现其他已复现的玩法缺陷。

## 3. 实际场景集成覆盖

新增 `tests/validate_stage5c3c_integration.gd`，实际加载未改布局的 C.3-B 场景，使用原生物理、AI、输入分发与正式组件连接；不以调用 HealthComponent 代替整段战斗。

| 场景 | 自动运行记录 |
|---|---|
| 四视角主动攻击 | F1/F2/F5/F6 均执行连续点击、首次打断、原生移动接近、后续挥击、击杀；每段运行都是新实例，玩家与僵尸保持原碰撞 |
| 攻击打断 | 僵尸自然进入 WINDUP 后由玩家实际左键命中，触发原 C.2 硬直并取消僵尸待命中攻击 |
| 移动躲避 | 前摇已开始后发送原移动输入，玩家离开锁定范围，僵尸挥空且玩家保持 100 HP，没有通过瞬移完成该躲避 |
| AI 状态 | 自然 IDLE→CHASE；利用遮挡站位中断视线，INVESTIGATE 的 last_seen 保持不变，再 RETURN→IDLE |
| 墙体/货架 | 固定几何站位，原生左键触发完整挥击，真实结构物理射线阻挡、目标保持 30 HP；不是自由走位路线验收 |
| 搜刮中受伤 | 原生 E 打开货架 02；真实库存事务先提交一瓶水；原生僵尸攻击使玩家受伤、关闭面板、保留事务；迟到回调被拒绝 |
| 恢复与重复领取 | 原计时器恢复后重新 E 搜索，拿取剩余水；总量恰为 2，重复全部拿取失败，无永久输入锁 |
| 玩家连续死亡 | 不直接调用伤害接口，等待 10 次原生僵尸命中，记录 90、80、70、60、50、40、30、20、10、0 HP |
| 死亡后输入 | 原生移动、点击、E、R 被拒绝；僵尸攻击次数停止增加；SceneTree 不暂停；四视角、滚轮与 F12 可用 |
| 重启初始化 | 同进程卸载并重新实例化 C.3-B，100 HP、僵尸 30 HP、空玩家库存、无残留硬直/无敌/死亡界面、仅一只僵尸 |

测试开始时记录现有 `scripts/scenes/materials/data/assets` 的源文件 SHA。除上述已说明的近战反馈修复外，原有源码、资产和配置均保持相同。整个进程重开、实际键鼠手感与自由走位仍需玩家最终确认。

## 4. 全部测试结果与历史差异

| 测试 | 通过 | 失败 | 说明 |
|---|---:|---:|---|
| C.1 | 41 | 0 | 原有零伤害几何夹具保持不变 |
| C.2 | 22 | 0 | 原健康、硬直、材质与死亡回归 |
| C.3-A | 39 | 0 | 原核心战斗回归 |
| C.3-B 逻辑 | 41 | 0 | 原材质、门禁、HUD、搜刮与原生输入 |
| C.3-B 渲染 | 31 | 0 | 原真实画面对比与小窗口 |
| C.3-C 真实场景 | 85 | 0 | 本轮新增完整流程，含 8 个缺陷回归断言 |
| 初版技术验证 | 42 | 0 | 物理/资源等 |
| 第二轮美术 | 21 | 1 | 仅历史 SHA 冻结失败 |
| 相机缩放 | 20 | 0 | 滚轮、Home、UI 输入等 |
| CAD 布局与通行 | 44 | 1 | 行为通过，历史 SHA 冻结失败 |
| 全店搜刮 | 86 | 1 | 库存/视觉/事务通过，历史 SHA 冻结失败 |
| 稀缺物资与高亮 | 21 | 0 | 16 容器、12 初始物资 |
| 中文美术资源 | 16 | 1 | 字体/模型等通过，历史 SHA 冻结失败 |
| 四相机预设 | 49 | 1 | 行为通过，历史 SHA 冻结失败 |
| 5-A 遮挡 | 49 | 1 | 行为通过，历史 SHA 冻结失败 |
| 5-B 导航/AI | 50 | 1 | 原生寻路/状态通过，历史 SHA 冻结失败 |
| **合计** | **657** | **7** | **未将历史断言失败解释为全绿** |

脚本解析：98 个既有脚本单独检查成功，新增集成脚本另行解析及实际运行成功，共覆盖 99 个；C.3-B 链同时重做对应脚本解析与场景 Smoke。

### 七项旧冻结断言的具体原因

- 第二轮美术冻结检查：`.gitignore`、`project.godot`、`Run.bat`、`scripts/player_controller.gd`。
- CAD 冻结检查：上述文件加 `scripts/survivor_animator.gd`。
- 全店搜刮、中文美术、四预设、5-A、5-B 的冻结检查：`scripts/player_controller.gd`、`scripts/survivor_animator.gd`。

前三个入口/仓库配置文件在当前 Git HEAD 已经如此，本轮 `git diff` 没有它们。玩家控制器与幸存者动画器是已完成 C.3-A/B 的可选战斗门禁/姿态所有权扩展，本轮没有再修改它们。旧清单记录的是更早阶段的文件哈希。

这些是**真实的原测试失败结果**，不是被忽略的错误；也没有通过回滚已验收功能来迎合旧字节级基线。最终要让总门禁全绿，需要玩家确认未来如何迁移历史源码冻结策略。本轮保留原清单与断言，不擅自更新预期。

## 5. 运行方法与证据

当前回归入口：

```powershell
./tests/run_stage5c3c_tests.ps1 -Capture
```

脚本会保留所有旧测试原始退出码。**当前会在完成全部检查后因七个历史冻结失败而返回失败**，不会打印虚假的全通过。

主要结果：

- `tests/results/stage5c3c_run_summary.json`：总门禁状态。
- `tests/results/stage5c3c_legacy_runs.json`：十个兼容性套件的原始退出码和失败文字。
- `tests/results/stage5c3c_integration.json`：85 项断言、真实 HP 序列、AI 轨迹与截图清单。
- `tests/results/stage5c3c_final_run.log`：整套最新执行记录。
- `tests/results/stage5c3c_parse.json`、`stage5c3c_parse_integration.log`：解析记录。
- `tests/results/stage5c3c_start_hashes.json`：本轮开始时原有源码/资源快照。

真实 Godot 图像（非生成图片）：

| 内容 | 文件 |
|---|---|
| 45° 首击打断、正确伤害提示 | [F6_interrupt.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/F6_interrupt.png) |
| 65° / 85° / 45° 正向 | [F2](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/F2_interrupt.png)、[F1](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/F1_interrupt.png)、[F5](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/F5_interrupt.png) |
| 击杀与即时死亡提示 | [F6_enemy_dead.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/F6_enemy_dead.png) |
| 原生移动躲避 | [native_dodge.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/native_dodge.png) |
| 货架 / 墙体阻挡 | [货架](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/native_blocked_shelf.png)、[墙体](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/native_blocked_wall.png) |
| 原生敌人攻击中断搜刮 | [native_search_interrupted.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/native_search_interrupted.png) |
| 连续受击死亡后的观察 | [native_player_dead_observe.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/native_player_dead_observe.png) |
| 重新实例化后初始状态 | [restarted_initial_state.png](E:/GameProject/PostApocalyptic3DTest/screenshots/stage5c3c/restarted_initial_state.png) |

## 6. 最终人工验收入口与清单

仍使用 [RunStage5C3B.bat](E:/GameProject/PostApocalyptic3DTest/RunStage5C3B.bat)。请先关闭之前打开的旧游戏窗口，再双击以加载本轮反馈修复。没有新建玩法场景或改变启动参数。

| 项目 | 当前证据 | 玩家最终确认 |
|---|---|---|
| 首击与致死反馈 | 四视角新增断言与截图通过 | 确认首击显示 -10 HP，致死击立即显示“死亡” |
| 主动击杀与连续点击 | 原生输入、实际移动/碰撞通过 | 自由移动中攻击，判断方向与节奏 |
| 躲避/打断 | 原生前摇躲避与打断通过 | 实际键鼠确认非追踪必中，无迟到伤害 |
| AI/导航 | 原有路线/碰撞与本轮状态序列通过 | 绕不同货架连续追逐，检查卡住与转向 |
| 材质与姿态 | B 的材质/像素检查重新通过 | 检查建筑不变红、保护亮度、死亡姿态 |
| 搜刮受伤与库存 | 实际场景已提交事务、关闭与防重复通过 | 自由探索不同容器并检查剩余数量 |
| 连续死亡与门禁 | 十次命中与死亡输入测试通过 | 实际 WASD/左键/E/R，确认没有残留操作 |
| 镜头与 UI | 原有缩放、预设、轮廓、HUD 检查通过 | 不同系统 DPI、窗口大小与近远缩放下判断可读性 |
| 关闭并重新启动 | 同进程场景重建通过 | 实际关闭整个游戏进程再双击入口，确认初始状态 |

C.3-B 的既有人工通过来自用户确认，予以保留；上述 **C.3-C 最终确认尚未填写为通过**。脚本不能替代实际鼠标手感、连续自由走位或不同显示器下的观察。遗漏这些检查可能留下输入手感、角落卡住、攻击读招或 UI 可读性问题。

## 7. Git 修改与提交建议

本轮新增：`tests/validate_stage5c3c_integration.gd`、`tests/run_stage5c3c_tests.ps1`、`screenshots/stage5c3c/` 和本报告。唯一额外改动的玩法源码是 `stage5c1_melee_attack_controller.gd` 的结果赋值顺序。

工作区仍包含此前 A/B 的未提交内容：AI/玩家控制器、瞄准/挥击/步态扩展、C.1 测试夹具、A/B 组件、场景、启动脚本、报告与截图。完整清单见 `tests/results/stage5c3c_git_status.txt`，没有自动暂存。

建议在确认历史 SHA 策略与最终人工清单后，按三组审阅再决定提交：

1. A/B 核心、受伤表现与验证入口。
2. 本轮命中提示修复与对应集成测试。
3. 报告及需要保留的真实截图。

不要提交 `tests/results/` 的日志、临时基线副本、PCK 或 `.godot` 缓存。可参考提交说明：`feat: validate single-zombie bidirectional combat through Stage 5-C.3`。本轮**未创建 commit、未推送**，等待玩家最终确认。

## 8. 仍存在的限制

历史冻结断言尚未迁移是当前自动总门禁的明确非全绿项；除此之外本轮没有已复现的未修复玩法失败。仍是单僵尸、简单程序化动作与近战原型，不包含正式武器、多敌人、复活、存档或结算。没有开展下一阶段，也没有使用单帧 FPS 宣称性能改善。
