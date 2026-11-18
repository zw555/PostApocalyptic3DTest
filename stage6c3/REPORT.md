# After Hours · Stage 6-C.3 基础生存状态与食物使用

**Stage 6-C.3 开发完成，玩家已确认人工验收通过。**

## C.2 归档

开始时，本地和远端 `main` 均为 `4b62c24ec33b35ec9ed3aad6ade1dacc1651e1cd`，暂存区为空。核对 C.2 场景、仓库、共用接口、专项和报告后，按清单提交 22 个文件。提交 `c6cd300632643cfa76ff60acc751b59ab490e3af` 已普通推送至 `origin/main`，独立查询确认远端哈希一致。保留了未选入归档的原始截图及其他历史未跟踪文件。C.3 没有暂存或提交。

## 生存数据和计时

C.3 场景继承 C.2。每个实例单独创建一个 `SurvivalState`，其中两个浮点值保存饥饿和口渴进度。新局以最大值初始化。速率、上限、警告阈值、回复量和物品效果映射集中于生存配置资源与脚本。

| 状态 | 初始与上限 | 每分钟消耗 | 恢复物品 |
| --- | ---: | ---: | --- |
| 饥饿 | 100 | 1 | 牛肉罐头 +35 |
| 口渴 | 100 | 1.5 | 瓶装水 +40 |

唯一入口是 C.3 游戏场景原有 `_process(delta)` 调用链。生存消耗按 `delta / 60` 将游戏秒数转换为分钟，背包和仓库使用现有世界模态判定，Esc 新增的 C.3 暂停菜单使用 SceneTree 暂停。死亡后停止更新。关闭界面或恢复游戏时从后续活动帧继续，暂停期间没有积压计时。零值只警告，不修改 HP。HUD 位于右下 HP 面板下方，数值低于 25 显示「偏低」，归零显示「已耗尽」。

## 物品使用

C.3 背包复用绷带的使用按钮。选中罐头或水时，详情显示当前数量、对应状态、回复量及当前值。电池保持无使用按钮，绷带继续走原治疗代码。

使用时校验玩家存活、所选槽位及物品 ID、对应状态未满。复用 `InventoryModel.remove_item()` 的同步提交回调，在写入真实库存前确认并设置恢复后的数值。事务失败时物品和生存状态均保留原值。事务成功时只扣除所选槽位的一份，回复最多到 100。库存观察器只能在两项状态一致后收到通知，事务锁拒绝重入。暂停、空槽、满值或死亡均不能消耗物品。

## 验证

| 测试 | 结果 |
| --- | ---: |
| C.3 Headless | 114/114 |
| C.3 独立 Vulkan Forward+ | 139/139，含 25 项截图保存检查 |
| C.2 仓库历史入口 | 98/98 |
| C.1 探索历史入口 | 57/57 |
| B.5-B1 遭遇 / B.4-A 绷带 | 76/76、27/27 |

使用 Godot 4.5.2、Vulkan 1.3.289、RTX 4060 Laptop GPU 和 1440×1000 视口。Vulkan 计时样本中，限制为 30 FPS 时，62 帧内实测约 2.031 秒，生存计入 2.021 秒。限制为 120 FPS 时，240 帧内实测约 2.012 秒，生存计入 2.005 秒。两项消耗按相同时间推进。专项也检查了各种暂停、满值和欠量使用、库存事务重入、警告与 HP 隔离、仓库存取后食用，以及原角色物理的三楼往返和五楼战斗。低值截图通过测试快进生存值取得。

并行验证时曾有一次绷带槽位的模拟鼠标点击未选中，导致三个关联断言失败。独立运行 Vulkan 后全部通过。保留并行结果供复核。

- [Headless 结果](evidence/headless.json) · [Vulkan 结果](evidence/vulkan.json) · [并行渲染结果](evidence/parallel_render_attempt.json)
- [HUD 45°](evidence/survival_HUD_F5.png) · [HUD 65°](evidence/survival_HUD_F2.png) · [HUD 85°](evidence/survival_HUD_F1.png) · [Esc 暂停](evidence/pause_menu.png)
- [仓库存入水和罐头](evidence/food_water_in_storage.png) · [罐头恢复](evidence/food_used.png) · [饮水恢复](evidence/water_used.png) · [满值拒绝](evidence/full_refused_water_bottle.png)
- [五楼遭遇](evidence/02_fifth_floor_bandage.png) · [三楼搜刮](evidence/04_third_floor_supplies.png) · [返回 501 后使用物资](evidence/501_return_and_used_stock.png) · [战斗 HUD](evidence/06_knife_counter.png)

## 文件清单

- [启动器](../RunStage6C3.bat)和[继承场景](scenes/gameplay.tscn)。
- [生存参数资源](data/survival.tres)、[参数映射](scripts/survival_profile.gd)和[运行状态及消费事务](scripts/survival_state.gd)。
- [场景和计时装配](scripts/gameplay.gd)、[生存 HUD](scripts/survival_hud.gd)、[背包派生面板](scripts/survival_inventory_panel.gd)和[暂停菜单](scripts/pause_menu.gd)。
- [专项测试](tests/validate_survival.gd)、本报告和 `evidence/` 中三份结果及上面链接的十二张归档截图。其他截图留作可复现的本地测试输出。

## 人工验收

1. 运行 [RunStage6C3.bat](../RunStage6C3.bat)。检查右下角饥饿和口渴从 100 开始随时间下降。依次打开背包、501 仓库和 Esc 暂停菜单，停留数秒确认数值冻结，关闭后继续下降。
2. 出门经五楼下至四、三楼，领取水、罐头和绷带。用 F5、F2、F1 切换 45°、65°、85°，确认生存 HUD 和交互提示清晰。
3. 返回 501，将水和罐头存入仓库后取出。按 I 选中并各使用一份，检查只恢复对应状态且只扣一份。保持背包打开再用同种物品，满值时应显示拒绝并保留库存。
4. 在五楼遭遇时检查 HP 和生存 HUD。受伤后使用绷带，确认只恢复 HP。玩家死亡后生存数值应停止消耗。

当前消耗率较慢，短路线通常只出现少量缺口。零值与告警的自动验证采用快进测试。运行数据随新局重置，C.3 沿用 B.5 已知的追击手感限制。
