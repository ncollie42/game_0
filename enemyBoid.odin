package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

PUSH_BACK_SPEED: f32 = 2.5
ENEMY_SPEED :: 5 / 2
ENEMY_TURN_SPEED :: 4
// Attack range == ability spawn point + radius, 1 unit away w/ 1 unit radius == 2 - some distance to hit
ATTACK_RANGE_MELE :: (2 - .2)
// linalg.cos(rl.PI / 8) == .92 // PI / 8 == 22.5 Degree, PI / 4 -> 45%
ATTACK_FOV: f32 = .95

updateEnemyMovement :: proc(targetOption: enum {
		CENTER,
		FORWARD,
		PLAYER,
	}, enemy: ^Enemy, player: Player, enemies: ^EnemyPool, objs: ^[dynamic]EnvObj, speed: f32) {
	target: vec3
	switch targetOption {
	case .CENTER:
		target = vec3{}
	case .FORWARD:
		target = directionFromRotation(enemy.rot) // forward
	case .PLAYER:
		target = normalize(player.pos - enemy.pos) // toward player -> Target
	}

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
	// Env Avoidance + map edges
	clearPath := vec3{}
	{
		clearPath += findClearPath(enemy, objs)
		clearPath += avoidMapBounds(enemy)
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

		r := lookAtVec3(target, {})
		enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * ENEMY_TURN_SPEED)
		enemy.spacial.pos += directionFromRotation(enemy.rot) * getDelta() * speed
		// enemy.spacial.pos += directionFromRotation(enemy.rot) * getDelta() * ENEMY_SPEED
	}
}


boidSeperation :: proc(boid: ^Enemy, other: Spacial) -> vec3 { 	// boidData ; spacial ; spacial
	range := boid.shape.(Sphere) * 2

	forward := directionFromRotation(boid.rot)

	toNeighbor := other.pos - boid.pos
	dist := linalg.length(toNeighbor)

	if dist > range {return {}} 	// Outside of range 
	toNeighbor = normalize(toNeighbor)

	if linalg.dot(forward, toNeighbor) <= -.5 {return {}} 	// Behind Unit 	// cos(120) == -.5

	// Get a vector pointing AWAY from the neighbor
	seperation: vec3 = boid.pos - other.pos
	seperation = normalize(seperation)

	dist = clamp(dist, .01, 1) // Prevent 0 when 100% ontop
	// Weigh by distance (closer toNeighbor have more influence)
	seperation = seperation * (1.0 / dist)
	return seperation
}

boidSeperation2 :: proc(boid: ^Enemy, enemies: ^EnemyPool) -> vec3 {
	range := boid.shape.(Sphere) * 4

	force := vec3{}
	for &other, index in enemies.active {
		if &other == boid {continue} 	// Skip self

		toNeighbor := other.pos - boid.pos
		dist := linalg.length(toNeighbor)

		if dist > range {continue} 	// Outside of range 

		forward := directionFromRotation(boid.rot)
		toNeighbor = normalize(toNeighbor)

		if linalg.dot(forward, toNeighbor) <= -.5 {continue} 	// Behind unit; cos(120) == -.5

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
boidAlignment :: proc(boid: ^Enemy, enemies: ^EnemyPool) -> vec3 {
	range := boid.shape.(Sphere) * 2

	force := vec3{}
	for &other in enemies.active {
		if &other == boid {continue} 	// Skip self

		toNeighbor := other.pos - boid.pos
		distance := linalg.length(toNeighbor)

		if distance > (range * alignmentRange) {return {}} 	// Outside of range 

		forward := directionFromRotation(boid.rot)
		toNeighbor = normalize(toNeighbor)
		if linalg.dot(forward, toNeighbor) <= -.5 {return {}} 	// Behind unit; cos(120) == -.5

		// Add neighbor's forward vector
		otherForward := directionFromRotation(other.rot)
		force += otherForward
	}

	return force
}


boidCohesion :: proc(boid: ^Enemy, enemies: ^EnemyPool) -> vec3 {
	range := boid.shape.(Sphere) * 2

	centerPos := vec3{}
	count := 0
	for &other in enemies.active {
		if &other == boid {continue} 	// Skip self

		toNeighbor := other.pos - boid.pos
		dist := linalg.length(toNeighbor)

		if dist >= range * cohesionRange {continue} 	// Outside of range 
		centerPos += other.pos // TODO: add ratio of how close to group?
		count += 1
	}

	if count <= 0 {return {}}

	centerPos = centerPos / f32(count)
	return normalize(centerPos - boid.pos)
}

// ---------------------------------------------------------------
/*
	Boid logic idea, how to do boids on different kinds of enemies.

	We can create an enemyState that all tyeps have -> stateRun or stateBoid:
	If enemy is in this state; update use a group update function. Collect all boids and update.

	updatingBoids []Spacial + enemyPtr

	updateBoids(mele, range, dummy) {
		for enemy in mele {
			if enemy.state == running {
				Add to a list
				spacial + pointer to enemy
			}
		}

		- For every enemy in a running state.
			- Add all mele, range, dummy, ext. to a single list.
			- Make a copy of spacial, + keep pointer to original enemy.
		
			- Apply rotation + translation on copy
		- Copy new 'spacial' to original enemy. 
		
	}
*/
