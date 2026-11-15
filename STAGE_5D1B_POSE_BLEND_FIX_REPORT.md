# D.1-B：短按准备与攻击过渡修复

## 根因与复现

检查了原近战控制器、程序化攻击视觉、玩家步态与最终受击姿态脚本。左键按下即开始准备，没有输入延迟。生硬切换来自视觉路径：

1. D.1-B 的 `_process_stance()` 每帧先调用 `_pose_normal_attack()`，把武器套入固定起始 yaw=-0.95 的普通挥击。
2. 随后又按 `stance_blend` 覆盖为准备姿态。松开后该权重以每秒 8 衰减，权重归零时，武器切回另一条普通轨迹。
3. 起手没有保存实际手臂、前臂、武器和上身姿态。手臂每帧从步态基底再混合，普通攻击与准备轨迹并非同一连续动作。
4. UpperBody 本来已有唯一最终写入者，并不是两个无序的反馈控制器抢写；但最终的额外指数平滑又会让上身落后于已经计算的姿态。

新增定点检查在修复前取得 18 通过、18 失败。60Hz、固定站姿与朝向下，0.05s 短按最大单帧节点旋转约 40.42°，武器尖端步进约 0.550m。原始结果保留于 `tests/results/pose_blend_repro.json`，未覆盖。

## 修改文件与融合方式

本轮只修改两个既有玩法源码：

- `scripts/combat/stage5c1_character_attack_visual.gd`
  - `play_attack()` 保存输入释放时实际显示的右臂、前臂、武器和上身姿态。
  - D.1-B 不再先写固定普通挥击再用准备姿态覆盖；改为计算一个最终姿态，再各写一次。
  - 普通和预备攻击共用“当前姿态 → 命中姿态 → 收势 → 当前步态基底”的轨迹，分别按既有 0.20s/0.08s 前摇采样。
  - 使用有界的角度插值与五次 smoothstep 进度，不先回默认姿态，不重设固定起手角度。恢复中再次准备也从上次显示姿态衔接。
  - 武器握点继续跟随实际右手，轨迹从同一姿态计算，避免位置重置。
- `scripts/combat/stage5c3b_player_feedback.gd`
  - 预备/挥击的融合输出直接交由原 UpperBody 最终写入者应用，避免第二层平滑造成相位落后。
  - 受击与死亡仍具有最终优先级，保留其原处理。

原步态先提供基础姿态，攻击视觉有序叠加右臂和武器，反馈脚本最终处理上身；没有引入新的 AnimationTree、Skeleton、模型、材质或动画系统。

新增文件：

- `tests/validate_stage5d1b_pose_blend.gd`
- `tests/run_pose_blend_tests.ps1`
- `screenshots/pose_blend_fix/` 的九张真实渲染图。
- 本报告。

本轮没有改近战逻辑脚本、输入、伤害、HP、移动、准备倍率、命中距离、扇形、击退、冷却、AI、场景或搜刮。专项读取本轮开始时的 SHA，验证除上述两个视觉脚本之外的所有既有脚本、配置和资源保持不变。此前 D.1-A/B 的未提交工作保留，没有提交或推送。

## 修改前后时间线

| 时刻 | 原视觉 | 修复后 |
|---|---|---|
| 按住左键 | 开始准备抬手 | 仍从当前显示姿态逐渐抬手 |
| 短按释放 | 固定普通轨迹与残留准备权重混用 | 保存当前实际姿态，作为本次挥击起点 |
| 释放到 0.20s | 准备权重消失时切回普通轨迹 | 连续推进到共同命中姿态 |
| READY 释放到 0.08s | 单独的快速轨迹 | 同一轨迹结构，以 READY 当前姿态为起点、更快采样 |
| 命中后 | 各分支分别收束 | 共同收势并返回步态基底 |

没有增加起手等待或固定攻击过渡延迟。0.30s READY、0.20s 普通命中、0.08s 快攻命中、0.65s 最小起手间隔和原 0.55s 动作收束均不变。

取消准备/被中断时存在最长约 0.12s 的纯视觉回落，只处理回到普通手臂姿态；它不延迟起手、伤害、控制解锁或死亡判定，也不是本次短按衔接的实现方式。受击/死亡的上身最终姿态仍优先。

## 自动结果与实测变化

执行：

```powershell
./tests/run_pose_blend_tests.ps1 -Capture
```

| 检查 | 通过 | 失败 | 说明 |
|---|---:|---:|---|
| 新姿态专项 | 54 | 0 | headless 与真实 Vulkan 渲染均执行，不重复累计 |
| D.1-B 左键方案 | 73 | 0 | 包含模拟两分钟输入、原生释放与真实僵尸前摇打断 |
| C.1 | 41 | 0 | 原测试 |
| C.2 | 22 | 0 | 原测试 |
| C.3-A | 39 | 0 | 原测试 |
| C.3-B 逻辑 | 41 | 0 | 原测试 |
| C.3-C | 84 | 1 | 唯一失败为已有授权源码变更触发的冻结检查 |
| D.1-A | 51 | 1 | 所有行为通过；唯一失败为只允许修改僵尸控制器的旧源码保护 |
| 僵尸死亡姿态 | 28 | 1 | 所有行为通过；唯一失败为旧源码保护 |

