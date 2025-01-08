package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

Enemy :: struct {
	model:             rl.Model,
	animation:         Animation,
	using spacial:     Spacial,
	using health:      Health,
	state:             EnemyState,
	// boid TODO: remove later on or move out
	range:             f32, // seprationRadius
	inRangeSeperation: bool,
	inRangeAlign:      bool,
	inRangeCohe:       bool,
	seperationDir:     vec3, // Debug view only
	alignmentDir:      vec3, // Debug view only
	target:            vec3, // Debug view only
	centertarget:      vec3, // Debug view only
	wallPoint:         vec3, // Debug view only
}

EnemyDummyPool :: struct {
	active: [dynamic]Enemy,
	free:   [dynamic]Enemy,
}

EnemyState :: union {
	EnemyStateBase,
	EnemyPushback,
	EnemyHurt,
}

EnemyStateBase :: struct {}
EnemyPushback :: struct {
	duration:  f32,
	animation: ANIMATION_NAME,
	animSpeed: f32,
}
EnemyHurt :: struct {
	duration:  f32,
	animation: ANIMATION_NAME,
	animSpeed: f32,
}

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
enemyPoolSize := 50
initEnemyDummies :: proc(path: cstring) -> EnemyDummyPool {
	// It looks like we can share the same shader for all enemies
	// shader := rl.LoadShader(nil, "shaders/grayScale.fs")
	shader := rl.LoadShader(nil, "shaders/flash.fs")

	pool := EnemyDummyPool {
		active = make([dynamic]Enemy, 0, enemyPoolSize),
		free   = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
	}

	for &enemy in pool.free {
		// Note: is loadModel slow? can I load once and dup memory for every model after?
		enemy.model = rl.LoadModel(path)
		assert(enemy.model.meshCount != 0, "No mesh")
		enemy.model.materials[1].shader = shader
		enemy.health.max = 10
		enemy.range = 1.75
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
	enemy.spacial.rot = f32(rl.GetRandomValue(0, 6))
	append(&pool.active, enemy)
}

// ---- Despawn

despawnEnemy :: proc(pool: ^EnemyDummyPool, index: int) {
	// Swap and remove last
	append(&pool.free, pool.active[index])
	pool.active[index] = pop(&pool.active)
}

// ---- Update
updateEnemyDummies :: proc(enemies: ^EnemyDummyPool, player: Player, objs: ^[dynamic]EnvObj) {
	for &enemy, index in enemies.active {
		updateDummy(&enemy, player, enemies, objs)

		updateHealth(&enemy)
		if enemy.health.current <= 0 {
			despawnEnemy(enemies, index)
		}

		updateAnimation(enemy.model, &enemy.animation, ANIMATION)
	}
}

updateDummyMovement :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyDummyPool,
	objs: ^[dynamic]EnvObj,
) {
	// target := vec3{}
	// target := directionFromRotation(enemy.rot) // forward
	target := normalize(player.pos - enemy.pos) // toward player -> Target

	// NOTE: optimization -we can use a quad tree and or move each force calculation to a different thread -> they don't have to be done sequaltially.
	seperationForce := vec3{}
	{
		{ 	// Enemy checks
			seperationForce += boidSeperation2(enemy, enemies)
		}
		{ 	// player
			seperationForce += boidSeperation(enemy, player) // Might want to  make it its own force? 
		}
		// enemy.seperationDir = seperationForce
	}
	// Env Avoidance
	clearPath := vec3{}
	{
		clearPath += findClearPath(enemy, objs)
	}
	// Alignment
	alignmentForce := vec3{}
	{
		alignmentForce += boidAlignment(enemy, enemies)
	}
	// Cohesion
	cohesionForce := vec3{}
	{
		cohesionForce += boidCohesion(enemy, enemies)
	}
	{ 	// Apply forces

		// fmt.println("b4", target, clearPath, seperationForce, alignmentForce, cohesionForce)
		target = normalize(
			(clearPath * 10) +
			(target * 1) +
			(seperationForce * .75) +
			(alignmentForce * .50) +
			(cohesionForce * .25),
		)

		enemy.target = target
		r := lookAtVec3(target, {})
		enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * ENEMY_TURN_SPEED)
		enemy.spacial.pos += directionFromRotation(enemy.rot) * getDelta() * ENEMY_SPEED

	}
}

