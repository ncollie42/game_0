package main
import "core:fmt"
import rl "vendor:raylib"

Infinate :: struct {}
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
	usageLimit: UsageLimit,
	cost:       int,
	cd:         Timer,
	action:     Action,
	// UI
	// Level
}

// Actions :: Closure for actions in game; used at a later time.
// Closure
Action :: union {
	ActionSpawnCubeAtPlayer,
	ActionSpawnCubeAtMouse,
	ActionSpawnMeleAtPlayer,
}

doAction :: proc(action: Action) {
	switch a in action {
	case ActionSpawnCubeAtMouse:
		spawnCubeAtMouse(a.pool, a.camera)
	case ActionSpawnCubeAtPlayer:
	case ActionSpawnMeleAtPlayer:
		spawnMeleInstanceAtPlayer(a.pool, a.player)
	}
}

startAction :: proc(action: Action, player: ^Player, camera: ^rl.Camera3D) {
	switch a in action {
	case ActionSpawnCubeAtMouse:
		enterPlayerState(
			player,
			playerStateAttack1 {
				trigger = .3,
				hasTriggered = false,
				animation = .H1_MELEE_ATTACK_SLICE_HORIZONTAL,
				action = action,
			},
			camera,
		)
	case ActionSpawnCubeAtPlayer:
		enterPlayerState(
			player,
			playerStateAttack1 {
				trigger = .3,
				hasTriggered = false,
				animation = .H1_MELEE_ATTACK_STAB,
				action = action,
			},
			camera,
		)
	case ActionSpawnMeleAtPlayer:
		enterPlayerState(
			player,
			playerStateAttack1 {
				trigger = .5,
				hasTriggered = false,
				animation = .H1_MELEE_ATTACK_CHOP,
				action = action,
			},
			camera,
		)
	}
}

// How to add a new action
// 1. Create function to do something in a system. ; test by it self
// 2. create new Action struct to encapsualte closure
// 3. create new function to create this ability
// 4. Add to doAction switch
// 5. Add to startAnimation switch
// StartAnim -> PlayerState & Anim -> doAction()
