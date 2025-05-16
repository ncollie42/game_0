package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

Enemy :: struct {
	model:              rl.Model,
	animState:          AnimationState,
	using spacial:      Spacial,
	using health:       Health,
	dmgIndicatorOffset: vec3, // Offset over pos - TODO: move out with animSet | it's shared.
	attackCD:           Timer, // CD for attacking
	type:               EnemyTypes,
	size:               f32,
}

// TODO: swap with the enum
EnemyTypes :: union {
	MeleEnemy,
	RangeEnemy,
	DummyEnemy,
	GiantEnemy,
	ThornEnemy,
	MonolithEnemy,
}

Spawning :: struct {
	enemy:    Enemy,
	pos:      vec3,
	duration: f32,
}

EnemyPool :: struct {
	spawning:     [dynamic]Spawning,
	active:       [dynamic]Enemy,
	freeDummy:    [dynamic]Enemy,
	animSetDummy: AnimationSet,
	freeMele:     [dynamic]Enemy,
	animSetMele:  AnimationSet,
	freeRange:    [dynamic]Enemy,
	animSetRange: AnimationSet,
	freeGiant:    [dynamic]Enemy,
	animSetGiant: AnimationSet,
	freeThorn:    [dynamic]Enemy,
	freeMonolith: [dynamic]Enemy,
}

EnemyState :: union {
	EnemyStateIdle,
	EnemyStateBase,
	EnemyPushback,
	EnemyAttack,
}

EnemyStateBase :: struct {}
EnemyAttack :: struct {
	animation:    ANIMATION_NAMES,
	animSpeed:    f32,
	action_frame: i32,
	hasTriggered: bool,
}
// TODO: change to 'hurt'
EnemyPushback :: struct {
	animation: ENEMY,
	animSpeed: f32,
}


SpawningTexture: rl.Texture2D