PUSH_BACK_SPEED: f32 = 2.5
ENEMY_SPEED :: 3
ENEMY_TURN_SPEED :: 4
updateDummy :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyDummyPool,
	objs: ^[dynamic]EnvObj,
) {
	switch &s in enemy.state {
	case EnemyStateBase:
		updateDummyMovement(enemy, player, enemies, objs) // Boids

	// if in range of player attack? Idle animation and running animation
	case EnemyPushback:
		dir := getBackwardPoint(enemy)
		enemy.spacial.pos += dir * getDelta() * PUSH_BACK_SPEED

		s.duration -= getDelta()
		if s.duration <= 0 {
			enemy.state = EnemyStateBase{}
			enemy.animation.current = .IDLE
		}
	case EnemyHurt:
		s.duration -= getDelta()
		if s.duration <= 0 {
			enemy.state = EnemyStateBase{}
			enemy.animation.current = .IDLE
		}
	case:
		enemy.state = EnemyStateBase{}
		enemy.animation.current = .IDLE
	}
}

// ---- Draw
drawEnemies :: proc(enemies: ^EnemyDummyPool) {
	for enemy in enemies.active {
		drawEnemy(enemy)
	}
}

boidSeperation :: proc(boid: ^Enemy, other: Spacial) -> vec3 { 	// boidData ; spacial ; spacial
	forward := directionFromRotation(boid.rot)

	toNeighbor := other.pos - boid.pos
	dist := linalg.length(toNeighbor)

	if dist > boid.range {return {}} 	// Outside of range 
	toNeighbor = normalize(toNeighbor)

	if linalg.dot(forward, toNeighbor) <= -.5 {return {}} 	// Behind Unit 	// cos(120) == -.5

	// Get a vector pointing AWAY from the neighbor
	seperation: vec3 = boid.pos - other.pos
	seperation = normalize(seperation)

	dist = clamp(dist, .01, 1) // Prevent 0 when 100% ontop
	// Weigh by distance (closer toNeighbor have more influence)
	seperation = seperation * (1.0 / dist)
	boid.inRangeSeperation = true

	return seperation
}

boidSeperation2 :: proc(boid: ^Enemy, enemies: ^EnemyDummyPool) -> vec3 {
	boid.inRangeSeperation = false
	force := vec3{}
	for &other, index in enemies.active {
		if &other == boid {continue} 	// Skip self

		toNeighbor := other.pos - boid.pos
		dist := linalg.length(toNeighbor)

		if dist > boid.range {continue} 	// Outside of range 

		forward := directionFromRotation(boid.rot)
		toNeighbor = normalize(toNeighbor)

		if linalg.dot(forward, toNeighbor) <= -.5 {continue} 	// Behind unit; cos(120) == -.5

		boid.inRangeSeperation = true

		// Get a vector pointing AWAY from the neighbor
		seperation := boid.pos - other.pos
		seperation = normalize(seperation)

		dist = clamp(dist, .01, 1) // Prevent 0 when 100% ontop
		// Weigh by distance (closer toNeighbor have more influence)
		force += seperation * (1.0 / dist)
	}

	return force
}


// Alignment usually uses a larget distance than seperation
alignmentRange: f32 = 1.75
cohesionRange: f32 = 2.25
boidAlignment :: proc(boid: ^Enemy, enemies: ^EnemyDummyPool) -> vec3 {
	boid.inRangeAlign = false
	force := vec3{}
	for &other in enemies.active {
		if &other == boid {continue} 	// Skip self

		toNeighbor := other.pos - boid.pos
		distance := linalg.length(toNeighbor)

		if distance > (boid.range * alignmentRange) {return {}} 	// Outside of range 

		forward := directionFromRotation(boid.rot)
		toNeighbor = normalize(toNeighbor)
		if linalg.dot(forward, toNeighbor) <= -.5 {return {}} 	// Behind unit; cos(120) == -.5
		boid.inRangeAlign = true

		// Add neighbor's forward vector
		otherForward := directionFromRotation(other.rot)
		force += otherForward
	}

	return force
}


