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
	ActionSpawnAoEAtPlayer,
	ActionSpawnGPointAtMouse,
}

ClosureName :: enum {
	Nil,
	Mele,
	Range,
	Aoe,
	Gravity,
}

Closures := [ClosureName]Closure{} // Global

doAction :: proc(name: ClosureName) {
	switch &a in Closures[name] {
	case ActionSpawnMeleAtPlayer:
		dmg := a.percent * a.player.power.Physical
		crit := a.player.power.M_Crit // Pass in crit, based on every attack

		forward := getForwardPoint(a.player)
		ability := newMeleInstance(a.player.pos + forward, dmg, crit)
		append(&a.pool.active, ability)
	case ActionSpawnRangeAtPlayer:
		crit := a.player.power.M_Crit
		dmg := a.percent * a.player.power.Magic

		forward := getForwardPoint(a.player)
		ability := newRangeInstance(a.player.pos + forward, a.player.rot, dmg, crit)
		append(&a.pool.active, ability)
	case ActionSpawnAoEAtPlayer:
		crit := a.player.power.M_Crit
		dmg := a.percent * a.player.power.Magic
		pos := a.player.pos

		ability := newAoEInstance(pos, dmg, crit)
		append(&a.pool.active, ability)
	case ActionSpawnGPointAtMouse:
		mouse := mouseInWorld(a.camera)
		spawnGravityPoint(a.pool, mouse)
	}
}

actionDescription :: proc(name: ClosureName) -> string {
	description := "N/A"
	switch a in Closures[name] {
	case ActionSpawnMeleAtPlayer:
		description = fmt.tprintf("Type: Physical\nPower: %.0f%%\nMele Attack", a.percent * 100)
	case ActionSpawnRangeAtPlayer:
		description = fmt.tprintf("Type: Magic\nPower: %.0f%%\nRange attack", a.percent * 100)
	case ActionSpawnAoEAtPlayer:
		description = fmt.tprintf("Type: Magic\nPower: %.0f%%\nRange attack", a.percent * 100)
	case ActionSpawnGPointAtMouse:
		description = fmt.tprintf("Gravity point")
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

ActionSpawnRangeAtPlayer :: struct {
	percent: f32, //[0,1] % of damage of given power
	// Magic or physical? probably wont change 
	player:  ^Player,
	pool:    ^AbilityPool,
}

ActionSpawnAoEAtPlayer :: struct {
	percent: f32, //[0,1] % of damage of given power
	player:  ^Player,
	pool:    ^AbilityPool,
}

ActionSpawnGPointAtMouse :: struct {
	camera: ^rl.Camera,
	pool:   ^[dynamic]GravityPoint,
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
	closureName = ClosureName.Range,
	state = playerStateAttack {
		cancellable = true,
		animation = PLAYER.punch,
		action_frame = 10,
		cancel_frame = 16,
		speed = 1,
		closure = ClosureName.Range,
	},
}

AoeAttackConfig := AbilityConfig {
	cost = 1,
	cd = Timer{max = 5},
	usageLimit = Limited{2, 2},
	img = .Mark2,
	closureName = ClosureName.Aoe,
	state = playerStateAttack {
		cancellable = true,
		animation = PLAYER.punch,
		action_frame = 10,
		cancel_frame = 16,
		speed = 1,
		closure = ClosureName.Aoe,
	},
}

GravityAttackConfig := AbilityConfig {
	cost = 1,
	cd = Timer{max = 5},
	usageLimit = Limited{2, 2},
	img = .Mark2,
	closureName = ClosureName.Gravity,
	state = playerStateAttack {
		cancellable = true,
		animation = PLAYER.punch,
		action_frame = 10,
		cancel_frame = 16,
		speed = 1,
		closure = ClosureName.Gravity,
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
