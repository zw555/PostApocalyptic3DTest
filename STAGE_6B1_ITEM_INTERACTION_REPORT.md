# Stage 6-B.1：通用物品数据模型与住宅楼交互基础

**最终状态：人工验收 PASS。** 玩家于 **2026-11-17** 明确确认 Stage6-B.1 人工验收通过；此状态依据玩家确认更新，不改写历史自动测试产物。Godot4.5.2，A.4和6-A.3-B人工验收通过作为前提。

## 1. 实施前只读审查与Git安全

分支 `main`，HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127`。初始tracked diff、staged diff为空，未跟踪556个文件，其中大量是历史Stage6入口、场景、脚本、测试、截图及旧Stage5生成的.uid。完整初始status和1857个已有非生成文件SHA256记录在 `tests/results/stage6b1_initial_audit.json`。不能说工作区干净，也不能把历史未跟踪内容算作本轮新增。

实际入口RunStage6A3B.bat → stage6a3b_floor_extension.tscn → floor_extension_main → 已验收A.4继承链。floor5_main消费E，choose_door选择门，interact_selected调用门.interact；safe_door负责安全旋转与碰撞。Coordinator在floor5_main._ready创建后initialize；B缓存会在initialize快照records，因此容器必须提前注册。

B.0推荐旧阶段路线已由本轮用户新路线替代：B.1数据/交互，B.2背包装备，B.3武器，B.4使用与完整搜刮，B.5僵尸闭环。本轮没有执行B.0建议的僵尸或任务玩法。

已读旧loot_main、shelf_loot_state和搜刮管理器，以及战斗/门/注册接口。旧搜刮事务的预检查/提交思路可借鉴，但旧库存依赖货架slot与GPU隐藏回调，manager还限定世界Y≈0，不能当作通用库存复制。新模型独立于世界坐标、楼层、HUD和玩家；仅场景Adapter知道授权区域与位置。没有发现必须改冻结核心的冲突。

全部既有1857个文件复核内容不变，20个既有visibility脚本（含B缓存和配置）哈希一致。未改建筑、家具、原门、E.1、相机、移动/战斗参数和旧测试断言；未执行git add、commit、push、reset或clean。隔离回归副本使用新的stage6b1_regression_workspace，避免旧测试写入原历史结果。

## 2. 复用与新增边界

|模块|处理方式|
|---|---|
|已验收五至三楼场景、玩家、相机、坡面与碰撞|原样继承B入口；保留A.4/B独立入口|
|floor5_safe_door及floor5_door|原样调用；DoorInteractionAdapter只做资格/距离/高度/射线验证，调用原interact，不复制状态机|
|VisibilityZone、权限、Presentation、Coordinator/cache|原样；通过config.register_object在initialize前注册新容器|
|旧shelf_loot_state/loot_display_manager/loot_main|保留；不继承便利店UI、世界Y或货架库存。没有把旧water静默改名成water_bottle|
|ItemDefinition/Database/Stack/Inventory|新增可复用Resource/RefCounted模型；独立测试，不依赖场景|
|统一E Broker、门Adapter、容器Endpoint|新增；同一能力协议，单一E消费入口|
|容器配置与占位Mesh、诊断面板|新增；内容通过Resource引用，面板可整块移除，不作为B.2正式UI接口|

## 3. 数据结构和六种定义

AHItemDefinition extends Resource：item_id、display_name、description、Category枚举、max_stack、可选Texture2D icon、可选Resource world_visual。类别为WEAPON/CONSUMABLE/MATERIAL/QUEST。定义中没有quantity、used、equipped字段；本轮无图标/武器世界模型及使用效果。

AHItemStack extends RefCounted：只包含item_id和quantity。武器尚无装备/耐久/随机属性，不制造无用途的实例ID。静态定义由catalog.tres显式列举；ItemDatabase.configure验证唯一ID、类别/上限、武器上限1，复制配置后冻结本会话数据库。definition(id)返回脱离内部原型的Resource副本，stack_limit/has_item/ids提供稳定查询；未知ID拒绝加入库存。调整配置须在下一次建立数据库时生效，不运行中替换已有堆叠上限。

|item_id|名称|类别|max_stack|
|---|---|---|---|
|water_bottle|瓶装水|CONSUMABLE|5|
|canned_food|罐头|CONSUMABLE|5|
|bandage|绷带|CONSUMABLE|5|
|battery|电池|MATERIAL|10|
|combat_knife|短刀|WEAPON|1|
|baseball_bat|棒球棍|WEAPON|1|

ItemAmount Resource保存容器初始definition引用和初始quantity，不是共享的运行时Stack。ContainerDefinition只负责容器稳定ID、泛化显示名、配置区域ID/坐标和ItemAmount列表。item_id与数量没有写入交互控制器分支。

## 4. InventoryModel公共接口与事务

默认12槽，可构造其他槽数。库存是RefCounted数据模型，不查节点、不持HUD/玩家、不查楼层。空槽为null，同类先填已有堆叠，再按槽顺序分配；移除后保留槽位空洞，不隐式压缩。武器每份占一槽。

|接口|语义|
|---|---|
|new(database, slot_count=12)|建立独立库存|
|slot_count / remaining_slots|总槽数/空槽数|
|capacity_for(item_id)|该种物品现有堆叠余量＋可用空槽容量；不是格子数|
|get_stack(index) / snapshot() / contents()|脱离内部可变Stack的副本、可序列化槽快照、按ID汇总|
|count_item(item_id)|查询数量|
|add_item / remove_item|正整数、全量原子添加/移除；非法ID/数量/不足均拒绝|
|transfer_to(target, requests)|源到目标指定请求的全量原子转移|
|transfer_all_to(target)|当前容器全部物品作为一笔事务|
|changed(revision)|提交后通知；revision每次成功提交递增一次|

结果统一为 `{ok, reason, actual_quantity, items}`；actual_quantity是实际增/减/转移总份数，items按ID给出实际数量。失败actual_quantity=0，items={}，两边状态/revision不变，不发changed。

**统一策略：每笔全量原子成功或失败，不自动部分领取。** transfer_to可明确请求子集，但请求本身仍整笔原子；本轮E采用transfer_all_to。目标容量不足任何一种物品，全部留在容器。先在分离的计划库存执行所有检查，再复制提交两边；两边提交完毕并锁定后才通知观察者，禁止通知回调期间重入写入。请求字典也先复制，观察者不能改变返回的领取清单。两库存从不共享同一个可变Stack。

不把渲染成功与库存扣除捆绑：本轮不删除物品世界实例，只有一个容器壳体。库存提交后观察者改变该壳体私有材质颜色；即使诊断UI未挂载，数据事务仍独立工作。失败回滚覆盖“第一种物品计划成功，第二种容量失败”，不是只测单物品满包。

## 5. 统一E仲裁

唯一E处理器位于新增stage6b1_main._unhandled_key_input。pressed且非echo时最多调用一次broker.execute_displayed；release/echo不执行，所有E在该层消费，不再转发父类E。其他键仍走原入口。

Endpoint协议：stable_id、can_interact、rank、interaction_prompt、perform。门用RefCounted Adapter，容器Node实现相同能力。排序规则为：**合法门优先于合法容器 → 同类按距离 → 距离近似相同时按稳定ID字典序**。已锁门仍可“查看”，因此也具有门优先级；这是明确的选择规则，不以猜测玩家意图覆盖它。

每帧broker.refresh选目标并生成最终提示。E事件再次检查当前合法最优目标必须等于此前显示目标，否则返回target_changed并更新提示，不静默切到另一个对象执行。perform再验资格；一次按键不遍历执行所有候选。

门沿用1.3m门洞距离与原native碰撞射线（排除该门扇自身），增加相对门所属根的高度差≤0.65m；没有floor==3/501等分支。容器要求主场景can_interact、相对容器UP高度差≤0.65m、脚底距离≤1.3m、既有portal.can_offer_interaction的3D距离与真实LOS/内容权限。新容器不会只按XZ选中，不依赖Mesh是否被相机切开。

提示与实际目标一致性、距离/优先级/稳定ID、目标失效拒绝均有专项测试。新仲裁使用距离规则，可能在楼道偏向另一侧时选中502；门前应看提示，不能假定E永远操作501。首次测试的失败正暴露了这个站位前提，保留initial/diagnostic日志，没有改原门断言。

## 6. 容器位置、内容和可见性

|配置Resource|区域|脚底世界坐标（米）|初始内容|
|---|---|---|---|
|hall.tres|corridor_f05|(-6.08,0,3.50)|water_bottle×2、bandage×2|
|landing_upper.tres|stairs_landing_f04|(-6.75,-3,9.05)|battery×3、canned_food×2|
|landing_lower.tres|stairs_landing_f03|(-6.75,-6,9.05)|combat_knife×1、baseball_bat×1|

这是独立场景的作者配置；通用物品/库存/交互模块不根据这些区域ID推断行为。占位箱体0.32×0.42×0.32m，放在平台/楼道侧边，有native箱体碰撞；既有通行路线的四视角往返仍通过。没有移动楼梯或墙体来让路。

super.create_structure_visibility返回后、Coordinator.initialize之前，三容器完成模型装配和register_object。壳体注册为GameInformation，采用既有discovered=true加当前真实LOS/区域授权（没有新增永久探索系统），并配置相对容器高度区间[-0.45,0.65)。cache初始化时已包含这些记录；没有运行时新增Mesh、改变所属区或缓存失效补丁。

只有一个预注册Mesh和“有物资/空”两种材质色值。材质实例在注册前克隆，记录持有相同材质引用；搜空后只变albedo，绝不调用Mesh.show/hide、不替换注册几何、不另建显隐写入器。Coordinator仍唯一提交Mesh可见性。空箱灰绿色，有物资棕色；空箱仍可E查看并返回empty，不重复奖励。

物品名称只在成功领取反馈和玩家已有库存诊断中显示；未经授权的容器没有提示/高亮/物资列表。B.1不额外添加高亮系统，避免拿深度测试当内容权限。玩家已持有物品清单不因离开领取区域而隐藏，它是玩家库存而非未知容器信息。

离开后再进入仍使用同一InventoryModel，空状态不会从Resource重新拷贝。重新启动本局才重新初始化；原R只回出生点，不清库存或容器。

## 7. 修改文件清单

本轮全部为新增文件，旧文件未修改：

- `RunStage6B1.bat`
- `data/items/bandage.tres`
- `data/items/baseball_bat.tres`
- `data/items/battery.tres`
- `data/items/canned_food.tres`
- `data/items/catalog.tres`
- `data/items/combat_knife.tres`
- `data/items/containers/hall.tres`
- `data/items/containers/landing_lower.tres`
- `data/items/containers/landing_upper.tres`
- `data/items/water_bottle.tres`
- `scenes/apartment/stage6b1_item_interaction.tscn`
- `scripts/gameplay/stage6b1_main.gd`
- `scripts/interaction/container_definition.gd`
- `scripts/interaction/door_interaction_adapter.gd`
- `scripts/interaction/interaction_broker.gd`
- `scripts/interaction/item_container.gd`
- `scripts/items/inventory_debug_panel.gd`
- `scripts/items/inventory_model.gd`
- `scripts/items/item_amount.gd`
- `scripts/items/item_catalog.gd`
- `scripts/items/item_database.gd`
- `scripts/items/item_definition.gd`
- `scripts/items/item_stack.gd`
- `tests/audit_stage6b1.py`
- `tests/benchmark_stage6b1.gd`
- `tests/capture_stage6b1.gd`
- `tests/fixtures/stage6b1_regression.gd`
- `tests/fixtures/stage6b1_regression.tscn`
- `tests/run_stage6b1_tests.ps1`
- `tests/validate_stage6b1_broker.gd`
- `tests/validate_stage6b1_building_journey.gd`
- `tests/validate_stage6b1_data.gd`
- `tests/validate_stage6b1_existing.gd`
- `tests/validate_stage6b1_interaction.gd`
- `tests/validate_stage6b1_presentation.gd`
- `STAGE_6B1_ITEM_INTERACTION_REPORT.md`

新GDScript附带Godot生成.uid。真实截图目录 `screenshots/stage6b1/after/` 共43张，另有contact.png。完整含.uid清单在stage6b1_final_audit.json的new_files；初始未跟踪内容与本轮新增区分以initial_audit为准。

## 8. 自动化结果与历史失败

|B.1专项|PASS|FAIL|
|---|---|---|
|物品与库存数据|34|0|
|交互Broker优先级/距离/稳定ID/显示目标|9|0|
|实际住宅楼门/容器/隔墙/跨层/满库存/领取/返回|64|0|
|B.1场景完整建筑四视角通行回归|75|0|
|B.1场景原A.4内容/信息权限|53|0|
|B.1场景原A.4背景表现|26|0|

数据覆盖ID重复拒绝、会话定义冻结、堆叠上限、武器不可堆叠、添加/移除、容量不足、计划中途失败两边不变、实际领取数量、通知一致与重入保护、请求/Stack/快照隔离。没有改旧断言制造全绿。

实际场景从501出门、关/开门、领取水与绷带，真实CharacterBody3D移动到四楼、三楼领取，再沿楼梯返回；第四/第三层互相不能交互，墙体射线拒绝、超距拒绝、空状态与玩家数量保持。浴室原门开关通过。四视角当前人物头部射线、平台和授权容器状态检查通过。交互测试中的临时移动箱体/临时墙及一次失效目标位置跳变仅为对抗测试；正常楼梯领取与返回没有传送。

旧入口回归在新隔离副本执行：

|原套件|PASS行|FAIL行|退出码|
|---|---|---|---|
|validate_stage6a3a4|53|0|0|
|validate_stage6a3a4_presentation|26|0|0|
|validate_stage6a3a4_journey|60|0|0|
|validate_stage6a3b_journey|75|0|0|
|validate_stage6a3b_configuration|31|0|0|
|validate_stage5c3b|41|0|0|
|validate_camera_presets|49|1|1|
|validate_player_occlusion|49|1|1|

两项历史冻结门禁各49/50：camera_presets和player_occlusion唯一FAIL仍为旧manifest对player_controller.gd、survivor_animator.gd的哈希断言。此处如实保留，不算通过。旧报告和旧结果未覆盖，本轮新日志均使用stage6b1前缀。

PowerShell runner语法检查、Godot导入/启动均通过。可重跑：`powershell -ExecutionPolicy Bypass -File tests/run_stage6b1_tests.ps1 -Render -Benchmark -Regression`。`python tests/audit_stage6b1.py`检查原文件保全、核心哈希、43张1440×1000非空帧及真实渲染事务结果。测试产物使用tests/results目录（现被gitignore忽略），无需将整个隔离副本提交。

首次新增测试有站位/临时墙路径错误，按实际目标诊断后修正测试布置；不是更改冻结门行为。早期数据测试观察者闭包形成循环引用，在测试结束解除连接后无资源泄漏。交互初始失败日志及诊断日志保留；最终成绩以同名JSON、*_final.log及明确的最终regressions汇总为准。

### 冻结核心SHA256

20个既有visibility脚本均未改；完整前后值见final_audit，表中为开始值，结束完全相同：

|脚本|开始SHA256|结束|
|---|---|---|
|adjacent_region_permissions.gd|`d889efd41403fb7a782b8a97cbaf9e772e436e590526355eb5462b3cceeb98f9`|一致|
|cached_presentation_coordinator.gd|`8135b9e991c8080ee770d657891a1734aee36977ec07661d611e8b48c971b09a`|一致|
|camera_occlusion.gd|`a5f6b299f0c96cfde4583f8d67f5cf7f0b6286968bc266d00b2e2ced067799f9`|一致|
|e1_portal_adapter.gd|`159eefb3ad0c7dad78f7f2a98e5c75e10a14ec0fa8e3ed8dfbc762cacca96579`|一致|
|floor5_information_config.gd|`11cac72bbff77ba8dd17c17773f9438fc56ef9312273b204c1c49d05307474fa`|一致|
|floor5_visibility_config.gd|`fe6a81e96a4bb1ac6b8efbe5f77024cdac92ba671626743ada8b0ae65abcc4c0`|一致|
|floor_extension_config.gd|`754b5ff0d8261c6869f8fe400481b4cb95b84bc35e95c6dd32331558e89285f4`|一致|
|information_camera_occlusion.gd|`669f408124a332068f20b86dc1970b3beb37804f16a37ffe9cebc024ce084b80`|一致|
|information_coordinator.gd|`ca157d304f6d30e2412508b801cb6c0e584a99fb139a226c1aeceeb2226f4a76`|一致|
|information_portals.gd|`905f05bd4849f38ef3819d493fa6a134a0f620593874f81f19fdc6b0f46c672a`|一致|
|information_portal_adapter.gd|`705ef7f0c66cd834fd1709e57303aa77e1c55fd5dd1c5158727198bffb244c2c`|一致|
|information_zones.gd|`bf8a0819dd77474083881773af2ff14045dd54d2e4017e0e1e9a8f36191a5056`|一致|
|portal_visibility.gd|`67cf37cfa8a4677ad9fc4a26ce315999e6aa1882fe75da9f01209cf6ded58c52`|一致|
|region_presentation_config.gd|`551c751d4326b45b686c08d2008de2b3ade876a900a236988a60b8bcc7613253`|一致|
|region_presentation_coordinator.gd|`ae3eb000c7092969fcf4431f0a01c31c1f635d6db8927c09729e8c63918bdad8`|一致|
|stable_structure_config.gd|`560d5fc23884fb8fa82e2e2cc12f414c7a335bf031562225b4be0b18c7bb9971`|一致|
|stable_visibility_coordinator.gd|`c2a2439a8c2508e37e64af30f26fe3f7e1e787a8a1adac8618b9df2a688ecb21`|一致|
|visibility_coordinator.gd|`3498c939a55cf56c24b0af248fefe6bcb7b49b9a82cfbcefae8aea7cc904bdc6`|一致|
|visibility_zone.gd|`a3492d7fc18a8397d7c71b9081e5cd4ac294fe193ef76651d46dad5cda32ad33`|一致|
|visibility_zones.gd|`cbb30fc55aab9c1762a620f4de0d7c0860de509fddbdbc52bfa74234d0f1f815`|一致|

## 9. 真实渲染与性能

已实际使用RTX4060 Laptop GPU、Forward+ Vulkan渲染43帧：10位置×F1/F2/F5/F6，以及F6满包拒绝/领取成功/重复空箱。捕获事务额外断言结果依次为capacity、成功实际4份、empty。不是只保存headless截图或只检查Mesh.visible；已查看真实楼道、四楼/三楼箱体及交互结果汇总。

![B.1真实帧汇总](E:/GameProject/PostApocalyptic3DTest/screenshots/stage6b1/contact.png)

配对基准复用B采样：1440×1000，size9.2，同四个位置/视角、门初始状态和渲染参数，前台、禁VSync；每点预热80帧、采样240帧。before为原6-A.3-B，after为正常B.1（诊断面板显示），顺序运行、没有并行Godot测试。新增UI本身是本轮渲染负担，未在主结果中隐藏。

|位置|FPS B→B.1|平均帧ms|P95 ms|Draw Calls|Coordinator µs|CameraOcclusion µs|B.1交互µs|
|---|---|---|---|---|---|---|---|
|apartment|223.769 → 205.943|4.469 → 4.856|7.935 → 8.110|661.000 → 675.000|2555.429 → 2710.379|172.196 → 191.142|60.37|
|hall|256.758 → 258.602|3.895 → 3.867|6.233 → 6.614|421.808 → 438.517|2015.846 → 2057.088|206.904 → 210.450|72.64|
|turn|355.691 → 439.682|2.811 → 2.274|5.267 → 3.175|245.100 → 263.733|1296.862 → 1056.829|193.412 → 174.242|24.60|
|fourth|313.158 → 331.899|3.193 → 3.013|5.018 → 4.921|329.692 → 352.279|1692.304 → 1624.721|151.029 → 157.537|60.75|

首轮触发楼道平均帧+15.7%，因此保留原始数据并增加一次配对和关闭诊断面板的定位采样；不能单凭高FPS通过：

|位置|首轮平均帧增幅|复测平均帧增幅|复测Coordinator增幅|
|---|---|---|---|
|apartment|+14.5%|+8.7%|+6.1%|
|hall|+15.7%|-0.7%|+2.0%|
|turn|+3.9%|-19.1%|-18.5%|
|fourth|-8.1%|-5.6%|-4.0%|

可确认的成本：501中诊断面板增加约14个Draw Calls；UI关闭诊断轮恢复到该点原661 Draw Calls。交互扫描固定注册Endpoint候选，约25～73µs/帧，没有遍历整个场景/全楼层查找物品，也不重新生成货架目录。容器通常仅当前高度的一个进入缓存决策；其GameInformation LOS增加少量查询。物品清单仅库存变更时刷新，模型不每帧发通知。

UI关闭诊断轮中501平均帧从约4.856降到3.967ms、楼道3.867降到3.518ms；另两点并未同步变快，表明采样仍有调度/遮挡状态波动，不能把全部差值都归因于UI。首轮+15.7%未在复测持续出现；这是一项已分析的短时性能波动和新增UI成本，不宣称性能提升、零成本或已获得长期稳定性保证。B.2替换诊断面板时应重新基准，并关注动态交互/边界切换P95。

原始数据：stage6b1_perf_before/after.json，首轮*_initial.json，诊断stage6b1_perf_after_no_debug.json。关闭UI数据只用于分析，不替代正常配置after值。相机检测仍沿用冻结state更新方式，本轮未优化或改变其算法。

## 10. 已知限制与人工验收风险

- **人工验收已由玩家于2026-11-17确认PASS。** 以下清单保留为后续回归风险；自动脚本调用仍不能替代真实输入和自由移动体验，不补写未提供的逐项人工操作记录。
- 箱体是小型占位物，没有独立物品图标、物品世界模型、打开盖动画或高亮；空/非空色差与墙边可读性仍需四视角人工确认。箱体碰撞可能在未覆盖的斜向擦边站位影响通行。
- 本轮仅会话数据，不存档。没有正式背包/装备栏、武器攻击、治疗、饥饿口渴或僵尸。逻辑武器仅物品Stack，左键不新增攻击。
- 调试面板能凭空填充武器占槽、清空玩家库存，只用于验证，明确不改变容器。清空不会把已领物品退回容器。不得把它作为正式游戏背包/经济流程；B.2可整块移除。
- E采用全量领取，满包时可能因其中一类放不下而全部拒绝，这是设计行为。空槽为零不等于所有物品容量均零，已有同类堆叠仍可能接收。
- 数据读取API返回副本，调用者需走模型方法修改；内部下划线字段是实现细节，GDScript并非强封装语言，不支持外部任意写内部字段后仍保证不变量。
- 缓存目前只支持本轮静态注册/固定区域对象；B.2以后若生成掉落物或跨区动态物品，应另审注册/失效接口，不能偷偷改冻结核心。
- 两轮性能仍是短时样本，不能代替至少两分钟实际连续探索；未对所有机器/缩放/站位保证无显示异常。

## 11. 人工验收步骤

双击RunStage6B1.bat。WASD、E、F1/F2/F5/F6、缩放/原调试键沿用。先看当前E提示，门与容器竞争时门优先。

1. 在501确认初始0/12槽，物品无效果/战斗；开门出屋，退开门扇再关门，确认提示与实际门一致；卫生间门开关一次。
2. **领取前测满包**：点击“B.1测试：填满空槽”，走到五楼箱按E，应提示容量不足。点“清空玩家库存”，再次E，应恰好得到瓶装水2、绷带2，证明拒绝时箱内物资未丢。
3. 再按E，提示空，不增加数量。原路走到四楼左侧平台箱，领取电池3、罐头2；期间在上层同XZ尝试E不能领取楼下物品。
4. 走到三楼左侧箱，领取短刀1、棒球棍1；两种武器各占一槽，最终共6槽，左键不产生本轮新增攻击。
5. 各箱重复E，沿楼梯返回四楼/五楼，再到501。三箱应保持空，库存不变。R不是本局重置，需重新启动入口才能恢复初始容器。
6. 对着墙、超出范围、楼层相同XZ反复按E；不得有隔墙/隔层领取或未知物资提示。
7. F1/F2/F5/F6重复靠近、领取/空箱查看和完整上下楼；检查地面、墙、箱体、人物及色变。保持连续探索至少两分钟，特别检查门边E目标竞争、开着调试UI时键鼠输入。

跳过会遗漏门前目标误读、箱体擦碰、低视角遮挡、UI焦点吞键和跨层提示闪烁，未来复制容器时可能放大。请提供具体楼层、视角、站位和显示提示；本次整体人工验收现已获玩家确认PASS，清单继续用于后续回归。

## 12. B.2接口建议与提交边界

B.2正式背包仅订阅InventoryModel.changed并读取snapshot/get_stack/count/capacity，不从HUD文本读取数据，不直接写_slots。装备应通过独立模型/接收规则处理类型限制及原子移动，先保留transfer_to的同类库存事务契约；不要把equipped放进ItemDefinition。若确实需要耐久或装备唯一实例，再新增ItemInstance/instance_id与迁移规则，本轮不预造无意义UUID。

正式UI可替换inventory_debug_panel，数据模型/容器/broker继续使用；拖放和装备操作应返回同样明确的成功/失败/实际数量。未来从旧便利店迁移water→water_bottle应有显式Adapter映射，不能混用两套ID。

目前历史A系列与B仍未提交，B.1依赖它们。后续安全提交顺序应先按B.0审查清单核对历史运行基础与A.4/B验收基线，再单独审核B.1数据Resource/模型、交互/场景装配、测试/报告与选定证据。逐路径暂存并检查cached diff；tests/results被忽略，若要保存证据仅明确收录具体文件，排除隔离副本/.godot/build。此处只是建议，本轮没有暂存/提交/推送。

B.1人工验收已于2026-11-17由玩家确认PASS；后续按新阶段明确授权推进，不改写本报告中的历史测试成绩。
