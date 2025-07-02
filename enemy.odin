package main

import "core:fmt"
import "core:math"
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
	box:                rl.BoundingBox, //For enemy select
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
EnemyDead :: struct {}
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

EnemyFreeze :: struct {
	duration: f32,
	// animation: ENEMY,
	// animSpeed: f32,
}


SpawningTexture: rl.Texture2D
TargetCircleTexture: rl.Texture2D
TargetCrossTexture: rl.Texture2D

// ---- ---- ---- ---- Init ---- ---- ---- ---- 
enemyPoolSize := 100
ENEMY_CD_ATTACK_VARIANT: f32 = 1

newEnemyPools :: proc() -> EnemyPool {
	SpawningTexture = loadTexture("resources/mark_2.png")
	// TargetCircleTexture = loadTexture("resources/png/target_circle.png")
	// TargetCrossTexture = loadTexture("resources/png/target_lock.png")

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

	loadEnemies :: proc(
		pool: [dynamic]Enemy,
		set: ^AnimationSet,
		modelPath: cstring,
		texturePath: cstring,
	) {
		if set != nil {
			set^ = loadM3DAnimationsWithRootMotion(modelPath)
		}
		texture := loadTexture(texturePath)

		for &enemy in pool {
			// Note: is loadModel slow? can I load once and dup memory for every model after?
			enemy.model = loadModel(modelPath)
			count := enemy.model.materialCount - 1
			enemy.model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
			enemy.model.materials[count].shader = Shaders[.Flash]
		}
	}
	// -------- Dummy -------- 
	loadEnemies(
		pool.freeDummy,
		&pool.animSetDummy,
		"resources/golem_large/base.m3d",
		"resources/golem_large/base.png",
	)

	// -------- Mele -------- 
	loadEnemies(
		pool.freeMele,
		&pool.animSetMele,
		"resources/golem_small_mele/base.m3d",
		"resources/golem_small_mele/base.png",
	)

	// -------- Range -------- 
	loadEnemies(
		pool.freeRange,
		&pool.animSetRange,
		"resources/golem_small_range/base.m3d",
		"resources/golem_small_range/base.png",
	)

	// -------- Giant -------- 
	loadEnemies(
		pool.freeGiant,
		&pool.animSetGiant,
		"resources/golem_large/base.m3d",
		"resources/golem_large/base.png",
	)

	// -------- Thorn -------- 
	loadEnemies(pool.freeThorn, nil, "resources/thorn/base.m3d", "resources/thorn/base.png")

	// -------- Monolith -------- 
	loadEnemies(
		pool.freeMonolith,
		nil,
		"resources/monolith/base.m3d",
		"resources/monolith/base2.png",
	)

	initEnemyPools(&pool)
	return pool
}

