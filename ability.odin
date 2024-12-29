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
	state:      State, //State Transion for player
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
		spawnCubeAtPlayer(a.pool, a.player)
	case ActionSpawnMeleAtPlayer:
		spawnMeleInstanceAtPlayer(a.pool, a.player)
	}
}

// How to add a new action
// 1. Create function to do something in a system. ; test by it self
// 2. create new Action struct to encapsualte closure
// 3. create new function to create this ability
// 4. Add to doAction switch
// 5. Add to startAnimation switch
// StartAnim -> PlayerState & Anim -> doAction()
