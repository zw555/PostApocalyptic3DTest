# Stage 6-A.3-B：楼层扩展与配置复用验证

状态：实现及自动验证完成；**人工验收 PASS**。玩家于 **2026-11-17** 明确确认 Stage 6-A.3-B 人工验收通过。此状态依据玩家确认更新，不改写历史自动测试日志。日期：2026-11-17。Godot 4.5.2 stable。A.4 人工验收通过是本轮前提；保留 A.4 独立入口，不改变默认项目入口。

## 1. 只读审查及范围判断

审查时 Git HEAD：`e36215ec8006291864632d4bf755aeaa1c8b2127`。起始 tracked/staged diff 为空，但 Stage6-A.3 历史入口、报告、场景、楼梯及 visibility 脚本、测试和截图存在大量未跟踪内容。完整起始清单、Git status 和1780个已有文件SHA256保存在 `tests/results/stage6a3b_initial_audit.json`，不能称工作区干净。

实际 A.4 入口为 RunStage6A3A4.bat → stage6a3a4_presentation.tscn → stairwell_presentation_main → stable_main → information_main → configured_main → stairwell_main。旧 StairBuilder 在 _enter_tree 中构造五至四楼，_ready 注册可见性。旧布局固定五楼门户XZ、3米层高、五/四楼ID及三个标牌；choose_door和HUD仍依赖五楼门与四楼终点。本轮保留它们，B仅修正新增入口的提示，不更改门状态机。

VisibilityZone 的 AABB 和高度、邻接权限、相机query代理与Presentation均可通过现有接口扩展。无需大规模重构可见性算法。采用最小装配抽取：新配置化连接调用旧 builder 的 platform/flight/rail/wall/sign_at；新增配置适配器注册区域、对象和相机代理。Presentation原背景规则保持原样。

最初未经缓存的方案仍对全部注册对象逐帧决策；四个样本Coordinator约3.219/3.335/3.687/3.626ms，记录于 stage6a3b_perf_after_uncached.json（诊断轮，与最终无干扰配对轮不混作严格比例比较）。因此添加独立通用缓存适配器，继承A.4并继续调用原决策与commit，而没有改写冻结文件。

本轮只增加四至三楼两跑楼梯、转角、三楼最小终点平台和封闭边界。没有三楼住宅、完整楼道、家具、敌人、搜刮、任务或其他楼层。

## 2. 修改文件清单

全部为新增文件；历史文件内容未改动：

- `RunStage6A3B.bat`
- `STAGE_6A3B_FLOOR_EXTENSION_REPORT.md`
- `scenes/apartment/stage6a3b_floor_extension.tscn`
- `scripts/apartment/configurable_stair_connection.gd`
- `scripts/apartment/floor_extension_main.gd`
- `scripts/visibility/cached_presentation_coordinator.gd`
- `scripts/visibility/floor_extension_config.gd`
- `tests/audit_stage6a3b.py`
- `tests/benchmark_stage6a3b.gd`
- `tests/capture_stage6a3b.gd`
- `tests/fixtures/floor_extension_regression.gd`
- `tests/fixtures/floor_extension_regression.tscn`
- `tests/fixtures/floor_extension_variant.gd`
- `tests/fixtures/floor_extension_variant.tscn`
- `tests/run_stage6a3b_tests.ps1`
- `tests/validate_stage6a3b_configuration.gd`
- `tests/validate_stage6a3b_existing.gd`
- `tests/validate_stage6a3b_journey.gd`
- `tests/validate_stage6a3b_presentation.gd`

Godot同时生成这些新脚本的 `.uid`。实际截图位于 `screenshots/stage6a3b/after/`（40张）与 `contact.png`；原始JSON、日志、起始审计、保全记录及隔离回归副本位于 `tests/results/stage6a3b*` 和 `validate_stage6a3b*_final.log`。results被现有.gitignore忽略；它们是本地交付证据，提交时须有选择地显式收录，不能提交整个隔离副本。

## 3. 楼层与区域配置

五楼脚底Y=0，四楼=-3，新增三楼=-6（单位米，Apartment当前未旋转）。四至三楼连接根位于旧楼梯 `(center, four_y, front)`，通过Apartment变换转为世界坐标；朝向Basis.IDENTITY。横向宽度沿用旧预留宽度；两跑宽1.35m、中央间隙0.20m、每跑12级×0.28m、平台深1.40m、板厚0.16m。旧四楼平台共享，不叠加第二张起始楼板。Y通过原CharacterBody3D.step_motion、坡面碰撞和重力改变；生产装配无传送或玩家Y赋值。