initEnemyPools :: proc(pool: ^EnemyPool) {

	initFreePool :: proc(ref: Enemy, pool: [dynamic]Enemy) {
		for &enemy in pool {
			enemy.animState = ref.animState
			enemy.health = ref.health
			enemy.attackCD = ref.attackCD
			enemy.shape = .8 // TODO: change, but also add attack range
			enemy.type = ref.type
			enemy.size = ref.size
			enemy.box = ref.box
			enemy.dmgIndicatorOffset = ref.dmgIndicatorOffset
		}
	}
	// -------- Dummy -------- 

	dummy := Enemy {
		health = {max = 15},
		attackCD = {max = 2},
		shape = .1,
		type = DummyEnemy{},
		animState = {speed = 1, current = ENEMY.idle},
		size = 5,
		box = rl.BoundingBox{{-.2, 0, -.2}, {.2, .5, .2}},
		dmgIndicatorOffset = {0, 5, 0},
	}
	initFreePool(dummy, pool.freeDummy)

	// -------- Mele -------- 

	mele := Enemy {
		health = {max = 6},
		attackCD = {left = 5.0, max = 10.0},
		shape = .8, // TODO: change, but also add attack range
		type = MeleEnemy{},
		animState = {speed = 1, current = ENEMY.idle},
		size = 4,
		box = rl.BoundingBox{{-.2, 0, -.2}, {.2, .4, .2}},
		dmgIndicatorOffset = {0, 2, 0},
	}
	initFreePool(mele, pool.freeMele)

	// -------- Range -------- 

	range := Enemy {
		health = {max = 4},
		attackCD = {max = 8.0},
		shape = .8, // TODO: change, but also add attack range
		type = RangeEnemy{},
		animState = {speed = 1, current = ENEMY.idle},
		size = 4,
		box = rl.BoundingBox{{-.2, 0, -.2}, {.2, .5, .2}},
		dmgIndicatorOffset = {0, 2.5, 0},
	}
	initFreePool(range, pool.freeRange)

	// -------- Giant -------- 

	giant := Enemy {
		health = {max = 8},
		attackCD = {left = 5.0, max = 10.0},
		shape = .8, // TODO: change, but also add attack range
		type = GiantEnemy{},
		size = 3,
		box = rl.BoundingBox{{-.3, 0, -.3}, {.3, .7, .3}},
		dmgIndicatorOffset = {0, 2, 0},
	}
	initFreePool(giant, pool.freeGiant)

	// -------- Thorn -------- 
	thorn := Enemy {
		health = {max = 4},
		attackCD = {left = .5, max = .5},
		shape = .8, // TODO: change, but also add attack range
		type = ThornEnemy{},
		size = 3,
		box = rl.BoundingBox{{-.3, 0, -.3}, {.3, .7, .3}},
		dmgIndicatorOffset = {0, 3.2, 0},
	}
	initFreePool(thorn, pool.freeThorn)

	// -------- Monolith -------- 

	monolith := Enemy {
		health = {max = 25},
		attackCD = {left = .5, max = .5},
		shape = .8, // TODO: change, but also add attack range
		type = MonolithEnemy{},
		size = 3,
		box = rl.BoundingBox{{-.3, 0, -.3}, {.3, 1, .3}},
		dmgIndicatorOffset = {0, 3.2, 0},
	}
	initFreePool(monolith, pool.freeMonolith)
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

spawnEnemy :: proc(pool: ^EnemyPool, pos: vec3, type: EnemyType, now: bool) {
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

	if now {
		append(&pool.active, enemy)
	} else {
		spawn := Spawning {
			enemy    = enemy,
			pos      = pos,
			duration = 1,
		}
		append(&pool.spawning, spawn)
	}
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
	gpoints: ^[dynamic]GravityPoint,
	pool: ^AbilityPool,
) {
	for &enemy, index in enemies.active {
		switch &s in enemy.type {
		case DummyEnemy:
			updateEnemyDummy(&enemy, player, enemies, objs, pool)
		case MeleEnemy:
			updateEnemyMele(&enemy, player, enemies, objs, gpoints, pool)
		case RangeEnemy:
			updateEnemyRange(&enemy, player, enemies, objs, gpoints, pool)
		case GiantEnemy:
			updateEnemyGiant(&enemy, player, enemies, objs, gpoints, pool)
		case ThornEnemy:
			updateEnemyThorn(&enemy, pool)
		case MonolithEnemy:
			updateEnemyMonolith(&enemy)
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
updateEnemyHealth :: proc(enemies: ^$T, pickup: ^Pickup, player: ^Player) {
	// Loop in reverse and swap with last element on remove
	#reverse for &enemy, index in enemies.active {
		updateHealth(&enemy)
		if enemy.health.current > 0 do continue
		// enterEnemyMeleState(&enemy, EnemyDead{}) -> TODO: Animation on death
		spawnPickup(pickup, enemy.pos, normalize(enemy.pos - player.pos))
		unordered_remove(&enemies.active, index)
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
drawSelectedEnemy :: proc(enemies: ^EnemyPool, camera: ^rl.Camera) {
	hit := getEnemyHitResult(enemies, camera)
	if !hit.hit do return
	red := colorToVec4(color27)
	drawOutline(hit.enemy.model, hit.enemy.spacial, hit.enemy.size, camera, red)
}

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
	drawOutline(enemy.model, enemy.spacial, enemy.size, camera, {0, 0, 0, 1})
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

// ----------------------------- Enemy Ray hit check -----------------------------

performEnemyHitTest :: proc(enemies: ^EnemyPool, camera: ^rl.Camera, size: f32) -> EnemyHitResult {
	hit: bool
	enemyPos: vec3
	enemyPosOverhead: vec3
	distance: f32 = math.F32_MAX // Set high for now
	count := 0
	ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), camera^)
	ee: ^Enemy
	for &enemy in enemies.active {
		box := getModelBoundingBox(&enemy, enemy.size * size)
		hitInfo := rl.GetRayCollisionBox(ray, box)
		// rl.DrawBoundingBox(box, rl.BLUE) // DEBUG

		if !hitInfo.hit do continue
		count += 1
		hit = true

		// rl.DrawBoundingBox(box, rl.GREEN) // DEBUG

		if hitInfo.distance >= distance do continue
		distance = hitInfo.distance
		enemyPosOverhead = enemy.pos + enemy.dmgIndicatorOffset
		enemyPos = enemy.pos
		ee = &enemy
	}
	hitInfo := EnemyHitResult{}
	if !hit do return hitInfo
	hitInfo.hit = true
	hitInfo.pos = enemyPos
	hitInfo.posOverhead = enemyPosOverhead
	hitInfo.multipleHits = count > 1
	hitInfo.enemy = ee
	return hitInfo
}

getModelBoundingBox :: proc(enemy: ^Enemy, size: f32) -> rl.BoundingBox {
	modelMatrix := getSpacialMatrixNoRot(enemy.spacial, size)
	box := rl.BoundingBox{}
	box.min = rl.Vector3Transform(enemy.box.min, modelMatrix)
	box.max = rl.Vector3Transform(enemy.box.max, modelMatrix)
	return box
}

getEnemyHitResult :: proc(enemies: ^EnemyPool, camera: ^rl.Camera) -> EnemyHitResult {
	// TODO: Add priority on enemies - lower on monolith?
	// First try with a wider hitbox
	result := performEnemyHitTest(enemies, camera, 1.5)

	// If we got multiple hits with the wide hitbox, try a more precise one
	if result.hit && result.multipleHits {
		preciseResult := performEnemyHitTest(enemies, camera, 1.2)
		// Only use the precise result if it actually hit something
		if preciseResult.hit {
			// result.enemy.targeted = false // reset the targeted value
			return preciseResult
		}
	}

	return result
}

EnemyHitResult :: struct {
	hit:          bool,
	pos:          vec3,
	posOverhead:  vec3,
	multipleHits: bool,
	enemy:        ^Enemy, // Only use imediately DONT save the pointer, maybe later when we use reference.
}

// 1. Enemy Attack Assist | on player get {bool | POS}
// 2. Dash at pos    | {bool | POS}
// 3. Show lock on while 'blocking'
// Do we add field on enemy? or check twice per loop
//  Check if within radious of mouse 1. Check if overlapping
