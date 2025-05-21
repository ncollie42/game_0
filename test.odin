package main
import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

// ---- Closure :: Action
ActionSpawnCubeAtMouse :: struct {
	// Add other variables if you want more state ie: number of times used, upgraded bool, ext
	camera: ^rl.Camera3D,
	pool:   ^[dynamic]vec3,
}

ActionSpawnCubeAtLocation :: struct {
	location: ^Spacial,
	pool:     ^[dynamic]vec3,
}

ActionSpawnMeleAtPlayer :: struct {
	player: ^Player,
	pool:   ^AbilityPool,
}

SpawnBashingMeleAtPlayer :: struct {
	player: ^Player,
	pool:   ^AbilityPool,
}

newPlayerDashAbility :: proc(player: ^Player, camera: ^rl.Camera3D) -> State {
	// No action needed

	// For now not using AbilityConfig; might have it's own config later.
	return playerStateDashing{timer = Timer{max = .5}, animation = PLAYER.run_fast, speed = 1.0}
}

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
// ---- Spawn
// ---- Despawn
// ---- Update
// ---- Draw


// Create a single version first, then create functions to update in mass
