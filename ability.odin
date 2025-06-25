package main
import "core:fmt"
import rl "vendor:raylib"

Infinate :: struct {
}
Limited :: struct {
	max:     u8,
	current: u8,
}

UsageLimit :: union {
	Infinate,
	Limited,
}

// Closure for ability
AbilityConfig :: struct {
	usageLimit:  UsageLimit,
	cost:        int,
	cd:          Timer,
	closureName: ClosureName, // NOTE: only for easy getting - could just go into the state.
	state:       State, //State Transion for player
	// UI
	img:         TextureName,
	// Level [0,1,2]
	// Audio function?
}

Closure :: union {
	ActionSpawnMeleAtPlayer,
	ActionSpawnRangeAtPlayer,
}

ClosureName :: enum {
	Nil,
	Mele,
	Range,
}

Closures := [ClosureName]Closure{} // Global

doAction :: proc(name: ClosureName) {
	switch a in Closures[name] {
	case ActionSpawnMeleAtPlayer:
		dmg := a.percent * a.player.power.Physical
		crit := a.player.power.M_Crit // Pass in crit, based on every attack
		spawnMeleInstanceAtPlayer(a.pool, a.player, dmg, crit)
	case ActionSpawnRangeAtPlayer:
		crit := a.player.power.M_Crit
		dmg := a.percent * a.player.power.Magic
		spawnRangeInstanceAtPlayer(a.pool, a.player, dmg, crit)
	}
}

actionDescription :: proc(name: ClosureName) -> string {
	description := "N/A"
	switch a in Closures[name] {
	case ActionSpawnMeleAtPlayer:
		description = fmt.tprintf("Type: Physical\nPower: %.0f%%\nMele Attack", a.percent * 100)
	case ActionSpawnRangeAtPlayer:
		description = fmt.tprintf("Type: Magic\nPower: %.0f%%\nRange attack", a.percent * 100)
	}
	return description
}

actionDescription2 :: proc(config: AbilityConfig) -> string {
	description := "N/A"
	// config.usageLimit
	// config.cost
	// config.cd
	description = actionDescription(config.closureName)
	return description
}

// How to add a new action
// 1. Create function to do something in a system. ; test by it self
// 2. create new Action struct to encapsualte closure
// 3. create new function to create this ability
// 4. Add to doAction switch
// 5. Add to startAnimation switch
// StartAnim -> PlayerState & Anim -> doAction()

ActionSpawnMeleAtPlayer :: struct {
	// type : physical or magic? -> Wrap out action :: struct {type, percent, union{}}
	percent: f32, //[0,1] % of damage of given power
	player:  ^Player,
	pool:    ^AbilityPool,
}

spawnMeleInstanceAtPlayer :: proc(pool: ^AbilityPool, player: ^Player, damage: f32, crit: f32) {
	forward := getForwardPoint(player)

	spawnMeleInstance(pool, player.pos + forward, damage, crit)
}

ActionSpawnRangeAtPlayer :: struct {
	percent: f32, //[0,1] % of damage of given power
	// Magic or physical? probably wont change 
	player:  ^Player,
	pool:    ^AbilityPool,
}

spawnRangeInstanceAtPlayer :: proc(pool: ^AbilityPool, player: ^Player, damage: f32, crit: f32) {
	forward := getForwardPoint(player)

	spawnRangeInstance(pool, player.pos + forward, player.rot, damage, crit)
}

// Global
MeleAttackConfig := AbilityConfig {
	cost = 0,
	cd = Timer{max = 5},
	usageLimit = Infinate{},
	img = .Mark1,
	closureName = .Mele,
	state = playerStateAttack {
		cancellable  = true,
		animation    = PLAYER.punch,
		action_frame = 10,
		// TODO: add a transition_frame? different than cancel_frame
		cancel_frame = 16, //10 - attack quicker with lower transition frame [10,16]
		speed        = 1,
		closure      = .Mele,
	},
}

RangeAttackConfig := AbilityConfig {
	cost = 1,
	cd = Timer{max = 5},
	usageLimit = Limited{2, 2},
	img = .Mark2,
	closureName = .Range,
	state = playerStateAttack {
		cancellable = true,
		animation = PLAYER.punch,
		action_frame = 10,
		cancel_frame = 16,
		speed = 1,
		closure = .Range,
	},
}

hasFreeSlot :: proc(hand: [HandAction]AbilityConfig) -> bool {
	empty := AbilityConfig{}
	for config, slot in hand {
		if slot == nil do continue
		if config == empty do return true
	}
	return false
}

isActiveSlot :: proc(hand: [HandAction]AbilityConfig, slot: HandAction) -> bool {
	empty := AbilityConfig{}
	return hand[slot] != empty
}

getFreeSlot :: proc(hand: [HandAction]AbilityConfig) -> HandAction {
	empty := AbilityConfig{}
	for config, slot in hand {
		if slot == .Nil do continue
		if config == empty do return slot
	}
	return .Nil
}
