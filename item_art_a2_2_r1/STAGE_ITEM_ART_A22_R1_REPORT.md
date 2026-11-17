# Stage Item-Art A2.2-R1：三种物品局部修订

日期：2026-11-17。Godot：4.5.2。状态：**等待玩家人工验收**。

项目目录：`E:/GameProject/PostApocalyptic3DTest`。

## 修订结果

| 物品 | 实施内容 | 实际尺寸 X×Y×Z（mm） | 三角面 |
|---|---|---|---:|
| canned_food | 32 段罐身与圆形盖；金属卷边；带贯通孔的椭圆易拉环及铆接支点；独立牛肉中文包装 | 65.6×93.6×65.6 | 1,504 |
| water_bottle | 瓶身、瓶肩、瓶颈、蓝盖均为 32 段；保留原材质和中文标签；标签 UV 按新截面重建并正面居中 | 79.24×206.5×79.24 | 640 |
| battery | 32 段圆柱主体；原深绿色套纸和钢材；凸起正极触点带 +，平面负极触点带 − | 35.4×79.29×35.4 | 932 |

罐头外径保持不变，新盖及拉环使总高度比旧版减少 0.9mm；电池的薄表面标记及负极接触片使总高增加约 0.49mm。水瓶总高度和最大外径保持不变，瓶身在原外包络内贴合标签，去除旧八边形包装与主体之间的间隙。没有修改 item_id、物品数据或玩法规则。

拉环外轮廓为约 15×26mm 的椭圆，内孔约 8.4×17.2mm，厚 1.2mm；下表面高于盖面约 2.2mm。孔内能看到下方罐盖，并非用暗色贴图模拟孔洞。正负极标识为固定在触点表面的薄标记几何，脱离预览 UI 仍会显示。

短刀、棒球棍及绷带使用原资源，完全未改。绷带在 R1 预览中标记为“当前可接受，暂时冻结”。

## 独立资源与共享保护

审查确认 `assets/localization/chinese_packaging.png` 与同名材质由水、饮料、桶面和罐头的既有中文商品 Mesh 共用。旧构建脚本 `scripts/localization/build_products.gd` 使用这一图集构建四类、各五种商品变体，因此本轮没有覆盖图集、原 Mesh、材质或旧工厂。

三种旧 Mesh 已烘焙成资源，不能直接设置其圆周分段属性。本轮在独立目录按原尺寸参数装配 32 段原生圆柱及新标签 Mesh，原 A2.2 场景继续保留为对照基线。

牛肉包装使用新增的 `models/canned_food/beef_label.png`、`beef_label_texture.res` 与 `beef_packaging.tres`。贴图为 1024×272 的独立包装展开图：名称“牛肉罐头”、两块带脂肪纹理的简洁牛肉图案，以及低饱和中文食品信息；没有沿用豆子图案。整个罐身映射一张完整展开图，主名称只绘制一次，接缝在背面。

PNG 是本次授权的**包装材质贴图**，不是背包图标。运行材质引用已保存的 Texture2D `.res`，不要求运行时生成贴图或启动任何图标工具。水瓶仍引用原水包装图集区域和原蓝盖材质，保留旧包装四面板排布，没有重新设计包装。

## 新模型与入口

资源路径：

- `res://item_art_a2_2_r1/models/canned_food/canned_food_visual.tscn`
- `res://item_art_a2_2_r1/models/water_bottle/water_bottle_visual.tscn`
- `res://item_art_a2_2_r1/models/battery/battery_visual.tscn`

**请使用本次新增入口**：`E:/GameProject/PostApocalyptic3DTest/item_art_a2_2_r1/RunPreview.bat`。

Godot 场景入口：`res://item_art_a2_2_r1/preview/revision_preview.tscn`，默认显示牛肉罐头。它继承原统一预览，仅替换这三个物品的资源路径；其余三个仍指向冻结资源。旧 A2.2 入口与旧截图保留为历史基线。

操作沿用：下拉框或 PgUp/PgDn 切换；F1/F2/F3/F4 为 45°/65°/85°/12°；A/D 或拖动旋转；滚轮缩放；F 翻面检查负极；L 切换光照；1/2/3 为近景、标尺、9.2 游戏视野；Space 复位。

厘米级金属平面在旧预览阴影偏移下出现自阴影斜纹。本轮只在新 R1 预览中设置 shadow_bias=0.15、shadow_normal_bias=0.6，消除这一预览伪影；主光方向、颜色、能量、环境色及正式游戏设置未改。所有前后对照均使用相同的新预览阴影设置。

