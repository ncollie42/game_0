package main
import "core:fmt"
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

newSpawnCubeAbilityMouse :: proc(pool: ^[dynamic]vec3, camera: ^rl.Camera3D) -> Ability {
	ability: Ability
	ability.cost = 1
	ability.cd.time = 5
	ability.usageLimit = Limited{2, 2}
	// ability.usageLimit = Infinate{}
	ability.action = ActionSpawnCubeAtMouse {
		camera = camera,
		pool   = pool,
	}
	return ability
}

newSpawnCubeAbilityPlayer :: proc(pool: ^[dynamic]vec3, player: ^Player) -> Ability {
	ability: Ability
	ability.cost = 1
	ability.cd.time = 5
	ability.usageLimit = Limited{2, 2}
	// ability.usageLimit = Infinate{}
	ability.action = ActionSpawnCubeAtPlayer {
		player = player,
		pool   = pool,
	}
	return ability
}

// ---- Init
// ---- Spawn
spawnCubeAtMouse :: proc(pool: ^[dynamic]vec3, camera: ^rl.Camera3D) {
	target := mouseInWorld(camera)
	spawnCube(pool, target)
}

spawnCubeAtPlayer :: proc(pool: ^[dynamic]vec3, player: ^Player) {
	spawnCube(pool, player.spacial.pos + player.spacial.dir)
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
// ---- Update
// ---- Draw
