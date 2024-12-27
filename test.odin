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

ActionSpawnCubeAtPlayer :: struct {
	player: ^Player,
	pool:   ^[dynamic]vec3,
}

ActionSpawnMeleAtPlayer :: struct {
	player: ^Player,
	pool:   ^AbilityPool,
}

newSpawnCubeAbilityMouse :: proc(pool: ^[dynamic]vec3, camera: ^rl.Camera3D) -> AbilityConfig {
	config: AbilityConfig
	config.cost = 1
	config.cd.time = 5
	config.usageLimit = Limited{2, 2}
	// ability.usageLimit = Infinate{}
	config.action = ActionSpawnCubeAtMouse {
		camera = camera,
		pool   = pool,
	}
	return config
}

newSpawnCubeAbilityPlayer :: proc(pool: ^[dynamic]vec3, player: ^Player) -> AbilityConfig {
	config: AbilityConfig
	config.cost = 1
	config.cd.time = 5
	config.usageLimit = Limited{2, 2}
	// ability.usageLimit = Infinate{}
	config.action = ActionSpawnCubeAtPlayer {
		player = player,
		pool   = pool,
	}
	return config
}

newSpawnMeleAbilityPlayer :: proc(pool: ^AbilityPool, player: ^Player) -> AbilityConfig {
	config: AbilityConfig
	config.cost = 1
	config.cd.time = 5
	config.usageLimit = Limited{2, 2}
	// ability.usageLimit = Infinate{}
	config.action = ActionSpawnMeleAtPlayer {
		player = player,
		pool   = pool,
	}
	return config
}

// ---- Init
// ---- Spawn
spawnCubeAtMouse :: proc(pool: ^[dynamic]vec3, camera: ^rl.Camera3D) {
	target := mouseInWorld(camera)
	spawnCube(pool, target)
}

spawnCubeAtPlayer :: proc(pool: ^[dynamic]vec3, player: ^Player) {
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