模块参数为id、start_floor、target_floor、height、width、transform、shared_start、四个region_ids。start/target只用于标识；高度不从楼层号推导。方向使用Transform3D的水平旋转，支持平移和不同层高；当前范围不承诺倾斜楼层或运行时改变注册几何。

|新区域ID|连接本地XZ|本地Y范围|世界脚底高程|
|---|---|---|---|
|stairs_f04_mid|东跑，z=1.4～4.76|[-1.85,0.30)|-3 → -4.5|
|stairs_turn_04_03|全宽，z=4.76～6.16|[-1.85,0.30)|-4.5|
|stairs_mid_f03|西跑，z=1.4～4.76|[-3.35,-1.20)|-4.5 → -6|
|stairs_landing_f03|全宽，z=0～1.4|[-3.35,-0.35)|-6|

区域bounds来自 Connection.definitions，注册后继承连接世界变换，含0.06m空间容差、0.10s归属稳定时间及活动空间采样点。通过 add_zone、register_object、neighbors、open_connections、occluders 及原 configure_presentation 注册。楼梯本身是无门连通体，沿用A.4的整楼梯内容权限；水平支撑面/内容再按已配置高程收口。它不授予三楼不存在的住宅权限，也不绕过五楼门授权。

新增墙体为BuildingStructure，坡面和平台为StructureSurface，细节/护栏/标牌为ZoneInterior；真实静态碰撞保持启用，query代理使用原遮挡层。新连接所有细节有相对高度区间；背景继续使用真实支撑面的footprint、原有深色材质、跨层收口，不添加全局灰色平面。旧501、卫生间、楼道、楼梯门连接不变。

配置复用验证使用独立测试连接：楼层标识19→18、区域variant_alpha/rho/sigma/tau/omega、世界位置(24,-12,7)、水平旋转0.61rad、层高2.4m、宽3.5m、非共享起始平台。实际碰撞下到-14.4m再返回-12m通过；没有四至三楼专用几何脚本。

## 4. 核心哈希与缓存边界

以下是本轮开始值；结束值逐字节一致（完整before/after见 stage6a3b_preservation.json）：

|既有可见性脚本|开始SHA256|结束对照|
|---|---|---|
|adjacent_region_permissions.gd|`d889efd41403fb7a782b8a97cbaf9e772e436e590526355eb5462b3cceeb98f9`|一致|
|camera_occlusion.gd|`a5f6b299f0c96cfde4583f8d67f5cf7f0b6286968bc266d00b2e2ced067799f9`|一致|
|e1_portal_adapter.gd|`159eefb3ad0c7dad78f7f2a98e5c75e10a14ec0fa8e3ed8dfbc762cacca96579`|一致|
|floor5_information_config.gd|`11cac72bbff77ba8dd17c17773f9438fc56ef9312273b204c1c49d05307474fa`|一致|
|floor5_visibility_config.gd|`fe6a81e96a4bb1ac6b8efbe5f77024cdac92ba671626743ada8b0ae65abcc4c0`|一致|
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

还对1780个既有文件复核：changed_original_files=[]。玩家移动/攻击/战斗、相机参数、E.1算法、501布局/家具、旧门代码及A.4入口均保全。无if floor==3、三楼ID或三楼固定坐标进入可见性核心。

cached_presentation_coordinator 是新增候选适配层：初始化缓存记录及所有配置高度边界；以当前区域、权限集合和高度区间为键，缓存候选字典。稳定帧不 find_children、不扫描全场景对象、不遍历全部records筛选。切换键时先用完整A.4提交撤销旧结果，再构造/复用候选集；每帧仍由A.4唯一commit写最终状态。inactive_decisions保留完整诊断信息。

旧 floor5_main.update_cutaway 还会重写其target/dependent阴影，所以这些已有对象强制保留候选，避免缓存留下错误状态。初次缓存等价测试因此失败，修正后的28组逐对象 visible/cast/transparency/material对照全部一致；初始失败JSON/log保留。

