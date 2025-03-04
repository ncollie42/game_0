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

newPlayerDashAbility :: proc(player: ^Player, camera: ^rl.Camera3D) -> State {
	// No action needed

	// For now not using AbilityConfig; might have it's own config later.
	return playerStateDashing{timer = Timer{max = .5}, animation = PLAYER.run_fast, speed = 1.0}
}

// ---- Init
// ---- Spawn
spawnCubeAtMouse :: proc(pool: ^[dynamic]vec3, camera: ^rl.Camera3D) {
	target := mouseInWorld(camera)
	spawnCube(pool, target)
}

spawnCubeAtLocation :: proc(pool: ^[dynamic]vec3, loc: ^Spacial) {
	pos := loc.pos
	mat := rl.MatrixTranslate(pos.x, pos.y, pos.z)
	mat = mat * rl.MatrixRotateY(loc.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	p := rl.Vector3Transform({}, mat)

	spawnCube(pool, p)
}

spawnMeleAtPlayer :: proc(pool: ^[dynamic]vec3, player: ^Player) {
	pos := player.spacial.pos
	mat := rl.MatrixTranslate(pos.x, pos.y, pos.z)
	mat = mat * rl.MatrixRotateY(player.spacial.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	p := rl.Vector3Transform({}, mat)

	spawnCube(pool, p)
}

spawnCube :: proc(pool: ^[dynamic]vec3, pos: vec3) {
	append(pool, pos)
}
// ---- Update
// ---- Draw


// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
// ---- Spawn
// ---- Despawn
// ---- Update
// ---- Draw


// Create a single version first, then create functions to update in mass
