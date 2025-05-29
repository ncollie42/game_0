package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/rand"
import rl "vendor:raylib"

Spawner :: struct {
	// AnimatedModel :: create this truct
	model:         rl.Model,
	animState:     AnimationState,
	using spacial: Spacial,
	using health:  Health,
	state:         SpawnerState,
	target:        vec3,
	duration:      f32, // Till next phase
}

EnemySpanwerPool :: struct {
	animSet: AnimationSet, // Not used for now
	active:  [dynamic]Spawner,
	free:    [dynamic]Spawner,
}

SpawnerState :: union {
	SpawnerBase,
	SpawnerSpawning,
}
SpawnerBase :: struct {}
SpawnerSpawning :: struct {
	cd: f32,
}

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
spanwerPoolSize := 20
initEnemySpawner :: proc() -> EnemySpanwerPool {

	pool := EnemySpanwerPool {
		active = make([dynamic]Spawner, 0, 10),
		free   = make([dynamic]Spawner, 10, 10),
	}

	// path: cstring = "/home/nico/Downloads/Human2/base.m3d"
	// pool.animSet = loadModelAnimations(path)
	// texture := loadTexture("/home/nico/Downloads/Human2/base.png")

	mesh := rl.GenMeshCube(2, 2, 2)
	model := rl.LoadModelFromMesh(mesh)
	checked := rl.GenImageChecked(4, 4, 1, 1, blue_1, blue_4)
	texture := rl.LoadTextureFromImage(checked)

	for &enemy in pool.free {
		// enemy.model = loadModel(path)
		enemy.model = rl.LoadModelFromMesh(mesh)
		//change index 1 when loading real model
		enemy.model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[0].shader = Shaders[.Flash]
		enemy.health = Health {
			max     = 2,
			current = 2,
		}
		enemy.shape = .8
	}
	return pool
}

// ---- Spawn
spawnEnemySpawner :: proc(pool: ^EnemySpanwerPool) {
	if len(pool.free) == 0 {
		// Do nothing if there isn't space for a new one.
		return
	}

	spawn := getPointAtEdgeOfMap()
	x := noise.noise_2d(1, {rl.GetTime(), rl.GetTime()})
	z := noise.noise_2d(2, {rl.GetTime(), rl.GetTime()})
	target := rand.float32_range(3, 6) * normalize({x, 0, z})

	enemy := pop(&pool.free)
	enemy.spacial.pos = spawn
	enemy.spacial.rot = f32(rl.GetRandomValue(0, 6))
	enemy.target = target
	enemy.health.current = enemy.health.max
	append(&pool.active, enemy)
}

// Get random point at edge of map
getPointAtEdgeOfMap :: proc() -> vec3 {
	x := noise.noise_2d(0, {rl.GetTime(), rl.GetTime()})
	z := noise.noise_2d(1, {rl.GetTime(), rl.GetTime()})
	return MapGround.shape.(Sphere) * normalize({x, 0, z})
}

getSafePointInGrid :: proc(enemies: ^EnemyPool, player: ^Player) -> vec3 {
	// upper bound check
	for ii in 0 ..< 15 {
		pos := getPointInGrid(ii, 1.5)
		if rl.Vector3DistanceSqrt(player.pos, pos) < 5 do continue // too close to player

		safe := !isUnsafeSpawn(enemies, pos)
		if safe do return pos
	}
	fmt.println("Could not find safe spawn")
	return getPointAtEdgeOfMap()
}

// Get randomPointInGridWithoutOverlap
getPointInGrid :: proc(seed: int, grid: f32) -> vec3 {
	x := rand.float32_range(-1, 1)
	z := rand.float32_range(-1, 1)
	dst := rand.float32_range(0, MapGround.shape.(Sphere))
	return roundVec((dst * vec3{x, 0, z}) / grid) * grid
}

getRandomPoint :: proc() -> vec3 {
	x := rand.float32_range(-1, 1)
	z := rand.float32_range(-1, 1)
	dst := rand.float32_range(0, MapGround.shape.(Sphere))
	return {x, 0, z} * dst
}

