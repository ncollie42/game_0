package main

import clay "/clay-odin"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"
// used := [UpgradeName]bool
// img := [UpgradeName]rl.Texture2D
// txt := [UpgradeName]string
// OR
// unlocks := [UpgradeName]Unlock
// Unlock :: struct {
// 	img:  rl.Texture2D,
// 	text: string,
// 	used: bool, // Could be here or split into different arrays -> 
// }

// upgrades :: struct {
// 	used:  [dynamic]unlock,
// 	free:  [dynamic]unlock,
// 	//
// 	mele:  [dynamic]unlock, // Sequential upgrades for same thing [0,1,2]?
// 	stats: [dynamic]unlock,
// }
// [dynamic]unlocks -> Sequential for ungrade paths? ability - upgrade 1 2 3?
// 
UpgradeName :: enum {
	RangeUnlock,
	AoeUnlock,
	GravityUnlock,
	AttackSpeed,
	Physical,
	P_Crit,
	Magic,
	M_Crit,
	Mana,
	Mana_Recharge,
	Stamina,
}

UpgradeType :: enum {
	Nil,
	Stat,
	Ability,
	Reaction,
}

Rarity :: enum {
	Common,
	Uncommon,
	Rare,
	Epic,
	Egendary,
}

Upgrade :: struct {
	name:   UpgradeName,
	img:    TextureName,
	rarity: Rarity,
	type:   UpgradeType,
}

UpgradesUsed := [dynamic]UpgradeName{}

startUpgradePhase :: proc() {
	// phase -> playing -> upgrade -> Add state machine to game, do we add pause to it and remove it from app? - or add to this func?
	//
	// StartUpgradePhase(game, app) {
	// 1. set upgradeOptions -> Based on anything
	// 2. Set phase
	// }
	//
	// drawUpgradePhase(game, app)
	// 3. In UI -> if pressed -> doUnlock(game, name) - set state back to playing
}

doUpgrade :: proc(game: ^Game, name: UpgradeName) {
	using game

	fmt.println("[Upgrade] ", name)
	switch name {
	case .RangeUnlock:
		append(&deck.free, RangeAttackConfig)
	case .AoeUnlock:
		append(&deck.free, AoeAttackConfig)
	case .GravityUnlock:
		append(&deck.free, GravityAttackConfig)
	case .AttackSpeed:
		attack := MeleAttackConfig.state.(playerStateAttack)
		attack.cancel_frame = 10
	// OR
	// player.animState.speed += .1
	case .Physical:
		game.player.power.Physical += 1
	case .Magic:
		game.player.power.Magic += 1
	case .P_Crit:
		game.player.power.P_Crit += .05
	case .M_Crit:
		game.player.power.M_Crit += .05
	case .Mana:
		player.mana.max += 1
		player.mana.current += 1
	case .Mana_Recharge:
		ManaRechargeSpeed += .1
	case .Stamina:
		Stamina.max += 1
		Stamina.current += 1
	}
	append(&UpgradesUsed, name)
}

upgradeDescription :: proc(game: ^Game, name: UpgradeName) -> string {
	using game

	description := "N/A"
	switch name {
	case .RangeUnlock:
		description = actionDescription2(RangeAttackConfig)
	// description = actionDescription(.Range)
	case .AoeUnlock:
		description = actionDescription2(AoeAttackConfig)
	case .GravityUnlock:
		description = actionDescription2(GravityAttackConfig)
	case .AttackSpeed:
		description = "Increase attack speed"
	case .Physical:
		description = "Increase Physical power by 1"
	case .Magic:
		description = "Increase Magic power by 1"
	case .P_Crit:
		description = "Increase Physical Crit chance by 5%"
	case .M_Crit:
		description = "Increase Magic Crit Chanse by 5%"
	case .Mana:
		description = "Increase Mana by 1"
	case .Mana_Recharge:
		description = "Increase Mana Regeneration Speed by 10%"
	case .Stamina:
		description = "Increase Stamina by 1"
	}
	return description
}
/*
1. Function :: proc(Game, enum) {for the upgrade to do}
Useing enum, and game - we can we all the stuff we need directly
- No way to keep track of state, if unlocked or not.
- Unless we wrap that on a struct too [UpgradeName]bool, []unlocks

2. create a union for callbacks for upgrades

how to do text? -> What about for feeding in damage?
60% of power
*/

// eventNames :: enum{enemyDead, player hurt} for now, maybe union later
// eventSystem :: Queue -> global
// addEvent(name)
// onupdate -> processQueue(game) -> switch eventName -> do stuff

a1 := Upgrade {
	name   = .RangeUnlock,
	img    = .Mark1,
	type   = .Ability,
	rarity = .Common,
}

a2 := Upgrade {
	name   = .AoeUnlock,
	img    = .Mark2,
	type   = .Ability,
	rarity = .Common,
}

a3 := Upgrade {
	name   = .GravityUnlock,
	img    = .Mark1,
	type   = .Ability,
	rarity = .Common,
}

// ----------------- XP -----------------------------
// Player wants consistent dopamine hits through steady level-up frequency (~60 seconds)
// while feeling increasingly overpowered toward the end of 20-30 minute matches.
// Using 1 kill = 1 XP system with instant first level-up, then scaling requirements.
// Goal is player power growth outpacing enemy power growth for power fantasy finale

Xp :: struct {
	showing: f32,
	current: f32,
	max:     f32,
	level:   i32,
}

newXp :: proc() -> Xp {
	return Xp{0, 0, getXPforLevel(1), 1}
}

getXPforLevel :: proc(level: i32) -> f32 {
	lvl := f32(level)
	if lvl == 1 do return 1
	return 2 + (lvl - 2.0) * 1.2 + math.pow(f32(lvl) - 2.0, 2) * 0.15
}

updateXPbar :: proc(xp: ^Xp, state: ^PlayState) {
	current := min(xp.current, xp.max)
	xp.showing = rl.Lerp(xp.showing, current, .02) // move 2% closer to current

	if !closeEnough(xp.current, xp.showing, .02) do return // Wait until showing XP is pretty close before leveling up
	if xp.current < xp.max do return // Return when 

	xp.current = xp.max - xp.current // Carry over on surplus
	xp.showing = 0
	xp.level += 1 // Capout at 30?
	xp.max = getXPforLevel(xp.level)
	// TODO: Show DING effect on level up + sound? or is upgrade section good enough
	state^ = PlayState.UPGRADE
}

closeEnough :: proc(aa: f32, target: f32, amount: f32) -> bool {
	if aa > target do return true
	return math.abs(aa - target) <= amount
}

drawXPbarUI :: proc(xp: Xp) {
	amount := xp.showing / xp.max
	layout := clay.LayoutConfig {
		sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(10)},
		padding = {0, 0, 0, 0},
		childGap = childGap,
		childAlignment = {.LEFT, .CENTER},
		layoutDirection = .LEFT_TO_RIGHT,
	}
	rec := clay.RectangleElementConfig {
		color        = {90, 90, 90, 180},
		cornerRadius = {10, 10, 10, 10},
	}

	if clay.UI(clay.ID("xp bar"), clay.Layout(layout), clay.Rectangle(rec)) {
		// Fill
		if clay.UI(
			clay.Layout(
				{sizing = {width = clay.SizingPercent(amount), height = clay.SizingGrow({})}},
			),
			clay.Rectangle(
				{color = COLOR_XP_GREEN, cornerRadius = clay.CornerRadiusAll(uiCorners)},
			),
		) {}
	}
}
