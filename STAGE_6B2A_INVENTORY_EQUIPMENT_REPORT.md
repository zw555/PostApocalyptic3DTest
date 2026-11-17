# Stage 6-B.2-A：正式背包 UI 与主手装备系统

**最终状态：等待玩家人工验收。** 日期2026-11-17，Godot4.5.2。

## 1. 实施前审查与基线

项目E:/GameProject/PostApocalyptic3DTest；分支main，HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127`。实施前tracked diff与staged diff为空，存在658个未跟踪文件。初始1959个非生成文件的哈希、完整Git状态及本轮允许修改文件的原始正文保存在 `tests/results/stage6b2a_initial_audit.json`，没有把历史Stage6未提交成果算作本轮新增。

玩家明确确认B.1人工验收通过；本轮已将B.1报告更新为**人工验收PASS，玩家于2026-11-17确认通过**，并替换相关仍待验收措辞。历史自动JSON中的PENDING不改写。

已读B.1报告、InventoryModel/ItemDatabase、统一InteractionBroker、场景继承、玩家控制开关、门及可见性注册链。B.1事务只能单向转移，不能安全完成满背包中的武器互换；因此新增一个通用双向原子交换接口，不让EquipmentModel直接写私有槽位。为正式入口取消调试依赖，仅给B.1装配增加可覆盖的面板创建方法，且延迟load调试模块。B.1原入口仍创建原调试面板，B.2-A不创建/调用它。

建筑、楼梯、相机、玩家移动/攻击、门状态机、VisibilityZone、Portal权限、Coordinator/cache算法均不改。20个已有visibility脚本SHA256前后完全一致。原InventoryModel已有方法内容对照一致，只在末尾新增exchange_with。除下列3个授权修改文件外，其余1956个已有文件内容均保全。未执行暂存、提交、推送、reset或clean。

## 2. 新增与修改文件

修改：

|文件|原因|
|---|---|
|STAGE_6B1_ITEM_INTERACTION_REPORT.md|记录玩家人工PASS及日期，保留旧测试成绩|
|scripts/items/inventory_model.gd|新增通用exchange_with双向事务；不改已有add/remove/transfer行为|
|scripts/gameplay/stage6b1_main.gd|将原调试面板创建提取为可覆盖方法、改为延迟load；B.1默认行为不变|

新增：

- `RunStage6B2A.bat`
- `RunStage6B2AFullPackTest.bat`
- `scenes/apartment/stage6b2a_inventory_equipment.tscn`
- `scripts/gameplay/stage6b2a_main.gd`
- `scripts/items/equipment_model.gd`
- `scripts/ui/inventory_equipment_panel.gd`
- `tests/audit_stage6b2a.py`
- `tests/benchmark_stage6b2a.gd`
- `tests/benchmark_stage6b2a_paired.gd`
- `tests/fixtures/stage6b2a_full_pack.gd`
- `tests/fixtures/stage6b2a_full_pack.tscn`
- `tests/run_stage6b2a_tests.ps1`
- `tests/validate_stage6b2a_equipment.gd`
- `tests/validate_stage6b2a_journey_ui.gd`
- `STAGE_6B2A_INVENTORY_EQUIPMENT_REPORT.md`

新脚本配套Godot.uid，最终15张有效截图与contact.png位于screenshots/stage6b2a；初次失败点击截图另存initial子目录。完整新文件清单、旧文件哈希及3文件对照diff见 `stage6b2a_final_audit.json`、`stage6b2a_allowed_changes.diff`，修改前正文可从initial_audit核对。上述文件均在本轮新建的tests/results路径；历史原测试结果未覆盖。

## 3. UI与唯一数据来源

正式入口RunStage6B2A.bat → stage6b2a_inventory_equipment.tscn → stage6b2a_main → B.1已验收住宅楼，继续使用原三个容器。初始库存为空；玩家实际到五/四/三楼领取，不能由正式UI生成测试物资。

背包为4列×3行共12个Button槽位，显示槽序号、物品名称、数量，空槽显示占位文字。单击选中，右侧显示名称、类别与description；主手区显示空/当前武器，提供装备、卸下与关闭按钮。没有生成新美术，没有手持模型和攻击动画。

UI只持有InventoryModel、ItemDatabase与EquipmentModel引用。所有物品数量来自snapshot/get_stack/count_item；没有第二份独立库存，也不解析HUD文字。订阅InventoryModel.changed和EquipmentModel.changed进行刷新；静止时不逐帧重建12槽。改变物品后若原选中槽的ID变化，选择清空，防连续按钮操作误用旧选中物品。

按钮操作还把expected_id传给装备模型再次校验。非允许物品的装备按钮禁用，底层API也独立拒绝；空主手卸下按钮禁用。容量不足时卸下按钮仍可尝试，以显示明确失败原因，状态不变。界面关闭时不执行装备动作。

正式入口不实例化B.1测试面板；历史RunStage6B1仍保留原DebugOnly测试流程。本轮另提供独立RunStage6B2AFullPackTest.bat，仅用于手动复现满包拒绝，不参与正常入口初始化。

## 4. 主手与原子事务

EquipmentModel只管理MAIN_HAND，内部组合一个1槽InventoryModel，通过公共事务接口操作它，外部不接触其_slots。允许ID默认为combat_knife、baseball_bat，还校验类别WEAPON和max_stack=1。装备状态不写入ItemDefinition，没有耐久、词条、UUID或属性效果。

|接口|用途|
|---|---|
|equipped_item_id / snapshot|只读当前主手ID，snapshot键为MAIN_HAND|
|allows_item|验证允许ID、类型及堆叠约束|
|equip_from(backpack, slot, expected_id)|从背包取1份武器；主手有旧武器时同时返还旧物品|
|unequip_to(backpack)|调用原transfer_all_to，将主手1份物品放回背包；满包拒绝|
|changed(revision)|由已提交的内部库存变更转发，供UI刷新|

InventoryModel.exchange_with(target, outgoing, incoming)新增了最小通用能力：复制请求与两边槽位，在分离计划中先移除两边要交出的物品，再添加双方要收到的物品，全部验证成功后同时提交。这样满包也可用即将腾出的武器槽接收旧主手，不需要临时额外格子。

成功返回ok、reason=exchanged、actual_quantity、items（交出清单）、received（收到清单）；actual_quantity为两方向实际移动总份数，单次换装为2。失败实际移动0份、两边snapshot/revision不变，无变更通知。实例Stack每边独立复制；两个库存都提交并锁定后才发通知，观察者不能看到交换中途状态或重入事务。

例如背包有短刀、主手有棒球棍：一次exchange使主手变短刀，背包变棒球棍。没有“先卸下，再装备”的两个独立提交窗口。EquipmentModel还有自身重入锁，同武器重复装备拒绝；旧选中ID失效、空槽、非武器、容量不足均返回失败而不改变数量。

正常两武器总量始终满足：背包该ID数量＋主手是否该ID的0/1数量＝已持有总量。空主手卸下、连续点击、失败重试不会凭空复制或丢失物品。卸下复用B.1原事务，换装新增接口也没有改变旧转移契约。

## 5. 输入处理与探索恢复

- I在新增场景_input中打开/关闭，忽略echo；Esc只关闭已打开面板。左键选择/按钮操作走真实Godot GUI事件。
- 打开时保存原controls_enabled，置false并清速度，清WASD actions；若已存在近战准备组件，调用其原cancel_pending_attack接口。没有为此修改移动或战斗核心。
- 打开期间每物理帧保持角色控制关闭、速度为零；原移动回调不运行move_and_slide，角色在平台/坡面保持停止。其他世界系统不做全局暂停，门扇仍由原安全算法处理。
- 模态全屏遮罩使用STOP鼠标过滤，GUI处理鼠标后世界_unhandled_input收不到点击；键盘世界操作被入口消费。can_interact及interact_selected也再次检查模态状态，直接调用API不能绕过E锁。
- 关闭时恢复先前控制状态并检查存活。若WASD仍实际按住，等待释放后恢复，避免关闭时旧方向输入造成自动移动；新一次按键可正常移动。若关闭时左键仍按住，其释放事件被吞掉，避免残留准备攻击释放。
- 控制恢复时同步刷新InteractionBroker及提示，因此关闭背包同一帧再按E也使用已显示的当前目标；没有重建第二套E入口或静默换目标。

只有一个正式模态界面，B.1不存在另一个搜刮面板；调试面板在正式入口禁用。未来接入额外模态界面应复用同一输入锁生命周期，而非让多个窗口分别改controls_enabled。

## 6. 自动验证

|新增验证|通过|失败|
|---|---|---|
|装备/通用交换数据专项|19|0|
|headless真实住宅楼领取＋UI＋输入＋门/楼梯|97|0|
|真实Forward+渲染与GUI鼠标事件回放|97|0|

数据专项覆盖空主手装备短刀、两种武器互换、卸下、非武器/空槽/过期选择拒绝、重复操作、满包卸下失败、满包原子换装、计划中两边已移除且一边添加后再失败的回滚、观察者完整性及重入保护。

场景从501出门关门，领取五楼水/绷带、四楼电池/罐头、三楼两武器，实际走楼梯返回。UI确认12槽与六种物品，点击读取描述，真实按钮装备/交换/卸下，满包反馈不改变数据，重复点击无复制；期间WASD、E和模拟世界攻击接收器被挡住。关闭后新输入可移动，关闭按钮及I/Esc快速切换正常，按住左键关闭后的释放不触发世界行为，关闭同一帧E合法恢复。

额外在501门口与楼梯坡面打开背包，按W/E后人物保持位置、无门/领取动作，关闭并释放按键后控制恢复。F1/F2/F5/F6分别捕获世界和背包画面。测试用攻击接收器仅记录事件，并验证它在UI关闭时确实能接收点击；正式入口没有近战攻击组件，也没有由此新增战斗。

旧套件在新的stage6b2a_regression_workspace副本执行，写入其内部旧结果路径，原工作区旧产物不覆盖：

|套件|PASS行|FAIL行|退出码|
|---|---|---|---|
|validate_stage6b1_data|34|0|0|
|validate_stage6b1_broker|9|0|0|
|validate_stage6b1_interaction|64|0|0|
|validate_stage6b1_existing|53|0|0|
|validate_stage6b1_presentation|26|0|0|
|validate_stage6b1_building_journey|75|0|0|
|validate_stage6a3a4|53|0|0|
|validate_stage6a3a4_presentation|26|0|0|
|validate_stage6a3b_configuration|31|0|0|
|validate_stage5c3b|41|0|0|
|validate_camera_presets|49|1|1|
|validate_player_occlusion|49|1|1|

两项历史冻结失败仍各49/50，唯一失败仍为旧manifest对player_controller.gd及survivor_animator.gd的哈希断言；未改旧断言或将它们统计为通过。

初次真实渲染卸下点击失败时，模型数据没有丢失：窗口真实光标与注入点击坐标不一致，BaseButton未发出pressed。测试补齐鼠标位置/运动同步后，同一实际按钮路径通过；原失败JSON、日志和截图保留为*_initial/initial，不算最终成功证据。没有用直接调用模型替代真实GUI回放。

导入、独立入口/B.1入口/满包夹具headless启动、PowerShell runner语法均检查通过。重跑：`powershell -ExecutionPolicy Bypass -File tests/run_stage6b2a_tests.ps1 -Render -Benchmark -Regression`；`python tests/audit_stage6b2a.py`复核3个允许修改、冻结核心、旧库存方法、数据/UI结果和15张真实帧。

## 7. 真实渲染截图

15张最终1440×1000原生渲染，含六种物品、装备短刀、交换棒球棍、卸下、满包拒绝、门口/坡面暂停，以及四视角世界与模态界面。每张对应背包snapshot、主手snapshot、位置、相机和size记录在stage6b2a_journey_ui_render.json。

![背包与主手装备真实渲染](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6b2a/contact.png)

完整阅读示例：`screenshots/stage6b2a/03_bat_equipped.png`，满包反馈：`05_full_refused.png`。截图只作核验/排版，没有生成图片替代游戏画面。

## 8. 性能对比与异常分析

RTX4060 Laptop GPU，Forward+ Vulkan，1440×1000、size9.2、同固定位置与相机模式、门初始状态、渲染配置，前台、禁VSync。没有并行Godot测试干扰采样。B.1基线使用旧入口（共享接口扩展不改变其行为），B.2-A正式入口无调试面板。

### 原有80渲染帧预热采样

沿用之前采样器：每点预热80个渲染帧、采样240帧。首轮与反向复测均出现若干>15%增幅，不能用FPS高掩盖：

|位置|首轮平均帧 / Coordinator增幅|反向复采平均帧 / Coordinator增幅|
|---|---|---|
|apartment|+18.6% / +18.1%|-3.9% / -3.1%|
|hall|+25.5% / +25.2%|+10.3% / +8.5%|
|turn|+7.4% / +11.1%|+41.8% / +37.1%|
|fourth|+18.4% / +11.5%|+24.6% / +20.9%|

原始before/after和*_initial数据完整保留。定位发现：两入口都注册593个Geometry记录，四点候选分别423/315/169/247；B.2-A静止UI刷新次数始终1，没有每帧扫描库存/装备或增加全楼层扫描。20个可见性脚本与候选集不变。关闭背包的Draw Calls通常低于旧B.1，因为不再绘制原测试面板。不能据此直接解释所有CPU增幅。

80个渲染帧在不同FPS下对应不同实际物理时间，不能保证CameraOcclusion原迟滞/渐变已稳定；不同进程/短样本也有明显时间波动。这是定位依据与可能因素，不能将全部增幅武断归因于某个单一原因。

### 同进程ABBA、物理时间预热对照

增加同进程B.1→B.2-A→B.2-A→B.1诊断；每点预热80个物理帧（60Hz约1.33秒），再采样240渲染帧。每版本每位置合计480帧，减轻新进程及短预热影响。四点稳定遮挡state数量分别1/6/3/2，各轮一致；候选、几何、UI刷新次数也一致。此组与上述80渲染帧方法分别报告，不混成同一统计样本。

|位置/视角|FPS B.1→B.2-A|平均帧ms|两轮P95范围ms|Draw Calls|Coordinator µs|CameraOcclusion µs|平均帧 / Coordinator增幅|
|---|---|---|---|---|---|---|---|
|apartment|209.49 → 221.13|4.773 → 4.522|6.771～7.239 → 6.645～7.681|675.0 → 662.0|2659.2 → 2548.0|177.8 → 178.0|-5.3% / -4.2%|
|hall|238.05 → 243.92|4.201 → 4.100|5.616～6.135 → 5.899～6.679|429.0 → 416.0|2177.4 → 2147.5|239.9 → 229.0|-2.4% / -1.4%|
|turn|356.47 → 399.86|2.805 → 2.501|4.355～4.441 → 4.061～4.065|243.0 → 230.0|1269.9 → 1173.1|191.6 → 183.5|-10.9% / -7.6%|
|fourth|300.44 → 296.05|3.328 → 3.378|3.893～6.059 → 4.955～5.224|343.0 → 330.0|1743.5 → 1778.9|149.0 → 156.0|+1.5% / +2.0%|

FPS由两轮等样本平均帧耗时换算；P95列是各版本两轮P95的取值范围，不将两个P95均值当总体P95。位置分别501/F6、五楼道/F6、五至四楼转角/F6、四楼平台/F2。

ABBA未复现稳定>15%的计算增幅；四楼仍有约1.5%平均帧和2.0%Coordinator增加。它不能抹掉前两轮结果，也不能证明全机器零成本或性能提升。可确认新增代码没有引入逐帧模型刷新、装备扫描或可见性算法改变；性能结论限于本次固定站位和硬件，动态整理/自由探索仍需人工。

独立空包模态打开采样（只给绝对值，不与不同进程closed直接差分归因）：

|位置|平均帧ms|P95 ms|Draw Calls|Coordinator µs|
|---|---|---|---|---|
|apartment|4.495|6.715|699.0|2550.2|
|hall|3.946|5.998|462.7|2106.8|
|turn|2.684|4.110|286.6|1220.5|
|fourth|3.063|4.097|371.4|1639.3|

真实六物品交互渲染通过，但这张静态性能表的模态包为空。后续B.2-B仍应测满包文本、连续交换和开关延迟。原始数据为stage6b2a_perf_before/after/after_modal.json、*_initial.json及stage6b2a_perf_paired.json；后者明确记录ABBA次序及物理预热方法。

## 9. 已知限制与人工验收风险

- **等待玩家人工验收。** 自动键鼠事件、固定截图不能替代玩家实际手感与不同输入焦点环境。
- 本轮只做主手，装备仅UI显示。没有攻击、武器手持模型/动画、耐久、属性、UUID、存档、僵尸，也不实现拖拽、拆分、丢弃或快捷转移。
- 会话重启后背包/主手/容器恢复初始值；原R仍是回出生点，不重置库存或装备。
- UI暂停玩家运动而非全局暂停。门扇原状态机可继续完成动作；门口和坡面已覆盖，但任意擦边站位、失焦、特殊键盘环境仍需人工检查。
- 控制锁当前针对原WASD与左鼠标生命周期，等待按键释放是有意防残留。若关闭时仍按住W，须释放再按；不是把持续旧按键解释为新的移动命令。
- 布局针对当前项目桌面分辨率；没有验证极小窗口、手柄、输入重映射或移动端。
- 满包人工夹具会注入固定测试物品，只用于拒绝卸下测试。正常入口仍必须到三个容器领取，正式UI没有加物品/清库存按钮。
- 旧历史哈希冻结门禁未全绿；短时性能有明显波动，完整证据保留，不宣称永久基准改善。

## 10. 人工验收步骤

正式入口：**RunStage6B2A.bat**。I开关背包，Esc/关闭按钮关闭，左键选中、装备/卸下按钮操作。先使用正常入口验收；满包夹具另行测试。

1. 从501出门并关门；五楼领取瓶装水/绷带，四楼领取电池/罐头，三楼领取短刀/棒球棍。途中可随时I查看，确认领取后数量自动更新，空箱重复E不重复奖励。
2. 三楼平台打开背包，确认六种物品与6个已用槽；单击每种物品，检查名称、类别、描述及非武器不能装备。
3. 选短刀→装备，主手为短刀、背包不再有该份短刀；选棒球棍→装备，主手变棒球棍、短刀回包；再换回短刀，连续点击检查总量不变。
4. 卸下，主手为空、两武器均在包。重复卸下/装备，不得复制或丢失。
5. 背包打开时按WASD、E、鼠标左键/按钮，应只操作UI；不能误开门、领取物品或移动。关闭后马上移动/E，反复快速I/Esc和关闭按钮；按住方向或左键关闭后先释放，检查无自动移动/攻击残留。
6. 在501门口、卫生间门口、四楼平台和楼梯坡面分别开关背包；确认不滑动，关UI后门和移动正常。F1/F2/F5/F6分别在关闭状态切换视角，再打开检查显示。
7. 独立运行**RunStage6B2AFullPackTest.bat**：预设短刀在主手、12槽电池已满。点击卸下，应提示容量不足，主手短刀与背包120电池均不变。此入口退出后重新用正式入口探索。
8. 正常场景连续探索/整理至少两分钟，返回旧楼层容器检查状态仍空，最终回到501。

**跳过装备交换测试，未来战斗接入后可能出现复制或丢失；跳过UI输入测试，可能整理背包时误开门、误攻击或误领取；跳过楼梯与门口，可能遗漏关闭后的控制异常。** 本报告不将上述人工步骤写成已经逐项通过。

## 11. B.2-B建议及Git收尾

先等本阶段人工反馈，再决定拖拽、Shift转移、右键或拆分是否值得实现；不要自动进入B.2-B。若增加操作，继续复用原子transfer/exchange及事件刷新，禁止让UI直写_slots或在ItemDefinition写装备状态。多面板统一复用模态锁，拖拽需校验选中ID/版本，避免旧槽位事件误操作。

B.3可读取EquipmentModel.equipped_item_id选择武器配置，但本轮不加攻击效果。仅当未来真正需要耐久/实例差异时再评估实例身份，不提前制造UUID。

当前HEAD/暂存区未变，历史未跟踪成果仍在。后续由玩家决定按B.0清单保存A.4/B/B.1基线，再逐路径审核本轮三个修改文件和新模型/UI/入口/测试/报告。tests/results被忽略，若需版本化只显式选择证据文件，不加入隔离回归副本、.godot/build或整份机器快照。本轮未暂存、提交或推送。

**完成后停止；等待玩家人工验收，不自动进入B.2-B。**