// We are using a check against thorn and monolith. In the future we might want to swap safe search with some
// different data structure that keeps track of whats placed in a grid? so we don't have to keep sampling.
isUnsafeSpawn :: proc(enemies: ^EnemyPool, pos: vec3) -> bool {
	for enemy in enemies.active {
		#partial switch v in enemy.type {
		case ThornEnemy:
			if enemy.pos == pos do return true
		case MonolithEnemy:
			if enemy.pos == pos do return true
		}
	}
	for spawn in enemies.spawning {
		#partial switch v in spawn.enemy.type {
		case ThornEnemy:
			if spawn.pos == pos do return true
		case MonolithEnemy:
			if spawn.pos == pos do return true
		}
	}
	return false
}

roundVec :: proc(vec: vec3) -> vec3 {
	return vec3{math.round(vec.x), math.round(vec.y), math.round(vec.z)}
}
// spapToGrid :: proc(pos: vec3, size: f32) {
// 	pos = math.round(pos / size) * size

// }
// // For half-grid snapping
// Vector2 SnapToHalfGrid(Vector2 position, float gridSize) {
//     Vector2 result;
//     result.x = roundf(position.x / (gridSize * 0.5f)) * (gridSize * 0.5f);
//     result.y = roundf(position.y / (gridSize * 0.5f)) * (gridSize * 0.5f);
//     return result;
// }
// ---- Despawn

// despawnAllEnemies :: proc(pool: ^EnemySpanwerPool) {
// 	for enemy, ii in pool.active {
// 		append(&pool.free, enemy)
// 	}
// 	clear(&pool.active)
// }


despawnSpawner :: proc(pool: ^EnemySpanwerPool, index: int) {
	// :: Swap
	// Add to Free
	append(&pool.free, pool.active[index])
	// Remove from active
	// pool.active[index] = pop(&pool.active)
	unordered_remove(&pool.active, index)
}

// ---- Update
updateEnemySpanwers :: proc(
	spawners: ^EnemySpanwerPool,
	enemies: ^EnemyPool,
	objs: ^[dynamic]EnvObj,
) {
	for &spawner, index in spawners.active {
		updateSpawner(&spawner, enemies)

		updateHealth(&spawner)
		if spawner.health.current <= 0 {
			despawnSpawner(spawners, index)
		}
	}
}

updateSpawner :: proc(spawner: ^Spawner, enemies: ^EnemyPool) {
	spawner.duration -= getDelta()
	switch &s in spawner.state {
	case SpawnerBase:
		// TOWARDS center
		spawner.pos += normalize(spawner.target - spawner.pos) * getDelta()
		if spawner.duration <= 0 {
			forward := getForwardPoint(spawner) * 3
			spawner.state = SpawnerSpawning{}
			spawner.duration = 5
			spawnEnemyMele(enemies, spawner.pos + forward)
			spawnEnemyMele(enemies, spawner.pos + forward)
			spawnEnemyMele(enemies, spawner.pos + forward)
			spawnEnemyRange(enemies, spawner.pos + forward)
		}
	case SpawnerSpawning:
		if spawner.duration <= 0 {
			spawner.state = SpawnerBase{}
			spawner.duration = 5
		}
	// s.cd -= getDelta()
	// if s.cd <= 0 {
	// 	spawnEnemyMele(enemies, spawner.pos)
	// 	spawnEnemyRange(enemies, spawner.pos)
	// 	s.cd = 5
	// }
	case:
		spawner.state = SpawnerBase{}
		spawner.duration = 1
	}
	assert(spawner.duration > 0, "Something bad happened")
}

// boidSeperation2 :: proc(boid: ^Enemy, enemies: ^EnemyDummyPool) -> vec3 {
// 	boid.inRangeSeperation = false
// 	force := vec3{}
// 	for &other, index in enemies.active {
// 		if &other == boid {continue} 	// Skip self

// 		toNeighbor := other.pos - boid.pos
// 		dist := linalg.length(toNeighbor)

