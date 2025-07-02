package main

import "core:fmt"
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
		slot := getFreeSlot(game.hand)
		fmt.println("Adding, ", slot)
		if slot == .Nil {
			// Do we want to panic? should not give this option of we can't select? or we allow to overwride?
			panic("Don't know how to handle not option yet")
		}
		game.hand[slot] = RangeAttackConfig
	case .AoeUnlock:
		slot := getFreeSlot(game.hand)
		fmt.println("Adding, ", slot)
		if slot == .Nil {
			// Do we want to panic? should not give this option of we can't select? or we allow to overwride?
			panic("Don't know how to handle not option yet")
		}
		game.hand[slot] = AoeAttackConfig
	case .GravityUnlock:
		slot := getFreeSlot(game.hand)
		fmt.println("Adding, ", slot)
		if slot == .Nil {
			// Do we want to panic? should not give this option of we can't select? or we allow to overwride?
			panic("Don't know how to handle not option yet")
		}
		game.hand[slot] = GravityAttackConfig
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
