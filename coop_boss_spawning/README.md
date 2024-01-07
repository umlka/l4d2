# 战役模式下解锁对抗中的Tank和Witch的刷新机制

### 需求
* [Source Scramble](https://forums.alliedmods.net/showthread.php?t=317175)
* [Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696)

### 冲突(以下插件功能已包含在 `coop_boss_spawning` 插件内, 请勿重复安装)
* [UnprohibitBosses](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/confoglcompmod/UnprohibitBosses.sp)
* [l4dvs_witch_spawn_fix](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4dvs_witch_spawn_fix)

### 说明
* `coop_boss_spawning` 为解锁补丁插件, 并包含了 `UnprohibitBosses`, `l4dvs_witch_spawn_fix` 两个必备插件所拥有的功能
* `witch_and_tankifier` 为 [Zonemod](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/witch_and_tankifier.sp) 中的原装插件, 控制Tank/Witch的生成范围, 只不过移除了战役用不上的插件依赖(如果你有需求, 可以将这个插件换成 `Zonemod` 的版本)
* `eq_finale_tanks`  为 [Zonemod](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/eq_finale_tanks.sp) 中的原装插件, 控制Tank在救援关的生成机制
* 请在server.cfg内添加以下代码(修改刷新范围以及阻止 `Tank/Witch` 在 `固定Tank` 或 `固定Witch` 的地图上刷新)
```bash
// [witch_and_tankifier.smx]
sm_cvar versus_boss_flow_min 0.10
sm_cvar versus_boss_flow_max 0.90
sm_cvar sm_witch_avoid_tank_spawn 10

// Static Tank maps / flow Tank disabled
static_tank_map c1m4_atrium
static_tank_map c4m5_milltown_escape
static_tank_map c5m5_bridge
static_tank_map c6m3_port
static_tank_map c7m1_docks
static_tank_map c7m3_port
static_tank_map c13m2_southpinestream
static_tank_map c13m4_cutthroatcreek
static_tank_map l4d2_darkblood04_extraction
static_tank_map x1m5_salvation
static_tank_map uf4_airfield
static_tank_map dprm5_milltown_escape
static_tank_map l4d2_diescraper4_top_361
static_tank_map dkr_m1_motel
static_tank_map dkr_m2_carnival
static_tank_map dkr_m3_tunneloflove
static_tank_map dkr_m4_ferris
static_tank_map dkr_m5_stadium
static_tank_map cdta_05finalroad
static_tank_map l4d_dbd2dc_new_dawn

// Finales with flow + second event Tanks
tank_map_flow_and_second_event c2m5_concert
tank_map_flow_and_second_event c3m4_plantation
tank_map_flow_and_second_event c8m5_rooftop
tank_map_flow_and_second_event c9m2_lots
tank_map_flow_and_second_event c10m5_houseboat
tank_map_flow_and_second_event c11m5_runway
tank_map_flow_and_second_event c12m5_cornfield
tank_map_flow_and_second_event c14m2_lighthouse
tank_map_flow_and_second_event nmrm5_rooftop

// Finales with a single first event Tank
tank_map_only_first_event c1m4_atrium
tank_map_only_first_event c4m5_milltown_escape
tank_map_only_first_event c5m5_bridge
tank_map_only_first_event c13m4_cutthroatcreek
tank_map_only_first_event cdta_05finalroad
tank_map_only_first_event l4d_dbd2dc_new_dawn

// Static witch maps / flow witch disabled
static_witch_map c4m2_sugarmill_a
static_witch_map c4m5_milltown_escape
static_witch_map c5m5_bridge
static_witch_map c6m1_riverbank
static_witch_map hf01_theforest
static_witch_map hf04_escape
static_witch_map cdta_05finalroad
static_witch_map l4d2_stadium5_stadium
static_witch_map x1m5_salvation
static_witch_map dkr_m1_motel
static_witch_map dkr_m2_carnival
static_witch_map dkr_m3_tunneloflove
static_witch_map dkr_m4_ferris
static_witch_map dkr_m5_stadium
```
