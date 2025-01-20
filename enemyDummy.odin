package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

Enemy :: struct {
	model:             rl.Model,
	animState:         AnimationState,
	using spacial:     Spacial,
	using health:      Health,
	state:             EnemyState,
	attackCD:          Timer, // CD for attacking
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
	animSet: AnimationSet,
	active:  [dynamic]Enemy,
	free:    [dynamic]Enemy,
}

EnemyState :: union {
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

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
enemyPoolSize := 100
initEnemyDummies :: proc() -> EnemyDummyPool {
	// It looks like we can share the same shader for all enemies
	// shader := rl.LoadShader(nil, "shaders/grayScale.fs")
	shader := rl.LoadShader(nil, "shaders/flash.fs")

	pool := EnemyDummyPool {
		active = make([dynamic]Enemy, 0, 0),
		free   = make([dynamic]Enemy, enemyPoolSize, enemyPoolSize),
	}
	path: cstring = "/home/nico/Downloads/Human2/base.m3d"

	pool.animSet = loadModelAnimations(path)
	texture := loadTexture("/home/nico/Downloads/Human2/base.png")

	for &enemy in pool.free {
		// Note: is loadModel slow? can I load once and dup memory for every model after?
		enemy.model = rl.LoadModel(path)
		assert(enemy.model.meshCount != 0, "No mesh")
		enemy.model.materials[1].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		enemy.model.materials[1].shader = shader
		enemy.health = Health {
			max     = 10,
			current = 10,
		}
		enemy.range = 1.75
		enemy.attackCD = Timer {
			max = 2.0,
		}
		enemy.shape = .8
		enemy.animState.speed = 1
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

despawnAllEnemies :: proc(pool: ^EnemyDummyPool) {
	for enemy, ii in pool.active {
		append(&pool.free, enemy)
	}
	clear(&pool.active)
}


despawnEnemy :: proc(pool: ^EnemyDummyPool, index: int) {
	// Swap and remove last
	append(&pool.free, pool.active[index])
	pool.active[index] = pop(&pool.active)
}

// ---- Update
updateEnemyDummies :: proc(
	enemies: ^EnemyDummyPool,
	player: Player,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	for &enemy, index in enemies.active {
		updateDummy(&enemy, player, enemies, objs, pool)

		updateHealth(&enemy)
		if enemy.health.current <= 0 {
			despawnEnemy(enemies, index)
		}

		updateAnimation(enemy.model, &enemy.animState, enemies.animSet)
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
			seperationForce += boidSeperation(enemy, player) * 1.5 // Might want to  make it its own force? // Change to straffing using noise if in range of player?
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
ATTACK_RANGE :: (2 - .2) // Attack range == ability spawn point + radius, 1 unit away w/ 1 unit radius == 2 - some distance to hit
// linalg.cos(rl.PI / 8) == .92 // PI / 8 == 22.5 Degree, PI / 4 -> 45%
ATTACK_FOV: f32 = .95

updateDummy :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyDummyPool,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	enemy.attackCD.left -= getDelta()

	switch &s in enemy.state {
	case EnemyStateBase:
		// TODO: Add extra states? Going to location ; fighting ; upclose to something ; ext
		// When next to player, it's weird 

		// updateDummyMovement(enemy, player, enemies, objs) // Boids
		// enemy.animation.current = .WALKING_B

		if linalg.distance(enemy.pos, player.pos) > ATTACK_RANGE {
			updateDummyMovement(enemy, player, enemies, objs) // Boids
			enemy.animState.current = SKELE.run
		} else {
			target := normalize(player.pos - enemy.pos) // toward player -> Target
			r := lookAtVec3(target, {})
			enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * ENEMY_TURN_SPEED)
			enemy.animState.current = SKELE.idle
		}

		inRange := linalg.distance(enemy.pos, player.pos) < ATTACK_RANGE
		canAttack := enemy.attackCD.left <= 0
		toPlayer := normalize(player.pos - enemy.pos)
		forward := getForwardPoint(enemy)
		facing := linalg.dot(forward, toPlayer) >= ATTACK_FOV

		if inRange && canAttack && facing {
			enemy.attackCD.left = enemy.attackCD.max // Start timer again
			enterEnemyState(
				enemy,
				EnemyAttack1{duration = 1, trigger = .3, animation = SKELE.attack, animSpeed = 1},
			)
		}
	// if in range of player attack? Idle animation and running animation
	case EnemyAttack1:
		s.duration -= getDelta()
		if s.duration <= 0 {
			enterEnemyState(enemy, EnemyStateBase{})
			return
		}

		if s.hasTriggered do return

		if s.duration <= s.trigger {
			s.hasTriggered = true
			spawnInstanceFrontOfLocation(pool, enemy)
		}
	case EnemyPushback:
		dir := getBackwardPoint(enemy)
		enemy.spacial.pos += dir * getDelta() * PUSH_BACK_SPEED

		s.duration -= getDelta()
		if s.duration <= 0 {
			enterEnemyState(enemy, EnemyStateBase{})
		}
	case EnemyHurt:
		s.duration -= getDelta()
		// Use enter enemy state
		if s.duration <= 0 {
			enterEnemyState(enemy, EnemyStateBase{})
		}
	case:
		enterEnemyState(enemy, EnemyStateBase{})
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
	// Apply hit flash
	drawHitFlash(enemy.model, enemy.health)

	rl.DrawModelEx(enemy.model, enemy.spacial.pos, UP, rl.RAD2DEG * enemy.spacial.rot, 3, rl.WHITE)

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
	// rl.DrawCapsule(enemy.pos, enemy.pos + enemy.target, .05, 5, 5, color1)

	// Alignment Range
	// rl.DrawSphereWires(enemy.pos, enemy.range * alignmentRange, 10, 10, alignmentColor)

	// cohesion
	// rl.DrawCube(enemy.centertarget, .2, .2, .2, rl.BLACK)

	// boxEdge?
	// rl.DrawCube(enemy.wallPoint, .2, .2, .2, rl.BLACK)

	// Collision shape
	// rl.DrawCylinderWires(enemy.pos, enemy.shape.(Sphere), enemy.shape.(Sphere), 2, 10, rl.BLACK)
}

// Update Funcs


// ------ Eneter State
enterEnemyState :: proc(enemy: ^Enemy, state: EnemyState) {
	enemy.animState.duration = 0
	enemy.state = state
	switch &s in enemy.state {
	case EnemyStateBase:
		enemy.animState.speed = 0.5
		enemy.animState.current = SKELE.idle
	case EnemyAttack1:
		// Face player
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
	case EnemyPushback:
		// TODO: update facing direction
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
	case EnemyHurt:
		// TODO: update facing direction
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
	}
	//TODO: default case
}
