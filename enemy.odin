package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

Enemy :: struct {
	model:         rl.Model,
	animState:     AnimationState,
	using spacial: Spacial,
	using health:  Health,
	attackCD:      Timer, // CD for attacking
	type:          union {
		meleEnemy,
		rangeEnemy,
		dummyEnemy,
	},
}

EnemyDummyPool :: struct {
	active:    [dynamic]Enemy,
	freeDummy: [dynamic]Enemy,
	animSet:   AnimationSet,
	freeMele:  [dynamic]Enemy,
	// animSet:   AnimationSet,
	freeRange: [dynamic]Enemy,
	// animSet:   AnimationSet,
}

EnemyState :: union {
	EnemyStateIdle,
	EnemyStateBase,
	EnemyPushback,
	EnemyAttack1,
	EnemyHurt,
}

EnemyStateBase :: struct {}
EnemyAttack1 :: struct {
	animation:    ANIMATION_NAMES,
	animSpeed:    f32,
	duration:     f32, // Duration of state, player uses a timer, trying this instead.
	trigger:      f32, // different than player to see how this works, trigger is time not [0,1]
	hasTriggered: bool,
}
EnemyPushback :: struct {
	duration:  f32,
	animation: SKELE,
	animSpeed: f32,
}
EnemyHurt :: struct {
	duration:  f32,
	animation: SKELE,
	animSpeed: f32,
}

// ---- ---- ---- ---- Init ---- ---- ---- ---- 
enemyPoolSize := 25
initEnemyDummies :: proc() -> EnemyDummyPool {
	// It looks like we can share the same shader for all enemies
	// shader := rl.LoadShader(nil, "shaders/grayScale.fs")
	shader := rl.LoadShader(nil, "shaders/flash.fs")

	pool := EnemyDummyPool {
		active    = make([dynamic]Enemy, 0, 0),
		freeDummy = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
		freeMele  = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
		freeRange = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
	}
	path: cstring = "/home/nico/Downloads/Human2/base.m3d"

	pool.animSet = loadModelAnimations(path)
	texture := loadTexture("/home/nico/Downloads/Human2/base.png")

	for &enemy in pool.freeDummy {
		// Note: is loadModel slow? can I load once and dup memory for every model after?
		enemy.model = loadModel(path)
		enemy.model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[1].shader = shader
		enemy.health = Health {
			max     = 15,
			current = 15,
		}
		enemy.attackCD = Timer {
			max = 2.0,
		}
		enemy.shape = .8
		enemy.animState.speed = 1
		enemy.type = dummyEnemy{}
	}

	for &enemy in pool.freeMele {
		// Note: is loadModel slow? can I load once and dup memory for every model after?
		enemy.model = loadModel(path)
		enemy.model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[1].shader = shader
		enemy.health = Health {
			max     = 4,
			current = 4,
		}
		enemy.attackCD = Timer {
			max = 2.0,
		}
		enemy.shape = .8
		enemy.animState.speed = 1
		enemy.type = meleEnemy{}
	}

	for &enemy in pool.freeRange {
		// Note: is loadModel slow? can I load once and dup memory for every model after?
		enemy.model = loadModel(path)
		enemy.model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[1].shader = shader
		enemy.health = Health {
			max     = 4,
			current = 4,
		}
		enemy.attackCD = Timer {
			max = 2.0,
		}
		enemy.shape = .8
		enemy.animState.speed = 1
		enemy.type = rangeEnemy{}
	}

	return pool
}
// ---- ---- ---- ---- Spawn ---- ---- ---- ---- 
spawnEnemyDummy :: proc(pool: ^EnemyDummyPool, pos: vec3) {
	if len(pool.freeDummy) == 0 {
		// Do nothing if there isn't space for a new one.
		return
	}

	enemy := pop(&pool.freeDummy)
	enemy.health.current = enemy.health.max
	enemy.health.hitFlash = 0
	enemy.spacial.pos = pos
	enemy.spacial.rot = f32(rl.GetRandomValue(0, 6))
	append(&pool.active, enemy)
}

spawnEnemyRange :: proc(pool: ^EnemyDummyPool, pos: vec3) {
	if len(pool.freeRange) == 0 {
		// Do nothing if there isn't space for a new one.
		return
	}

	enemy := pop(&pool.freeRange)
	enemy.health.current = enemy.health.max
	enemy.health.hitFlash = 0
	enemy.spacial.pos = pos
	enemy.spacial.rot = f32(rl.GetRandomValue(0, 6))
	append(&pool.active, enemy)
}

spawnEnemyMele :: proc(pool: ^EnemyDummyPool, pos: vec3) {
	if len(pool.freeMele) == 0 {
		// Do nothing if there isn't space for a new one.
		return
	}
	enemy := pop(&pool.freeMele)
	enemy.health.current = enemy.health.max
	enemy.health.hitFlash = 0
	enemy.spacial.pos = pos
	enemy.spacial.rot = f32(rl.GetRandomValue(0, 6))
	append(&pool.active, enemy)
}

// ---- ---- ---- ---- Despawn ---- ---- ---- ---- 
despawnAllEnemies :: proc(pool: ^EnemyDummyPool) {
	for enemy, ii in pool.active {
		switch v in enemy.type {
		case meleEnemy:
			append(&pool.freeMele, enemy)
		case rangeEnemy:
			append(&pool.freeRange, enemy)
		case dummyEnemy:
			append(&pool.freeDummy, enemy)
		}
	}
	clear(&pool.active)
}

// ---- ---- ---- ---- Update ---- ---- ---- ---- 
updateEnemies :: proc(
	enemies: ^EnemyDummyPool,
	player: Player,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	for &enemy, index in enemies.active {
		switch &s in enemy.type {
		case meleEnemy:
			updateEnemyMele(&enemy, player, enemies, objs, pool)
		case rangeEnemy:
			updateEnemyRange(&enemy, player, enemies, objs, pool)
		case dummyEnemy:
			updateEnemyDummy(&enemy, player, enemies, objs, pool)
		}
	}
}

// ---- ---- ---- ---- Health ---- ---- ---- ---- 
updateEnemyHealth :: proc(enemies: ^$T) {
	// Loop in reverse and swap with last element on remove
	#reverse for &enemy, index in enemies.active {
		updateHealth(&enemy)
		if enemy.health.current <= 0 {
			unordered_remove(&enemies.active, index)
		}
	}
}

// ---- ---- ---- ---- Animations ---- ---- ---- ---- 
updateEnemyAnimations :: proc(enemies: $T) {
	for &enemy, index in enemies.active {
		updateAnimation(enemy.model, &enemy.animState, enemies.animSet)
	}
}

// ---- ---- ---- ---- Draw ---- ---- ---- ---- 
drawEnemies :: proc(enemies: ^EnemyDummyPool) {
	for enemy in enemies.active {
		drawEnemy(enemy)
	}
}

drawEnemy :: proc(enemy: Enemy) {
	// Apply hit flash
	drawHitFlash(enemy.model, enemy.health)

	rl.DrawModelEx(enemy.model, enemy.spacial.pos, UP, rl.RAD2DEG * enemy.spacial.rot, 3, rl.WHITE)

	// Collision shape
	// rl.DrawCylinderWires(enemy.pos, enemy.shape.(Sphere), enemy.shape.(Sphere), 2, 10, rl.BLACK)
}
