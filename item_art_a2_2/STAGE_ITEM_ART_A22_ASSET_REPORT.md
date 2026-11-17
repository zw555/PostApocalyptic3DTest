# Stage Item-Art A2.2：四种物品建模与六物品统一预览

日期：2026-11-17。项目：`E:/GameProject/PostApocalyptic3DTest`。引擎：Godot 4.5.2。

**当前状态：等待玩家集中人工验收。短刀与棒球棍已由玩家确认通过，保持冻结。**

## 结果与范围

完成新建绷带、复用电池几何及基础材质装配、封装水瓶与罐头，以及六种物品的统一预览。全部新增内容位于 `item_art_a2_2/`，未修改任何既有文件。

本轮按批量方式装配，集中做一轮视觉自检。发现旧货架水瓶与罐头尺寸和现有 500ml／200g 标签不协调，因此仅调整新场景内的等比装配缩放。未重新设计原 Mesh，未反复微调隐藏细节。

未接入正式场景、背包、装备、战斗或存档；未修改物品定义、数量与规则。没有生成正式 PNG 图标或开发图标渲染器。报告中的 PNG 均为预览场景截图及验收拼图。

## 六种纯视觉场景

以下 `res://` 路径均相对于项目目录。场景均可直接实例化，模型本身没有运行脚本、物理碰撞、相机、光照或业务状态。

| item_id | 场景资源路径 | 尺寸 X×Y×Z（mm） | 三角面 |
|---|---|---|---:|
| combat_knife | `res://item_art_a1/combat_knife/model/combat_knife_visual.tscn` | 47.6×21.6×286 | 5,180 |
| baseball_bat | `res://item_art_a2_1/baseball_bat/model/baseball_bat_visual.tscn` | 66×66×820 | 19,840 |
| bandage | `res://item_art_a2_2/models/bandage/bandage_visual.tscn` | 70×60×70 | 768 |
| battery | `res://item_art_a2_2/models/battery/battery_visual.tscn` | 35.4×78.8×35.4 | 1,184 |
| water_bottle | `res://item_art_a2_2/models/water_bottle/water_bottle_visual.tscn` | 79.24×206.5×79.24 | 160 |
| canned_food | `res://item_art_a2_2/models/canned_food/canned_food_visual.tscn` | 65.6×94.5×65.6 | 108 |

短刀、棒球棍仅被引用，其模型、材质、脚本、独立入口及既有截图均未改变。武器原有历史 stage 元数据也保持原样；玩家确认通过的状态登记在新增预览注册表中。

## 新增与复用说明

| 物品 | 几何与来源 | 材质及处理 |
|---|---|---|
| 绷带 | 新建连续环形布卷；48 段圆周，真实贯通中孔直径 16mm；上下卷层端面、外部纱布及内芯 | 低饱和米白粗糙纱布，简洁织纹与端面卷层，哑光纸芯；1 Mesh、3 材质 |
| 电池 | 通过 `scripts/loot/store_product_visuals.gd` 的 `mesh_for("battery_0_GOOD")` 取得原程序化电池几何，数组原样保留；主体等比缩小至 0.5，补绝缘环、正极和包覆套 | 局部独立钢材、低饱和橄榄色套纸；原八边形主体不重建。作为通用大型干电池视觉原型，不宣称特定 AA/D 标准规格 |
| 水瓶 | 直接引用 `assets/localization/cn_water_0.res`；装配缩放 0.70 | 原有不透明浅蓝塑料、瓶盖和中文矿泉水包装材质，未修改源 Mesh/材质 |
| 罐头 | 直接引用 `assets/localization/cn_canned_food_0.res`；装配缩放 0.50 | 沿用中文纸包装；新场景以独立材质覆盖金属表面，metallic=0.65、roughness=0.60，未改源材质 |

电池旧工厂仅用于离线构建，不进入新模型的运行依赖链；没有复制旧搜刮、库存、世界坐标或状态逻辑。

新模型以米为单位，根节点带原有 `item_id` 元数据。新注册表 `preview/visual_catalog.gd` 只把六个稳定 ID 映射到纯视觉场景；显示名称读取既有 `data/items/<item_id>.tres`。没有写入 ItemDefinition 的 `world_visual`、icon 或任何运行状态，后续接入需要另行授权。

## 统一入口与操作

双击：`E:/GameProject/PostApocalyptic3DTest/item_art_a2_2/RunPreview.bat`。

或在 Godot 中运行：`res://item_art_a2_2/preview/item_preview.tscn`。默认显示绷带。

| 操作 | 功能 |
|---|---|
| 顶部下拉框、PgUp/PgDn 或 [ / ] | 切换全部六种物品 |
| F1 / F2 / F3 / F4 | 45° / 65° / 85° / 12°低角度 |
| 左键拖拽、A/D | 旋转观察 |
| 滚轮 | 缩放 |
| R / F | 自动旋转 / 翻面 |
| L | 游戏近似光 / 辅助检查光 |
| 1 / 2 / 3 | 适配近景 / 实际尺寸标尺 / 游戏视野 size 9.2 |
| Space | 复位当前物品观察状态 |

预览继承冻结的棒球棍预览类，继续复用短刀工具的相机、输入、光照与标尺构建能力；扩展仅包括模型切换、立式物品居中、自适应标尺、小物品缩放范围和说明文字。旧入口不受影响。

