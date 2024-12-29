package main

import rl "vendor:raylib"

Enemy :: struct {
	model:         rl.Model,
	animation:     Animation,
	using spacial: Spacial,
	using health:  Health,
	state:         EnemyState,
}

EnemyDummyPool :: struct {
	active: [dynamic]Enemy,
	free:   [dynamic]Enemy,
}

EnemyState :: union {
	EnemyStateBase,
	EnemyPushback,
}

EnemyStateBase :: struct {}
EnemyPushback :: struct {}

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
		enemy.health.max = 3
		enemy.state = EnemyStateBase{}
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

// ---- Despawn

despawnEnemy :: proc(pool: ^EnemyDummyPool, index: int) {
	// Swap and remove last
	append(&pool.free, pool.active[index])
	pool.active[index] = pop(&pool.active)
}

// ---- Update
updateEnemyDummies :: proc(enemies: ^EnemyDummyPool, player: Player) {
	for &enemy, index in enemies.active {
		updateDummy(&enemy, player)
		updateHealth(&enemy)
		if enemy.health.current <= 0 {
			despawnEnemy(enemies, index)
		}
	}
}

updateDummy :: proc(enemy: ^Enemy, player: Player) {
	switch &s in enemy.state {
	case EnemyStateBase:
		r := lookAtVec3(player.spacial.pos, enemy.spacial.pos)
		enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * TURN_SPEED)
	case EnemyPushback:
	// Lower a timer; when over; change state
	// enemy.spacial.pos 
	case:
		enemy.state = EnemyStateBase{}
	}
}

// ---- Draw
drawEnemies :: proc(enemies: ^EnemyDummyPool) {
	for enemy in enemies.active {
		drawEnemy(enemy)
	}
}

drawEnemy :: proc(enemy: Enemy) {
	// rl.DrawModelEx(enemy.model, enemy.spacial.pos, UP, rl.RAD2DEG * enemy.spacial.rot, 1, rl.BLANK)
	// Get around for hitflash untill we add in a shader? This makes it transperent for a bit and it's a little weird
	rl.DrawModelEx(
		enemy.model,
		enemy.spacial.pos,
		UP,
		rl.RAD2DEG * enemy.spacial.rot,
		1,
		{255, 255, 255, u8(enemy.hitFlashLerp)},
		// {0, 0, 0, u8(enemy.hitFlash)},
	)
}

// Update Funcs
hurtEnemy :: proc(enemy: ^Enemy, amount: f32) {
	hurt(enemy, amount)
	enemy.health.hitFlashLerp = 0 // Move into generic hurt?
	// Sound
	// Push back
	// Particle
}