必须区分：Coordinator稳态不再对所有注册Mesh做决策，但区域注册表仍遍历少量区域，CameraOcclusion仍对全部已注册遮挡state做计时/渐变更新（不做全场景树查询）。新增层没有移除这个旧成本；未来大量楼层的CameraOcclusion候选化仍需另立阶段，不能据本轮宣称无限楼层扩展已验证。缓存只支持静态注册配置；动态增删对象需重新初始化。

## 5. 自动化测试

|专项|通过|失败|
|---|---|---|
|B完整通行、转角、反向、护栏、区域、权限及头部遮挡射线|75|0|
|不同ID/位置/旋转/高度真实通行 + 缓存与完整A.4策略对照|31|0|
|B场景原501/卫生间/门/内容与信息权限|53|0|
|B场景原A.4背景表现|26|0|

五→四→三→四→五，在F1/F2/F5/F6重复；途中停走并反走转角，真实E打开501与楼梯门。7028个运动采样中离地0；最大Y单步0.022475m，最大相机focus单步0.052837m。新坡面停止无滑落，中央护栏阻止跨越，三楼封闭前边界阻止进入未建区域。采样覆盖新旧全部9个楼梯区域ID；同XZ不同高度有不同归属。三楼时五楼私有内容权重为0，五楼时新增低层Mesh不可见，四视角三楼头部射线无可见实心阻挡。固定采样不能证明每个任意站位都没有遮挡。

既有回归在隔离副本执行，避免旧测试覆盖历史结果：

|原测试套件|PASS行|FAIL行|退出码|
|---|---|---|---|
|validate_stage6a3a4_presentation|26|0|0|
|validate_stage6a3a4|53|0|0|
|validate_stage6a3a4_journey|60|0|0|
|validate_stage6a3a3|53|0|0|
|validate_stage6a3a3_structure|10|0|0|
|validate_stage6a3a3_permissions|10|0|0|
|validate_stage6a3a2|57|0|0|
|validate_stage6a3a1|40|0|0|
|validate_stage6a2c|111|0|0|
|validate_stage6a1c|84|0|0|
|validate_camera_zoom|20|0|0|
|validate_stage5c3b|41|0|0|
|validate_camera_presets|49|1|1|
|validate_player_occlusion|49|1|1|

**两项历史冻结失败真实保留**：camera_presets 49/50、player_occlusion 49/50；各唯一失败仍是旧manifest对 scripts/player_controller.gd 与 scripts/survivor_animator.gd 的哈希冻结断言。未修改manifest、旧断言或旧脚本，不把它们算作通过。

隔离副本首轮漏拷data，另一次Stage6A1C副本缺少manifest所列根文件/旧截图，引发非产品错误；补齐资源后上述最终回归通过。错误过程日志以_initial、_incomplete_mirror保留，最终汇总以 stage6a3b_regressions.json 为准。

可重跑：`powershell -ExecutionPolicy Bypass -File tests/run_stage6a3b_tests.ps1 -Render -Benchmark -Regression`。专项runner保留独立的既有core运行前后哈希检查。`python tests/audit_stage6a3b.py`核验初始文件、通行区域和40张真实帧尺寸/非空内容；图片基础检查不是视觉验收。

## 6. 真实渲染与性能

原生Forward+ / Vulkan，RTX4060 Laptop GPU，1440×1000，camera size9.2。固定玩家位置、相机模式、门初始状态、光照和渲染配置；前台窗口，独立基准关闭VSync。每点预热80帧、采样240帧。最终before/after顺序运行，期间没有并行Godot测试；没有把截图HUD或headless FPS混入统计。

|位置|FPS A.4→B|平均帧ms|P95 ms|Draw Calls|Coordinator µs|CameraOcclusion µs|
|---|---|---|---|---|---|---|
|501 / F6|210.637 → 247.692|4.748 → 4.037|7.499 → 6.168|661.000 → 661.000|2905.646 → 2396.442|164.683 → 158.308|
|五楼公共楼道 / F6|222.377 → 301.452|4.497 → 3.317|7.674 → 5.609|419.075 → 426.658|2886.796 → 1827.662|208.258 → 199.154|
|五楼楼梯转角 / F6|251.137 → 413.502|3.982 → 2.418|5.035 → 3.307|235.850 → 246.317|2756.121 → 1122.271|153.346 → 190.892|
|四楼平台 / F2|226.561 → 317.227|4.414 → 3.152|7.631 → 4.925|181.708 → 333.762|3025.733 → 1684.487|148.213 → 149.162|

