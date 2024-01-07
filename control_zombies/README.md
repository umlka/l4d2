# 允许玩家在非对抗模式下扮演特感及坦克

### 需求
* [Source Scramble](https://forums.alliedmods.net/showthread.php?t=317175)
* [Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696)
* [Dominators Control](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_dominatorscontrol.sp)`解除控制性特感数量限制`

### 命令
* `!team3`		切换到特感方
* `!team2`		切换到生还方
* `!pb`			提前叛变
* `!pt`			转交坦克
* `!tt`			接管坦克
* `!class`		灵魂状态下更改特感类型(或使用鼠标中键也行)
* `鼠标中键`	非灵魂状态下管理员重置特感技能冷却时间

### 推荐安装
- [Zombie Spawn Fix](https://forums.alliedmods.net/showthread.php?p=2751992)`防止加载卡特, 结局卡特, 特感玩家在玩家加载时无法从灵魂状态下重生以及director_no_specials设置为1时提示的重生已禁用`

### 建议配置
```bash
// [l4d2_dominatorscontrol.smx]
sm_cvar l4d2_dominators 0

// 复活时间
sm_cvar z_ghost_delay_min 5
sm_cvar z_ghost_delay_max 10
sm_cvar z_ghost_delay_minspawn 0

// 复活最小距离
sm_cvar z_spawn_safety_range 1

// 特感数量限制
sm_cvar z_max_player_zombies	28
sm_cvar z_versus_smoker_limit	5
sm_cvar z_versus_boomer_limit	5
sm_cvar z_versus_hunter_limit	5
sm_cvar z_versus_spitter_limit	5
sm_cvar z_versus_jockey_limit	5
sm_cvar z_versus_charger_limit	5
```
