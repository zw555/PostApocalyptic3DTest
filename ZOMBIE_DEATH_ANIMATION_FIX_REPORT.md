# 僵尸死亡后继续行走动画：定点修复

## 根因

实际检查了 `zombie_visual.gd`、`zombie_controller.gd`、`zombie_model.gd`、父类 `survivor_animator.gd` 和程序化人形节点结构。

控制器死亡后已正确进入 `DEAD`，停止实体移动。但视觉 `_process()` 没有提前退出：仍读取 `get_real_velocity()`、推进 clock/phase/gait_weight，并调用 `pose_at()` 改写双腿、手臂、骨盆和躯干，之后才给 Visual 根节点叠加倒地旋转。

`get_real_velocity()` 是最近一次 `move_and_slide()` 的结果。控制器死后不再调用移动方法，死亡前 CHASE 的速度缓存仍然非零，造成持续摆腿；即便从 ATTACK 死亡且速度为零，呼吸和待机周期仍在更新。不是 AI 复活，也不是两个独立 Animator 同时执行，而是同一视觉脚本里的普通姿态更新没有被死亡状态截断。

原生场景复现证实：死亡时 AI 和视觉标记都正确，但旧速度仍存在。修复前针对性检查 **19 通过、10 失败**。保留结果 `tests/results/zombie_death_pose_repro.json` 与 `zombie_death_repro_console.log`。

## 最小修复

唯一修改的玩法源码：[scripts/ai/zombie_visual.gd](E:/GameProject/PostApocalyptic3DTest/scripts/ai/zombie_visual.gd)。

1. 把死亡分支置于 `_process()` 顶部。死亡后只继续原根节点倒地插值，然后返回，不再推进任何行走、攻击、受击或呼吸周期。
2. `death_feedback()` 一次性清除攻击/受击/闪红和步态权重，将局部肢体设为脚部落地的无攻击静态姿态，然后锁定死亡状态。
3. 死后 `pose_at()`、`attack()`、`hit_feedback()` 不再写入姿态；重复 `death_feedback()` 不会重置尸体。
4. 保留原倒地目标 **-1.15 rad** 和插值速率 **6**，接近目标小于 0.003 rad 时收敛为准确目标，避免无限小残余变化。

没有隐藏或删除腿部，没有改碰撞体、AI 状态机、战斗参数、场景布局、物资、玩家动画或其他存活实例。存活时仍沿用原 C.3 控制器的受击取消攻击规则，没有重构整套动画系统。

其他修改：

- 新增 `tests/validate_zombie_death_pose.gd`：死亡稳定性和实例隔离回归。
- 新增 `tests/run_zombie_death_fix_tests.ps1`：本轮相关测试入口。
- `tests/validate_stage5c3c_integration.gd`：资源保护检查只额外放行本次明确授权修改的 `zombie_visual.gd`，其余原检查保留。该文件变动由修复前失败、修复后通过的独立死亡测试覆盖，并非跳过视觉检查。
- 新增本报告和四张真实渲染截图。

本轮开始时已有的 A/B/C 未提交工作全部保留，没有创建提交、暂存或推送 Git。

## 自动测试结果

执行：

```powershell
./tests/run_zombie_death_fix_tests.ps1 -Capture
```

| 检查 | 通过 | 失败 |
|---|---:|---:|
| 死亡动画专项 | 29 | 0 |
| C.3-C 实际场景集成 | 85 | 0 |
| C.3-B 逻辑 | 41 | 0 |
| C.3-B 实际渲染 | 31 | 0 |
| C.3-A | 39 | 0 |
| C.2 | 22 | 0 |
| C.1 | 41 | 0 |
| **本轮相关断言合计** | **288** | **0** |

脚本解析、场景 Smoke 均通过。专项分别在 headless 与真实 Vulkan 渲染环境执行，重复执行不重复计入上表。

专项实际覆盖：

- 原生 CHASE 确有实体速度和腿部动画，再受致命伤进入 DEAD。
- 原生 ATTACK/WINDUP 中死亡，取消攻击且不再伤害玩家。
- 死亡后 1.0 s、3.0 s 的全部局部子节点姿态不变，周期参数冻结；倒地根节点已稳定。
- 恢复原生 `_process`/物理回调继续运行 3 s，并发送迟到攻击、受击、pose 请求，仍不能恢复站立或行走。
- 双腿仍然存在并可见；实体全局变换不变，材质属性恢复。
- 测试夹具中的另一存活僵尸继续正常行走；玩家动画继续运行。第二僵尸仅用于隔离测试，没有加进游戏场景或实现多敌人玩法。
- SHA 检查确认：本轮其他玩法源码、资源、布局和参数未改动。

日志和 JSON 位于 `tests/results/zombie_death_fix_final_run.log`、`zombie_death_pose_validation.json`、`zombie_death_pose_render.log`。此前更早历史 SHA 冻结基线的七项差异没有在本轮迁移或改写；此处的 288/288 指本轮要求的相关回归，不宣称所有历史门禁已经全绿。

## 真实渲染

以下为 Godot 实际输出，非生成图片；截图和脚本检查不能替代玩家人工确认。

| 死亡前状态 | 1 秒 | 3 秒 |
|---|---|---|
| CHASE | [CHASE_1s.png](E:/GameProject/PostApocalyptic3DTest/screenshots/zombie_death_fix/CHASE_1s.png) | [CHASE_3s.png](E:/GameProject/PostApocalyptic3DTest/screenshots/zombie_death_fix/CHASE_3s.png) |
| ATTACK | [ATTACK_1s.png](E:/GameProject/PostApocalyptic3DTest/screenshots/zombie_death_fix/ATTACK_1s.png) | [ATTACK_3s.png](E:/GameProject/PostApocalyptic3DTest/screenshots/zombie_death_fix/ATTACK_3s.png) |

1 秒和 3 秒的时间点由精确物理 delta 推进采样，另外继续原生回调验证稳定性。截图中即时 FPS 不是性能基准，本轮不声称性能提升。

## 可运行入口及人工确认

关闭旧游戏窗口后，双击原有 [RunStage5C3B.bat](E:/GameProject/PostApocalyptic3DTest/RunStage5C3B.bat) 加载本次修复，不需修改启动参数。

仅请重点复查：

1. 在僵尸 CHASE 时击杀，观察倒地过程保留；1 秒、3 秒后双腿和手臂不再摆动。
2. 在僵尸起手攻击时击杀，确认倒地后无挥击/受击循环，也无迟到伤害。
3. 绕尸体移动、攻击或切换视角，确认尸体不恢复站立；玩家自身动画正常。
4. 重启后存活僵尸仍正常追击/行走，原有倒地方向与速度无明显异常。

这些人工项目仍为**待验收**；用户已说明其他已测试功能正常，本轮没有据此擅自标记尸体修复人工通过。已停止开发，不新增功能。