// 		if dist > boid.range {continue} 	// Outside of range 

// 		forward := directionFromRotation(boid.rot)
// 		toNeighbor = normalize(toNeighbor)

// 		if linalg.dot(forward, toNeighbor) <= -.5 {continue} 	// Behind unit; cos(120) == -.5

// 		boid.inRangeSeperation = true

// 		// Get a vector pointing AWAY from the neighbor
// 		seperation := boid.pos - other.pos
// 		seperation = normalize(seperation)

// 		dist = clamp(dist, .01, 1) // Prevent 0 when 100% ontop
// 		// Weigh by distance (closer toNeighbor have more influence)
// 		force += seperation * (1.0 / dist)
// 	}

// 	return force
// }


// // Alignment usually uses a larget distance than seperation
// alignmentRange: f32 = 1.75
// cohesionRange: f32 = 2.25
// boidAlignment :: proc(boid: ^Enemy, enemies: ^EnemyDummyPool) -> vec3 {
// 	boid.inRangeAlign = false
// 	force := vec3{}
// 	for &other in enemies.active {
// 		if &other == boid {continue} 	// Skip self

// 		toNeighbor := other.pos - boid.pos
// 		distance := linalg.length(toNeighbor)

// 		if distance > (boid.range * alignmentRange) {return {}} 	// Outside of range 

// 		forward := directionFromRotation(boid.rot)
// 		toNeighbor = normalize(toNeighbor)
// 		if linalg.dot(forward, toNeighbor) <= -.5 {return {}} 	// Behind unit; cos(120) == -.5
// 		boid.inRangeAlign = true

// 		// Add neighbor's forward vector
// 		otherForward := directionFromRotation(other.rot)
// 		force += otherForward
// 	}

// 	return force
// }


// boidCohesion :: proc(boid: ^Enemy, enemies: ^EnemyDummyPool) -> vec3 {
// 	boid.inRangeCohe = false
// 	centerPos := vec3{}
// 	count := 0
// 	for &other in enemies.active {
// 		if &other == boid {continue} 	// Skip self

// 		toNeighbor := other.pos - boid.pos
// 		dist := linalg.length(toNeighbor)

// 		if dist >= boid.range * cohesionRange {continue} 	// Outside of range 
// 		centerPos += other.pos // TODO: add ratio of how close to group?
// 		count += 1
// 	}

// 	if count <= 0 {return {}}
// 	boid.inRangeCohe = true

// 	centerPos = centerPos / f32(count)
// 	boid.centertarget = centerPos
// 	return normalize(centerPos - boid.pos)
// }

// // Update Funcs


// // ------ Eneter State
// enterEnemyState :: proc(enemy: ^Enemy, state: EnemyState) {
// 	enemy.animState.duration = 0
// 	enemy.state = state
// 	switch &s in enemy.state {
// 	case EnemyStateBase:
// 		enemy.animState.speed = 0.5
// 		enemy.animState.current = SKELE.idle
// 	case EnemyAttack1:
// 		// Face player
// 		enemy.animState.speed = s.animSpeed
// 		enemy.animState.current = s.animation
// 	case EnemyPushback:
// 		// TODO: update facing direction
// 		enemy.animState.speed = s.animSpeed
// 		enemy.animState.current = s.animation
// 	case EnemyHurt:
// 		// TODO: update facing direction
// 		enemy.animState.speed = s.animSpeed
// 		enemy.animState.current = s.animation
// 	}
// 	//TODO: default case
// }

// ---- Draw
drawEnemySpanwers :: proc(enemies: ^EnemySpanwerPool) {
	for enemy in enemies.active {
		drawEnemySpawner(enemy)
	}
}

drawEnemySpawner :: proc(enemy: Spawner) {
	// Apply hit flash
	drawHitFlash(enemy.model, enemy.health)

	rl.DrawModelEx(
		enemy.model,
		enemy.spacial.pos + {0, 2, 0},
		UP,
		rl.RAD2DEG * enemy.spacial.rot,
		1,
		rl.WHITE,
	)
}