// ---- ---- ---- ---- Init ---- ---- ---- ---- 
enemyPoolSize := 100
ENEMY_CD_ATTACK_VARIANT: f32 = 1
initEnemyDummies :: proc() -> EnemyPool {
	// It looks like we can share the same shader for all enemies
	// shader := rl.LoadShader(nil, "shaders/grayScale.fs")
	shader := rl.LoadShader(nil, "shaders/flash.fs")
	SpawningTexture = loadTexture("resources/mark_2.png")

	pool := EnemyPool {
		spawning     = make([dynamic]Spawning, 0, 0),
		active       = make([dynamic]Enemy, 0, 0),
		freeDummy    = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
		freeMele     = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
		freeRange    = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
		freeGiant    = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
		freeThorn    = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
		freeMonolith = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
	}

	// -------- Dummy -------- 
	// Texture + Model + animation
	modelPath: cstring = "resources/golem_large/base.m3d"
	texturePath: cstring = "resources/golem_large/base.png"

	pool.animSetDummy = loadM3DAnimationsWithRootMotion(modelPath)
	texture := loadTexture(texturePath)

	for &enemy in pool.freeDummy {
		// Note: is loadModel slow? can I load once and dup memory for every model after?
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max = 15,
		}
		enemy.attackCD = Timer {
			max = 2.0,
		}
		enemy.shape = .8
		enemy.animState.speed = 1
		enemy.type = DummyEnemy{}
		enemy.size = 5
		enemy.dmgIndicatorOffset = {0, 2, 0}
	}

	// -------- Mele -------- 
	modelPath = "resources/golem_small_mele/base.m3d"
	texturePath = "resources/golem_small_mele/base.png"

	pool.animSetMele = loadM3DAnimationsWithRootMotion(modelPath)
	texture = loadTexture(texturePath)

	for &enemy in pool.freeMele {
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max = 2,
		}
		enemy.attackCD = Timer {
			left = 5.0,
			max  = 10.0,
		}
		enemy.shape = .8
		enemy.animState.current = ENEMY.idle
		enemy.animState.speed = 1
		enemy.type = MeleEnemy{}
		enemy.size = 4
		enemy.dmgIndicatorOffset = {0, 2, 0}
	}


	// -------- Range -------- 
	modelPath = "resources/golem_small_range/base.m3d"
	texturePath = "resources/golem_small_range/base.png"

	pool.animSetRange = loadM3DAnimationsWithRootMotion(modelPath)
	texture = loadTexture(texturePath)

	for &enemy in pool.freeRange {
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max = 4,
		}
		enemy.attackCD = Timer {
			max = 8.0,
		}
		enemy.shape = .8
		enemy.animState.current = ENEMY.idle
		enemy.animState.speed = 1
		enemy.type = RangeEnemy{}
		enemy.size = 4
		enemy.dmgIndicatorOffset = {0, 2.5, 0}
	}

	// -------- Giant -------- 
	modelPath = "resources/golem_large/base.m3d"
	texturePath = "resources/golem_large/base.png"

	pool.animSetGiant = loadM3DAnimationsWithRootMotion(modelPath)
	texture = loadTexture(texturePath)

	for &enemy in pool.freeGiant {
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max = 4,
		}
		enemy.attackCD = Timer {
			left = 5.0,
			max  = 10.0,
		}
		enemy.shape = .8 // TODO: change, but also add attack range
		enemy.animState.speed = 1
		enemy.type = GiantEnemy{}
		enemy.size = 3
		enemy.dmgIndicatorOffset = {0, 2, 0}
	}

	// -------- Thorn -------- 
	modelPath = "resources/thorn/base.m3d"
	texturePath = "resources/thorn/base.png"
	texture = loadTexture(texturePath)

	for &enemy in pool.freeThorn {
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max = 2,
		}
		enemy.attackCD = Timer {
			left = .5,
			max  = .5,
		}
		enemy.shape = .8 // TODO: change, but also add attack range
		enemy.type = ThornEnemy{}
		enemy.size = 3
		enemy.dmgIndicatorOffset = {0, 3.2, 0}
	}

	// -------- Monolith -------- 
	modelPath = "resources/monolith/base.m3d"
	texturePath = "resources/monolith/base3.png"
	texture = loadTexture(texturePath)

	for &enemy in pool.freeMonolith {
		enemy.model = loadModel(modelPath)
		count := enemy.model.materialCount - 1
		enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[count].shader = shader
		enemy.health = Health {
			max = 15,
		}
		enemy.attackCD = Timer {
			left = .5,
			max  = .5,
		}
		enemy.shape = .8 // TODO: change, but also add attack range
		enemy.type = MonolithEnemy{}
		enemy.size = 3
		enemy.dmgIndicatorOffset = {0, 3.2, 0}
	}

	return pool
}
// ---- ---- ---- ---- Spawn ---- ---- ---- ---- 
spawnEnemyDummy :: proc(pool: ^EnemyPool, pos: vec3) {
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

spawnEnemyRange :: proc(pool: ^EnemyPool, pos: vec3) {
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

spawnEnemyMele :: proc(pool: ^EnemyPool, pos: vec3) {
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

spawnEnemyGiant :: proc(pool: ^EnemyPool, pos: vec3) {
	if len(pool.freeGiant) == 0 {
		// Do nothing if there isn't space for a new one.
		return
	}
	enemy := pop(&pool.freeGiant)
	enemy.health.current = enemy.health.max
	enemy.health.hitFlash = 0
	enemy.spacial.pos = pos
	enemy.spacial.rot = f32(rl.GetRandomValue(0, 6))
	append(&pool.active, enemy)
}

spawnEnemy :: proc(pool: ^EnemyPool, pos: vec3, type: EnemyType) {
	freePool: ^[dynamic]Enemy
	switch type {
	case .Mele:
		freePool = &pool.freeMele
	case .Giant:
		freePool = &pool.freeGiant
	case .Dummy:
		freePool = &pool.freeDummy
	case .Range:
		freePool = &pool.freeRange
	case .Thorn:
		freePool = &pool.freeThorn
	case .Monolith:
		freePool = &pool.freeMonolith
	}
	if len(freePool^) == 0 {
		// Do nothing if there isn't space for a new one.
		return
	}
	enemy := pop(freePool)
	enemy.health.current = enemy.health.max
	enemy.health.hitFlash = 0
	enemy.spacial.pos = pos
	// enemy.spacial.rot = f32(rl.GetRandomValue(0, 6))
	spawn := Spawning {
		enemy    = enemy,
		pos      = pos,
		duration = 1,
	}
	// append(&pool.active, enemy)
	append(&pool.spawning, spawn)
}

// ---- ---- ---- ---- Despawn ---- ---- ---- ---- 
despawnAllEnemies :: proc(pool: ^EnemyPool) {
	for enemy, ii in pool.active {
		switch v in enemy.type {
		case DummyEnemy:
			append(&pool.freeDummy, enemy)
		case MeleEnemy:
			append(&pool.freeMele, enemy)
		case RangeEnemy:
			append(&pool.freeRange, enemy)
		case GiantEnemy:
			append(&pool.freeGiant, enemy)
		case ThornEnemy:
			append(&pool.freeThorn, enemy)
		case MonolithEnemy:
			append(&pool.freeMonolith, enemy)
		}
	}
	clear(&pool.active)
}

// ---- ---- ---- ---- Update ---- ---- ---- ---- 
updateEnemies :: proc(
	enemies: ^EnemyPool,
	player: Player,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	for &enemy, index in enemies.active {
		switch &s in enemy.type {
		case DummyEnemy:
			updateEnemyDummy(&enemy, player, enemies, objs, pool)
		case MeleEnemy:
			updateEnemyMele(&enemy, player, enemies, objs, pool)
		case RangeEnemy:
			updateEnemyRange(&enemy, player, enemies, objs, pool)
		case GiantEnemy:
			updateEnemyGiant(&enemy, player, enemies, objs, pool)
		case ThornEnemy:
			updateEnemyThorn(&enemy, player, enemies, objs, pool)
		case MonolithEnemy:
			updateEnemyMonolith(&enemy, player, enemies, objs, pool)
		}
	}
}

updateSpawningEnemies :: proc(enemies: ^EnemyPool) {
	// Loop in reverse and swap with last element on remove
	#reverse for &spawn, index in enemies.spawning {
		spawn.duration -= getDelta()
		if spawn.duration >= 0 {
			continue
		}
		append(&enemies.active, spawn.enemy)
		unordered_remove(&enemies.spawning, index)
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
updateEnemyAnimations :: proc(enemies: ^EnemyPool) {
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
		case GiantEnemy:
			animSet = enemies.animSetGiant
		case ThornEnemy:
			continue
		case MonolithEnemy:
			continue
		case:
			panic("Not set type")
		}
		updateAnimation(enemy.model, &enemy.animState, animSet)
	}
}

// ---- ---- ---- ---- Draw ---- ---- ---- ---- 
drawEnemies :: proc(enemies: ^EnemyPool, camera: ^rl.Camera) {
	for enemy in enemies.active {
		drawEnemy(enemy, camera)
	}


	// TODO: move to its on func?
	scale: f32 = 1.5
	for spawn in enemies.spawning {
		// rl.DrawCube(spawn.pos, .1, .1, .1, rl.WHITE)

		// rl.DrawBillboard(camera, SpawningTexture, spawn.pos + {0, 1, 0}, 1, rl.WHITE)

		// Flat on ground
		rl.DrawBillboardPro(
			camera^,
			SpawningTexture,
			rl.Rectangle{0, 0, 64, 64},
			spawn.pos + {.5, .05, -.5} * scale, //Center and scale 
			{0, 0, 1},
			scale,
			{},
			0,
			rl.WHITE,
		)
	}
}

drawEnemy :: proc(enemy: Enemy, camera: ^rl.Camera) {
	// Apply hit flash
	drawHitFlash(enemy.model, enemy.health)

	drawShadow(enemy.model, enemy.spacial, enemy.size, camera)
	rl.DrawModelEx(
		enemy.model,
		enemy.spacial.pos,
		UP,
		rl.RAD2DEG * enemy.spacial.rot,
		enemy.size,
		rl.WHITE,
	)
	rl.EndShaderMode()
	// Damage indicator spot
	// rl.DrawCube(enemy.pos + enemy.dmgIndicatorOffset, .1, .1, .1, rl.WHITE)

	// Collision shape
	// rl.DrawCylinderWires(enemy.pos, enemy.shape.(Sphere), enemy.shape.(Sphere), 2, 10, rl.BLACK)
}
