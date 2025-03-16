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
		MeleEnemy,
		RangeEnemy,
		DummyEnemy,
	},
	size:          f32,
}

EnemyDummyPool :: struct {
	active:       [dynamic]Enemy,
	freeDummy:    [dynamic]Enemy,
	animSetDummy: AnimationSet,
	freeMele:     [dynamic]Enemy,
	animSetMele:  AnimationSet,
	freeRange:    [dynamic]Enemy,
	animSetRange: AnimationSet,
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
	action_frame: i32,
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
enemyPoolSize := 100
ENEMY_CD_ATTACK_VARIANT: f32 = 1
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
	// modelPath: cstring = "/home/nico/Downloads/Human2/base.m3d"
	// texturePath := loadTexture("/home/nico/Downloads/Human2/base.png")

	// modelPath: cstring = "resources/Human2/base.m3d"
	// texturePath: cstring = "resources/Human2/base.png"

	// modelPath: cstring = "/home/nico/Downloads/golem_small_round/base.m3d"
	// texturePath: cstring = "/home/nico/Downloads/golem_small_round/95_p2.png"

	// -------- Mele -------- 
	// Texture + Model + animation
	modelPath: cstring = "resources/golem_large/base.m3d"
	texturePath: cstring = "resources/golem_large/base.png"
	// pool.animSet = loadModelAnimations(modelPath)
	pool.animSetDummy = loadM3DAnimationsWithRootMotion(modelPath)
	texture := loadTexture(texturePath)

	for &enemy in pool.freeDummy {
		// Note: is loadModel slow? can I load once and dup memory for every model after?
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max     = 15,
			current = 15,
		}
		enemy.attackCD = Timer {
			max = 2.0,
		}
		enemy.shape = .8
		enemy.animState.speed = 1
		enemy.type = DummyEnemy{}
		enemy.size = 3
	}

	// -------- Mele -------- 
	// Texture + Model + animation
	modelPath = "resources/golem_small_mele/base.m3d"
	texturePath = "resources/golem_small_mele/base.png"
	// pool.animSet = loadModelAnimations(modelPath)
	pool.animSetMele = loadM3DAnimationsWithRootMotion(modelPath)
	texture = loadTexture(texturePath)

	for &enemy in pool.freeMele {
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max     = 4,
			current = 4,
		}
		enemy.attackCD = Timer {
			max = 5.0,
		}
		enemy.shape = .8
		enemy.animState.speed = 1
		enemy.type = MeleEnemy{}
		enemy.size = 3
	}


	// -------- Range -------- 
	// Texture + Model + animation
	modelPath = "resources/golem_small_range/base.m3d"
	texturePath = "resources/golem_small_range/base.png"
	// pool.animSet = loadModelAnimations(modelPath)
	pool.animSetRange = loadM3DAnimationsWithRootMotion(modelPath)
	texture = loadTexture(texturePath)

	for &enemy in pool.freeRange {
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max     = 4,
			current = 4,
		}
		enemy.attackCD = Timer {
			max = 8.0,
		}
		enemy.shape = .8
		enemy.animState.speed = 1
		enemy.type = RangeEnemy{}
		enemy.size = 2
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
		case MeleEnemy:
			append(&pool.freeMele, enemy)
		case RangeEnemy:
			append(&pool.freeRange, enemy)
		case DummyEnemy:
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
		case MeleEnemy:
			updateEnemyMele(&enemy, player, enemies, objs, pool)
		case RangeEnemy:
			updateEnemyRange(&enemy, player, enemies, objs, pool)
		case DummyEnemy:
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
updateEnemyAnimations :: proc(enemies: ^EnemyDummyPool) {
	// updateEnemyAnimations :: proc(enemies: $T) {
	for &enemy, index in enemies.active {
		animSet: AnimationSet
		switch &s in enemy.type {
		case DummyEnemy:
			animSet = enemies.animSetDummy
		case MeleEnemy:
			animSet = enemies.animSetMele
		case RangeEnemy:
			animSet = enemies.animSetRange
		}
		updateAnimation(enemy.model, &enemy.animState, animSet)
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

	rl.DrawModelEx(
		enemy.model,
		enemy.spacial.pos,
		UP,
		rl.RAD2DEG * enemy.spacial.rot,
		enemy.size,
		rl.WHITE,
	)

	// Collision shape
	// rl.DrawCylinderWires(enemy.pos, enemy.shape.(Sphere), enemy.shape.(Sphere), 2, 10, rl.BLACK)
}
