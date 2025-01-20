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

newSpawnCubeAbilityMouse :: proc(pool: ^[dynamic]vec3, camera: ^rl.Camera3D) -> AbilityConfig {
	action := ActionSpawnCubeAtMouse {
		camera = camera,
		pool   = pool,
	}

	config: AbilityConfig
	config.cost = 1
	config.cd.max = 5
	config.usageLimit = Limited{2, 2}
	// ability.usageLimit = Infinate{}
	config.state = playerStateAttack1 {
		timer = Timer{max = .6},
		trigger = .4,
		animation = PLAYER.punch2,
		speed = 1,
		action = action,
	}
	return config
}

// newSpawnCubeAbilityPlayer :: proc(pool: ^[dynamic]vec3, player: ^Player) -> AbilityConfig {
newSpawnCubeAbilityLocation :: proc(pool: ^[dynamic]vec3, loc: ^Spacial) -> AbilityConfig {
	action := ActionSpawnCubeAtLocation {
		location = loc,
		pool     = pool,
	}

	config: AbilityConfig
	config.cost = 1
	config.cd.max = 5
	config.usageLimit = Limited{2, 2}
	// ability.usageLimit = Infinate{}
	config.state = playerStateAttack1 {
		timer = Timer{max = .3},
		trigger = .4,
		animation = PLAYER.punch2,
		speed = 1.0,
		action = action,
	}
	return config
}

newPlayerDashAbility :: proc(player: ^Player, camera: ^rl.Camera3D) -> State {
	// No action needed

	// For now not using AbilityConfig; might have it's own config later.
	return playerStateDashing{timer = Timer{max = .5}, animation = PLAYER.roll, speed = 2.9}
}

newSpawnMeleAbilityPlayer :: proc(pool: ^AbilityPool, player: ^Player) -> AbilityConfig {
	action := ActionSpawnMeleAtPlayer {
		player = player,
		pool   = pool,
	}

	config: AbilityConfig
	config.cost = 1
	config.cd.max = 5
	config.usageLimit = Limited{2, 2}
	// ability.usageLimit = Infinate{}
	// KICK
	// config.state = playerStateAttack1 {
	// 	cancellable = true,
	// 	timer = Timer{max = .4},
	// 	trigger = .0, // [0, 1]
	// 	animation = .UNARMED_MELEE_ATTACK_KICK,
	// 	speed = 2,
	// 	action = action,
	// }
	// PUNCH A
	config.state = playerStateAttack1 {
		cancellable = true,
		timer = Timer{max = .3},
		trigger = .0,
		animation = PLAYER.punch1,
		speed = 4,
		action = action,
	}
	// PUNCH B
	// config.state = playerStateAttack1 {
	// 	timer = Timer{max = .4},
	// 	trigger = .0,
	// 	animation = .UNARMED_MELEE_ATTACK_PUNCH_B,
	// 	speed = 2,
	// 	action = action,
	// }

	return config
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