## 截图

- [三种修订模型总览](evidence/revised_models.png)
- [45°、65°、85°截图](evidence/three_angles.png)
- [罐头拉环、包装正面、电池两极特写拼图](evidence/revision_details.png)
- [正常游戏视野前后对照](evidence/game_before_after.png)：左修订前，右修订后。

原始全帧特写：

- [罐头顶部拉环](evidence/after/can_top_detail.png)
- [牛肉罐头中文正面](evidence/after/can_front_detail.png)
- [电池正极](evidence/after/battery_positive_detail.png)
- [电池负极](evidence/after/battery_negative_detail.png)

原始截图位于 `evidence/before/` 和 `evidence/after/`，每组 16 张，共 32 张，分辨率 1440×1000。前后固定同一旧模型基准坐标、相机、角度、缩放与光照；UI 尺寸显示各模型实际尺寸。`evidence/captures.json` 保存机位信息，16 对参数逐项一致。

近景拼图分别适配模型取景，不能用它比较不同物品的物理大小。游戏视野对照均为相同 9.2 正交尺寸，以相同比例排版。

## 自动验证

| 项目 | 结果 |
|---|---|
| headless 资源、几何、材质、UV、结构及预览检查 | **51 PASS / 0 FAIL** |
| 哈希、共享资源、Git、机位与截图保存性检查 | **10 PASS / 0 FAIL** |
| 三种圆柱主体、瓶盖等截面分段 | 32 |
| 顶点/法线/UV 有效，三角面不退化，面朝向正确 | PASS |
| 拉环真实空孔、实体环边及离盖距离 | PASS |
| 罐头单圈连续 UV；水标签位于原图集区域且正面居中 | PASS |
| 两极标记存在于模型内 | PASS |
| 冻结三物品仍解析到原资源 | PASS |
| GPU 实渲染（RTX 4060 Laptop / Vulkan Forward+） | 32 张完成，最终日志无脚本/Shader 错误 |

验证结果：`evidence/validation.json`、`preservation.json`。未修改旧测试断言，也未覆盖历史测试证据。

复验命令（在项目根目录执行）：

```powershell
& 'E:/Godot_v4.5.2-stable_win64.exe/Godot_v4.5.2-stable_win64_console.exe' --headless --path . --script res://item_art_a2_2_r1/tests/validate_revisions.gd
python item_art_a2_2_r1/tests/audit_revision.py
```

## 文件与 Git

初始分支 `main`，HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127`。历史未提交文件全部保留；tracked/staged diff 为空，HEAD 不变。未执行暂存、提交、推送、reset、clean 或未跟踪文件清理。

**2,285 个既有文件哈希全部不变**，其中包含短刀、棒球棍、绷带的 188 个冻结文件。原共享包装与源 Mesh 也未改变。仅新增 `item_art_a2_2_r1/`：

- `models/canned_food/`：新场景、圆标签 Mesh、椭圆拉环 Mesh、钢材/拉环材质、独立牛肉贴图及包装材质。
- `models/water_bottle/`：32 段瓶体场景和圆标签 Mesh。
- `models/battery/`：32 段电池场景、两极标记材质。
- `tools/build_revisions.gd`、`build_beef_label.py`：只写 R1 目录的离线构建工具。
- `preview/revision_preview.gd`、`revision_preview.tscn`、`RunPreview.bat`。
- `tests/validate_revisions.gd`、`capture_revisions.gd`、`audit_revision.py`。
- 本报告与 `evidence/` 中的快照、日志、结果、截图及拼图。

完整逐文件清单：`evidence/file_manifest.json`。既有文件修改清单为空。

## 限制与人工验收

32 段轮廓在极端放大下仍可见规则分段；本轮不继续增加面数。电极标识及包装文字在近景可读，在 9.2 游戏视野中物品只有数个到十余个像素，无法阅读这些细节；正常视野下的电池整体辨识度仍需玩家判断。没有通过改变实际尺寸、增加发光或新增 UI 来补偿。

请在 R1 入口集中检查三种物品的三个角度，确认轮廓圆度；查看罐头正面名称、牛肉图案及背面接缝；从顶部与低角度检查拉环孔洞和间距；翻转电池确认 +/− 随模型固定；最后按 3 检查游戏尺寸。自动验证不等于人工视觉验收通过。

本阶段停止于纯视觉修订，等待玩家确认。未生成图标，未修改背包 UI、库存、装备、战斗、存档或正式关卡，也不自动推进后续阶段。
