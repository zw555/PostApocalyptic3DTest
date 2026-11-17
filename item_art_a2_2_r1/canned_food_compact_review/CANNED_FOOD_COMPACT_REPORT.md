# 牛肉罐头矮罐局部优化

日期：2026-11-17。引擎：Godot 4.5.2。状态：**等待玩家人工验收**。

仅优化当前 `canned_food`，参考玩家提供样图的矮胖轮廓、卷边、盖面同心压纹和平放拉环。水瓶、电池及其他物品未改。

## 当前结果

- 外径 **90mm**，总高 **39.5mm**，高径比 **43.9%**，符合 40%～50% 的要求。
- 上下金属卷边；盖面为有真实高度变化的 Procedural ArrayMesh，包含三圈浅压纹。继续使用原钢材与拉环材质。
- 拉环平放于盖面上方约 **0.6mm**，厚 **0.8mm**；真实椭圆孔、后部实心连接片、铆钉杆及可见铆钉头均由几何体构成。
- 保留原米黄色、牛肉图案、“牛肉罐头”、品牌及食品说明。原 `beef_label.png`、`beef_label_texture.res`、`beef_packaging.tres` 哈希完全不变，通过曲面 UV 小片重新排布旧内容，避免把高罐标签直接压扁。
- 保留底部中心原点、根节点单位变换、`item_id=canned_food` 以及原主要视觉节点名称。当前模型原本无碰撞体或交互脚本，因此无需新增/调整碰撞；业务接口未动。
- 采用 Godot 原生圆柱、TorusMesh 和程序化 Mesh，未使用 Blender 或外部模型。模型共 **5,952 三角面**。

## 使用与截图

模型路径保持不变：

`res://item_art_a2_2_r1/models/canned_food/canned_food_visual.tscn`

重新运行现有 `E:/GameProject/PostApocalyptic3DTest/item_art_a2_2_r1/RunPreview.bat`，默认即为更新后的牛肉罐头。按 F2 查看 65°，拖动或 A/D 旋转，L 切换辅助光，3 查看游戏尺寸。无需使用新的预览入口。

- [65°更新截图](evidence/after/after_65.png)
- [相同机位前后对比](evidence/comparison_65.png)
- [65°盖面与拉环特写](evidence/after/lid_detail_65.png)
- [标签正面补充检查](evidence/after/label_front.png)

前后对比采用相同的 65°、模型旋转 28°、0.15m 正交取景、主光和相机位置，物品底部位于同一世界高度。原始截图为 1440×1000。不是从参考图改绘出的效果图。

## 验证

专项检查在 headless 与 RTX 4060 Laptop / Vulkan Forward+ 实渲染中均执行，**15 PASS / 0 FAIL**；另有 **10 项保存性、机位和 Git 核对通过**。

检查覆盖实际高径比、原点、原节点接口、有效顶点/法线、非退化三角面、面朝向、几何压纹、拉环贯通孔、实心连接片、贴盖间距、铆接构件、原贴图引用及加载运行。最终日志无脚本或渲染资源泄漏错误。

结果见 `evidence/validation.json`、`preservation.json`；机位见 `evidence/captures.json`。保留旧测试及旧证据，没有修改旧高度断言来适配新罐型；本次使用独立专项检查。

## 文件范围与保护

修改四个已有文件：

1. `item_art_a2_2_r1/tools/build_revisions.gd`：只调整罐头构建函数及罐头专用辅助函数；增加 `--can-only` 构建分支，避免本轮重写水瓶、电池。
2. `item_art_a2_2_r1/models/canned_food/canned_food_visual.tscn`。
3. `item_art_a2_2_r1/models/canned_food/oval_pull_tab.res`。
4. `item_art_a2_2_r1/models/canned_food/round_label_mesh.res`。

新增文件位于罐头目录和本验收目录：压纹盖 Mesh、四个旧标签内容曲面 Mesh、纸底和边线材质，以及本报告、专项检查、原模型备份、哈希记录、日志和截图。逐文件列表在 `evidence/preservation.json`。

实施前记录 **2,350 个已有文件**。除上述四文件外，其他已有文件哈希均不变；水瓶、电池的生成函数文本也完全不变。原罐头及生成脚本备份位于 `evidence/before/`。

Git 分支 `main`，HEAD `e36215ec8006291864632d4bf755aeaa1c8b2127` 不变；tracked/staged diff 为空，历史未跟踪文件全部保留。未暂存、提交、推送、reset、clean。

后续若需重建本罐头，应使用：

```powershell
& 'E:/Godot_v4.5.2-stable_win64.exe/Godot_v4.5.2-stable_win64_console.exe' --headless --path . --script res://item_art_a2_2_r1/tools/build_revisions.gd -- --can-only
```

## 人工验收与限制

请在现有 65° 视角确认矮胖比例、压纹金属高光、拉环孔与连接片可读性；再稍转低角度确认拉环贴近盖面，检查牛肉图案和名称。标签为原内容重新排版，并未复制参考图中的牛剪影或英文包装。

自动检查不能替代视觉认可。模型仍为纯视觉资源，未接入正式关卡、物品碰撞、背包或装备；未生成图标。本次完成后停止，等待玩家确认。