旧十组兼容性套件仍保留七组历史冻结断言失败。未改任何原测试断言或旧 SHA；总入口保留非零退出码，**不宣称完整历史门禁全绿**。本轮未发现新增功能断言失败。脚本解析、Smoke 与场景加载通过。

新专项覆盖：0.05/0.10/0.20/0.299/0.31/2.30s 按住后释放（最后一项代表 READY 保持约 2s）；释放点姿态和握点连续性；逐帧角度及尖端轨迹；到达原命中时刻、无提前或重复伤害；连续短按；恢复中再次按下；受击/死亡/搜刮中断；45°/65°/85°；真实回调顺序；非视觉源码 SHA 不变。

以下是在同一局部姿态坐标、60Hz、固定朝向、固定相机条件下测量的前摇数据，属于自动采样而非人体动作质量评分：

| 按住时长 | 最大单帧节点旋转：前 → 后 | 最大尖端步进：前 → 后 |
|---|---:|---:|
| 0.05s | 40.42° → 7.06° | 0.550m → 0.087m |
| 0.10s | 33.60° → 5.39° | 0.473m → 0.062m |
| 0.20s | 20.37° → 9.28° | 0.275m → 0.131m |
| 0.299s | 15.91° → 11.67° | 0.227m → 0.182m |
| 0.31s | 16.01° → 28.62° | 0.252m → 0.440m |
| 2.30s | 16.01° → 28.62° | 0.252m → 0.440m |

短按分支的突兀重置和反向抽动已在数值检查中消除。快攻仍需在 0.08s 完成 READY 到命中的较大运动；新曲线在起止处缓和，中段速度更集中，因此其峰值步进比旧线性快攻更大。此项已如实保留，**不能据自动通过宣布快攻手感更好**，需玩家确认。

释放点姿态差异小于 0.002rad、尖端位置差小于 0.002m；角度读数存在 Quaternion 单精度换算误差。前摇内检查不会先回零再起手，两种攻击均在原逻辑时刻对齐命中姿态。测试只在最终采样使用亚纳秒误差余量跨越十进制浮点阈值，游戏计时未改。

主要证据：

- `tests/results/pose_blend_repro.json`：修复前。
- `tests/results/pose_blend_validation.json`、`pose_blend_render.log`：专项与渲染。
- `tests/results/pose_blend_final_run.log`、`pose_blend_run_summary.json`：整轮原始输出。
- `tests/results/stage5d1b_run_summary.json`、`stage5c3c_legacy_runs.json`：旧回归及冻结失败明细。

## 实际截图与人工入口

截图由真实 Godot 场景节点渲染。定点截图使用精确物理进度与原姿态回调顺序采样，另有自动恢复原生回调的输入检查，不代表玩家人工操作。

| 视角 | 0.10s 短按释放前 | 释放点 | 原 0.20s 命中点 |
|---|---|---|---|
| 45° 斜向 | [前](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F6_short_before.png) | [释放](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F6_short_release.png) | [命中](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F6_short_impact.png) |
| 65° | [前](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F2_short_before.png) | [释放](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F2_short_release.png) | [命中](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F2_short_impact.png) |
| 85° | [前](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F1_short_before.png) | [释放](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F1_short_release.png) | [命中](E:/GameProject/PostApocalyptic3DTest/screenshots/pose_blend_fix/F1_short_impact.png) |

关闭旧游戏窗口后，双击原入口 [RunStage5D1B.bat](E:/GameProject/PostApocalyptic3DTest/RunStage5D1B.bat)。没有新建或改变游戏启动场景。

人工请重点检查：

1. 反复短按约 0.05/0.10/0.20s，以及接近 READY 阈值前松开，确认从当时手臂位置继续挥击，不先回默认姿态。
2. READY 保持约 2s 后释放，确认快攻连贯，特别判断中段较快的转动是否自然。
3. 连点、恢复中重新按住、边移动边短按与长按，检查手臂和武器没有抽动或跳到别处。
4. 准备或挥击时受击、死亡、打开搜刮，确认取消后不迟到命中，受击与死亡姿态正确。
5. F6/F5 45°、F2 65°、F1 85°和近远缩放下检查实际可读性及命中接触感。

## 限制与验收状态

- 已实现：实际姿态起手、共用挥击轨迹、有序单次最终姿态应用，玩法计时不变。
- 已自动验证：连续性、状态、伤害时序及上述回归功能。
- 已完成实际渲染检查：三种游戏相机的定点截图。
- **人工验收待完成**：动作自然度、快攻峰值速度、走位和鼠标急转时的观感。
- 当前测量是相对角色局部姿态；角色转向、移动和相机运动会改变屏幕轨迹。低渲染帧率下 0.08s 快攻帧数少，不能保证与高帧率同样细腻。
- 未增加 IK、骨骼或 AnimationTree；轻量程序化人物的表现上限仍存在。
- 截图 FPS 不作为性能基准，没有宣称性能改善或正式视觉验收通过。

完成后停止，等待玩家人工验收。
