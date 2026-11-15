# Stage 5-C.1：3D 近战方向与攻击表现验证

项目：`E:/GameProject/PostApocalyptic3DTest`  
引擎目标：Godot 4.5.2  
状态：Stage 5-C.1 缺陷修复完成；Godot 4.5.2 解析、场景加载、专项自动验证和三视角渲染验证已恢复，人工验收仍待执行。

2026-11-15 修复：将 `move_left/right/forward/back` 的 InputMap 注册下沉到 `scripts/player_controller.gd` 的 `_ready()`，并在物理帧保留兜底初始化，解决某些独立验证入口先进入玩家物理帧而动作尚未注册时的 `InputMap action doesn't exist` 错误。

2026-11-15 Stage 5-C.1 修复：统一 `attack_resolved` 的阻挡目标信号类型；按时间区间跨越检测近战有效窗口；将挥击轨迹顶点统一转换到轨迹节点局部空间；修正 DebugHUD 追加路径；为瞄准期间关闭移动控制器的自动转身，恢复后退/横移与鼠标面向独立；补充真实 UI、墙体/货架、窗口缩放和三视角运行验证。

## 已实现

- `Stage5C1AimController`：使用当前 `Camera3D` 的投影射线与玩家高度水平面求交，鼠标对应世界坐标后只绕 Y 轴平滑转向；鼠标靠近玩家投影时保留上一有效朝向。
- `Stage5C1MeleeAttackController`：左键单击、0.65 秒冷却、0.20–0.39 秒理论命中窗口、1.5 米距离、90° 扇形；移动与攻击独立，候选目标只取 `validation_zombie`，不扣血。
- 物理遮挡：命中前从玩家躯干高度向目标躯干发射建筑/敌人层射线，货架和墙体会把候选目标标记为 blocked。
- `Stage5C1CharacterAttackVisual`：程序化短棍、水平挥击弧线、短暂轨迹线和轻微上半身反馈；不改变玩家世界位置，不改 Idle/Walk 脚部动画。
- F11 调试：显示玩家朝向、鼠标世界坐标、攻击距离、扇形、攻击状态、理论命中和被遮挡目标。
- 独立场景：`scenes/combat/stage5c1_melee_validation.tscn`，继承现有 Stage 5-B 追逐场景；未修改便利店布局、搜刮规则、导航或僵尸控制器。

## 修改文件

| 文件 | 用途 |
| --- | --- |
| `scripts/combat/stage5c1_aim_controller.gd` | 鼠标到世界平面的投影和角色朝向 |
| `scripts/combat/stage5c1_melee_attack_controller.gd` | 输入、冷却、扇形候选和遮挡判定 |
| `scripts/combat/stage5c1_character_attack_visual.gd` | 临时短棍、挥击和轨迹 |
| `scripts/combat/stage5c1_validation_main.gd` | Stage 5-C.1 场景装配与反馈 |
| `scenes/combat/stage5c1_melee_validation.tscn` | 可运行验证场景 |
| `tests/validate_stage5c1.gd` | 相机、缩放、冷却、UI、遮挡和无伤害验证 |
| `tests/stage5c1_capture.gd` | 三视角、范围调试和挥击截图 |
| `tests/run_stage5c1_tests.ps1` | 自动验证入口 |
| `RunMelee.bat` | 桌面启动入口 |

## 自动验证

入口：

```powershell
./tests/run_stage5c1_tests.ps1 -Capture
```

测试覆盖设计为：45°/65°/85° 世界坐标瞄准一致、缩放不改变攻击参数、移动与朝向独立、单击与冷却、动画不叠加、墙体遮挡、搜刮 UI 拦截、无生命值/伤害接口及 Stage 5-B 场景复用。

本轮实际结果：`tests/run_stage5c1_tests.ps1 -Capture` 返回成功；专项结果为 41 passed / 0 failed，渲染结果为 18 passed / 0 failed。日志、命令、stdout/stderr 和退出码位于 `tests/results/stage5c1_*.{command.json,log,stdout.log,stderr.log,exitcode.txt}`。本轮正式命令未出现 `signal 11` 或 `CrashHandlerException`；历史报告中的 signal 11 证据仍保留在旧日志和本文件的版本历史中。

原有 Stage 5-B/4-D 回归的功能断言均通过，但旧基线的“源文件 SHA256 不可变”检查仍将 `scripts/player_controller.gd` 列为变化项，因此完整回归链不能标记为全绿；该失败没有跳过或篡改基线。

## 人工验收

启动 `RunMelee.bat` 后依次测试：

1. F5：45°；F2：65°；F1：85°。
2. 把鼠标移动到僵尸身体，确认角色朝向与屏幕投影对应的世界方向一致。
3. 左键单击，确认短棍挥击、轨迹和单次触发；按住鼠标不应连续攻击。
4. WASD 移动中继续瞄准和攻击，确认后退/横移不强制改变面向。
5. F11 打开调试，确认扇形和 1.5 米范围与命中逻辑一致。
6. 把僵尸放到货架或墙后，确认调试信息显示 blocked 而不是命中。
7. 打开 E 搜刮面板后点击左键，确认不触发攻击；Esc 后恢复。

人工验收 A–D 当前均为 **待验收**。自动测试恢复运行后，还需要实际生成三种视角截图和 `range_debug_65.png`、`attack_swing_65.png`。

## 未实现

- 生命值、伤害、死亡、掉落、正式背包和武器系统。
- Blender/正式骨骼动画、受击反馈和多目标战斗规则。
- Stage 5-C.2。
