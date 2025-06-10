package main
import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

newPlayerDashAbility :: proc(player: ^Player, camera: ^rl.Camera3D) -> State {
	// No action needed

	// For now not using AbilityConfig; might have it's own config later.
	return playerStateDashing{timer = Timer{max = .5}, animation = PLAYER.dash, speed = 1}
}

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
// ---- Spawn
// ---- Despawn
// ---- Update
// ---- Draw


// Create a single version first, then create functions to update in mass