- apartment：平均帧 -15.0%；Coordinator -17.5%。
- hall：平均帧 -26.2%；Coordinator -36.7%。
- turn：平均帧 -39.3%；Coordinator -59.3%。
- fourth：平均帧 -28.6%；Coordinator -44.3%。

平均帧和Coordinator均未触发+15%门槛；这不代表新增几何零成本。四楼Draw Calls明显增加（约182→334），来自允许看到的新下行楼梯与支撑面。转角CameraOcclusion约153→191µs，上升约24%，与新增query代理/命中及state更新有关；绝对值约0.038ms，仍须如实保留。既有位置的Draw Calls小幅变化也包含遮挡时间采样差异；不得把旧版/新版短时均值当作长期保证。

原始数据：stage6a3b_perf_before.json、stage6a3b_perf_after.json；早期未缓存轮 stage6a3b_perf_after_uncached.json用于原因分析。缓存改善了CPU决策成本，未改变底层渲染质量/分辨率/相机参数来换取FPS。

40张真实帧覆盖501开关门、楼道开关门、卫生间门口、楼梯入口、五/四楼平台、新转角、三楼平台，各F1/F2/F5/F6。完整镜头、位置、门状态与区域见stage6a3b_capture_after.json。

![最终四楼、新转角、三楼四视角](screenshots/stage6a3b/contact.png)

## 7. 已知问题与人工验收

- 本阶段人工验收已由玩家于2026-11-17确认PASS；自动结果本身仍不能替代人工验收。以下空间阅读、动态遮挡项目保留为后续回归风险，不表示本次仍待验收。
- 延用A.4无门楼梯连通体与高程背景表现，不恢复逐片元裁剪或严格门洞视锥。没有完整三楼建筑，不能声称三楼住宅内容权限已实景验收；新增私有内容将必须单独注册权限。
- 高度边界/权限改变时有一次完整提交和候选重建，稳态性能不能代表边界瞬时最坏值；最终P95为固定站位数据，动态两分钟探索是原人工验收要求；本次整体人工验收已获玩家确认，不补写未提供的逐项计时记录。
- 旧五至四楼装配仍有历史硬编码；它完整保留作为回归基线。新连接已配置化，但本轮没有冒险替换已验收旧连接或宣称所有旧配置已经泛化。

双击RunStage6A3B.bat，WASD移动，E开门；F1=85°、F2=65°、F5=45°、F6=斜向45°。A.4回归可另用RunStage6A3A4.bat。

1. 从501真实走出，打开楼梯门，完整走五→四→三→四→五→501，不能跳过任何转角。
2. 在两处转角、四楼共享平台停下、反向、短按再连续移动，检查卡角、穿墙、穿栏及悬空。
3. 四种视角重复；确认当前人物与活动平台不被上层墙/板遮住，护栏方向明确。
4. 观察楼层切换背景是否跳变、灰面扩散或暴露未授权内容；返回501与卫生间反复开关门。
5. 连续自由探索至少两分钟，记录具体楼层、视角与站位问题。

**人工验收 PASS：玩家于2026-11-17确认通过。** 上述清单保留为后续回归方法；不据整体通过推断未单独记录的测试细节。住宅楼可见性规则及楼梯扩展架构暂时冻结，不自动继续扩建。

## 8. Git安全与分批提交建议

无reset/clean/add、无提交或推送。结束tracked diff、cached diff为空，git diff --check通过；历史未跟踪文件仍在。完整新增清单与旧文件保全见 stage6a3b_preservation.json；不把历史文件误称本轮新增。

人工验收现已通过；建议后续分批、逐路径暂存（本轮仅提供方案）：

1. 先单独核对并保存历史A.4及其前置依赖（它们尚未提交，B依赖这些文件）；先审查原始清单，不执行git add .。
2. 再暂存B装配/main/config/cache、独立场景、入口及对应新.uid。
3. 再暂存B专项/配置夹具/runner/audit、报告和选定真实截图；单独显式收录关键stage6a3b JSON/log证据。results被忽略时只对审核过的具体文件使用git add -f，排除隔离副本与.godot缓存。
4. 每批检查git diff --cached --name-status和diff；确认历史冻结失败记录仍在后再由玩家决定提交。本轮不执行这些暂存/提交操作。