标尺按实际尺寸选择 10～100cm 跨度，数字单位为 cm；游戏尺寸模式显示 1.75m 高度参照。光照沿用住宅近似环境色和主光，并提供原辅助检视光。近景截图对每个模型分别适配取景，不能用近景拼图比较实际物品大小。

## 截图与验证

- [六种物品近景总览](evidence/six_items_review.png)：65°，每件分别适配取景。
- [四种物品三角度总览](evidence/four_items_three_angles.png)：45°、65°、85°。
- [六种物品游戏尺寸总览](evidence/game_size_review.png)：统一 9.2 视野，各原始截图采用相同缩小比例排版。
- 原始截图：`evidence/<item_id>_45.png`、`_65.png`、`_85.png`、`_game.png`、`_low.png`，每件 5 张，共 30 张，原始分辨率 1440×1000。

执行 Godot headless 检查与 NVIDIA RTX 4060 Laptop / Vulkan Forward+ 真实渲染。最终构建、验证和渲染日志无脚本或 Shader 错误。

| 验证 | 结果 |
|---|---|
| 模型和统一预览自动检查 | **103 PASS / 0 FAIL** |
| 保存性、截图及 Git 只读核对 | **10 PASS / 0 FAIL** |
| 独立模型可加载、ID/定义匹配、尺寸合理 | PASS |
| 顶点/法线/UV 有效，面不退化，面朝向正确 | PASS |
| 绷带真实中孔及周围卷体射线验证 | PASS |
| 电池与旧工厂几何数组一致 | PASS |
| 水瓶、罐头直接引用源 Mesh | PASS |
| 六物品切换、四角度、旋转、缩放、光照、标尺、9.2 视野 | PASS |
| 30 张 GPU 截图 | PASS |

结果文件：`evidence/validation.json`、`preservation.json`、`provenance.json`、`captures.json`。复验可运行 `tests/run_checks.ps1`；带 `-Capture` 时重新采集实渲染截图。没有运行会覆盖旧阶段证据的历史测试，也没有修改任何旧断言。

## 正常游戏尺寸的实际限制

在 1440×1000、65°、size=9.2 的独立预览中，按模型顶点投影测得：

| 物品 | 屏幕包围范围（约，像素） |
|---|---|
| 短刀 | 5.2×28.2 |
| 棒球棍 | 10.6×81.7 |
| 绷带 | 7.6×9.5 |
| 电池 | 3.8×6.9 |
| 水瓶 | 8.6×14.9 |
| 罐头 | 7.1×10.5 |

因此，小物品的纹理和标签在正常远景下无法阅读，单靠模型难以可靠区分全部物品。该项**仍需人工验收，不标为视觉 PASS**。模型维持真实尺寸，未增加特殊发光或高亮补丁。正式玩法中的辨识通常还需要交互提示/高亮辅助，本阶段没有接入这些系统。

水瓶与罐头保留原八边形轮廓，近看可见分面；罐头拉片仍为旧模型的简洁几何。水瓶采用原不透明塑料表现，没有液面或折射。绷带采用简洁织纹和卷层，没有自由布条模拟。它们是本轮控制成本的明确限制，不影响资源独立加载；是否符合最终美术期望由玩家集中确认。

本轮没有进行正式关卡中的遮挡、拾取或装备测试，未宣称游戏集成完成。

## Git 与文件清单

分支 `main`，HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127`。实施前已有大量历史 untracked 文件；tracked/staged diff 均为空。初始完整状态与哈希记录在 `evidence/initial_audit.json`。

现有 **2,180 个文件全部哈希不变**，包括短刀与棒球棍目录的 **181 个文件**。未暂存、提交、推送、reset、clean 或清理未跟踪文件。

新增范围：

- `models/bandage/`：纯视觉场景、环形 Mesh、纱布 Shader、三种材质。
- `models/battery/`：纯视觉场景、原几何保存资源、套纸 Shader 与三种基础材质。
- `models/water_bottle/water_bottle_visual.tscn`：原水瓶 Mesh 的纯视觉装配。
- `models/canned_food/`：原罐头 Mesh 的纯视觉装配及金属覆盖材质。
- `preview/visual_catalog.gd`、`item_preview.gd`、`item_preview.tscn`：统一预览。
- `tools/build_items.gd`：批量离线装配工具，仅写本阶段目录。
- `tests/validate_items.gd`、`capture_items.gd`、`audit_assets.py`、`run_checks.ps1`。
- `RunPreview.bat`、本报告、`evidence/` 内的快照、日志、JSON、原始截图和验收拼图。

逐文件新增清单见 `evidence/file_manifest.json`；既有文件修改清单为空。

## 集中人工验收

1. 从统一入口切换六种物品，核对短刀、棒球棍与已验收版本一致。
2. 检查新四种物品的 45°、65°、85°，确认主要结构、比例和颜色能够接受。
3. 旋转、翻面并切换辅助光，检查破面、接缝、异常弯曲和穿插；绷带确认中孔，电池确认正极与外壳。
4. 按 2 核对物理尺寸，再按 3 查看真实游戏尺寸；重点决定小物品辨识度限制是否可以接受。
5. 快速切换物品并缩放、旋转，确认没有残留上一件模型或错误提示。

自动检查不能替代上述视觉判断。本阶段到此停止，等待玩家一次性确认六种物品集中验收结果；不推进图标、背包 UI 或装备/战斗接入。
