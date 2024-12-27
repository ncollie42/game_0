package main

import rl "vendor:raylib"

Enemy :: struct {
	model:         rl.Model,
	animation:     Animation,
	using spacial: Spacial,
	using health:  Health,
}

EnemyDummyPool :: struct {
	active: [dynamic]Enemy,
	free:   [dynamic]Enemy,
}

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
initEnemyDummies :: proc(path: cstring) -> EnemyDummyPool {
	pool := EnemyDummyPool {
		active = make([dynamic]Enemy, 0, 10),
		free   = make([dynamic]Enemy, 10, 10),
	}

	for &enemy in pool.free {
		// Note: is loadModel slow? can I load once and dup memory for every model after?
		enemy.model = rl.LoadModel(path)
		assert(enemy.model.meshCount != 0, "No mesh")
	}
	return pool
}

// ---- Spawn
spawnDummyEnemy :: proc(pool: ^EnemyDummyPool, pos: vec3) {
	if len(pool.free) == 0 {
		// Do nothing if there isn't space for a new one.
		return
	}

	enemy := pop(&pool.free)
	enemy.spacial.pos = pos
	append(&pool.active, enemy)
}

// ---- Update
updateEnemyDummies :: proc(enemies: ^EnemyDummyPool, player: Player) {
	for &enemy in enemies.active {
		updateDummy(&enemy, player)
	}
}

updateDummy :: proc(enemy: ^Enemy, player: Player) {
	r := lookAtVec3(player.spacial.pos, enemy.spacial.pos)
	enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * TURN_SPEED)
}

// ---- Draw
drawEnemies :: proc(enemies: ^EnemyDummyPool) {
	for enemy in enemies.active {
		drawEnemy(enemy)
	}
}

drawEnemy :: proc(enemy: Enemy) {
	rl.DrawModelEx(enemy.model, enemy.spacial.pos, UP, rl.RAD2DEG * enemy.spacial.rot, 1, rl.WHITE)
}