boidCohesion :: proc(boid: ^Enemy, enemies: ^EnemyDummyPool) -> vec3 {
	boid.inRangeCohe = false
	centerPos := vec3{}
	count := 0
	for &other in enemies.active {
		if &other == boid {continue} 	// Skip self

		toNeighbor := other.pos - boid.pos
		dist := linalg.length(toNeighbor)

		if dist >= boid.range * cohesionRange {continue} 	// Outside of range 
		centerPos += other.pos // TODO: add ratio of how close to group?
		count += 1
	}

	if count <= 0 {return {}}
	boid.inRangeCohe = true

	centerPos = centerPos / f32(count)
	boid.centertarget = centerPos
	return normalize(centerPos - boid.pos)
}

drawEnemy :: proc(enemy: Enemy) {
	{ 	// Apply hit flash
		// Is it slow to getShaderLocation every time, do we want to move this somewhere else?
		shader := enemy.model.materials[1].shader
		flashIndex := rl.GetShaderLocation(shader, "flash")

		data := enemy.hitFlash
		rl.SetShaderValue(shader, flashIndex, &data, .FLOAT)
	}

	rl.DrawModelEx(enemy.model, enemy.spacial.pos, UP, rl.RAD2DEG * enemy.spacial.rot, 1, rl.WHITE)

	angle120: f32 = rl.PI * 120 / 180 // 120* mirrored in both sides TODO: precompute
	lineCount: f32 = 12 // 24
	lineAngle: f32 = angle120 / lineCount

	// seperationColor := enemy.inRangeSeperation ? rl.RED : rl.GREEN
	// alignmentColor := enemy.inRangeAlign ? rl.RED : rl.GREEN
	// color := enemy.inRange ? rl.RED : rl.GREEN
	// for ii in 1 ..< lineCount {
	// 	rl.DrawLine3D(
	// 		enemy.pos,
	// 		enemy.pos + directionFromRotation(enemy.rot + lineAngle * ii) * enemy.range,
	// 		seperationColor,
	// 	)
	// 	rl.DrawLine3D(
	// 		enemy.pos,
	// 		enemy.pos + directionFromRotation(enemy.rot + lineAngle * -ii) * enemy.range,
	// 		seperationColor,
	// 	)
	// }

	// seperation
	// rl.DrawCapsule(enemy.pos, enemy.pos + enemy.seperationDir, .05, 5, 5, rl.BLUE)
	// Final forward 
	rl.DrawCapsule(enemy.pos, enemy.pos + enemy.target, .05, 5, 5, rl.PURPLE)

	// Alignment Range
	// rl.DrawSphereWires(enemy.pos, enemy.range * alignmentRange, 10, 10, alignmentColor)

	// cohesion
	// rl.DrawCube(enemy.centertarget, .2, .2, .2, rl.BLACK)

	// boxEdge?
	rl.DrawCube(enemy.wallPoint, .2, .2, .2, rl.BLACK)
}

// Update Funcs
hurtEnemy :: proc(enemy: ^Enemy, amount: f32) {
	hurt(enemy, amount)
	enemy.health.hitFlash = 1 // Move into generic hurt?

	// TODO: Add this into ability? Pass in from hurt?
	// state := EnemyHurt {
	// 	duration  = .5,
	// 	animation = .HIT_A,
	// 	animSpeed     = 1.0,
	// }
	state := EnemyPushback {
		duration  = .35,
		animation = .DODGE_BACKWARD,
		animSpeed = 1,
	}
	enterEnemyState(enemy, state)
	// enterEnemyState
	// Sound
	// Push back
	// Particle
}


// ------ Eneter State
enterEnemyState :: proc(enemy: ^Enemy, state: EnemyState) {
	enemy.animation.frame = 0
	enemy.state = state
	switch &s in enemy.state {
	case EnemyStateBase:
		enemy.animation.speed = 1.0
		enemy.animation.current = .IDLE
	case EnemyPushback:
		// TODO: update facing direction
		enemy.animation.speed = s.animSpeed
		enemy.animation.current = s.animation
	case EnemyHurt:
		// TODO: update facing direction
		enemy.animation.speed = s.animSpeed
		enemy.animation.current = s.animation
	}
}
