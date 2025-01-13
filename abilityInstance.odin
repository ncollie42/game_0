package main

import "core:fmt"
import rl "vendor:raylib"

// MeleInstance 
AbilityInstance :: struct {
	using spacial: Spacial,
	// enum (Timer_based, Single, Other)
	// timer
	// hit:           bool, 
	// Model
}

// oneShot : hurt everything around
// timer : Hurt everything around on a timer
// Pierce : Hurt enemy once but keep going, keep track of enemies hit -- NEED to start indexing enemies.

// deflayed : After x amount of time do it's thing -> or should this be a spawner?
// Number of projectiles + direction? part of spanwer?

// For Debug, How to show where things have been hit? Create a seperate Ghost array? active : free : ghost

AbilityPool :: struct {
	active: [dynamic]AbilityInstance,
	// free:   [dynamic]AbilityInstance,
}

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
initAbilityPool :: proc() -> ^AbilityPool {
	pool := new(AbilityPool)
	pool.active = make([dynamic]AbilityInstance, 0, 10)
	return pool
}

newMeleInstance :: proc(pos: vec3) -> AbilityInstance {
	return AbilityInstance{spacial = Spacial{pos = pos, radious = 1}}
}
// ---- Spawn
spawnMeleInstance :: proc(pool: ^AbilityPool, pos: vec3) {
	append(&pool.active, newMeleInstance(pos))
}

spawnMeleInstanceAtPlayer :: proc(pool: ^AbilityPool, player: ^Player) {
	pos := player.spacial.pos
	mat := rl.MatrixTranslate(pos.x, pos.y, pos.z)
	mat = mat * rl.MatrixRotateY(player.spacial.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	p := rl.Vector3Transform({}, mat)

	append(&pool.active, newMeleInstance(p))
}

spawnInstanceFrontOfLocation :: proc(pool: ^AbilityPool, loc: ^Spacial) {
	forward := getForwardPoint(loc)

	append(&pool.active, newMeleInstance(forward + loc.pos))
}

// ---- despawn 
removeAbility :: proc(pool: ^AbilityPool, activeIndex: int) {
	// Swap and remove last
	pool.active[activeIndex] = pop(&pool.active)
}

// ---- Update

updateEnemyHitCollisions :: proc(pool: ^AbilityPool, enemies: ^EnemyDummyPool) {
	// Check collision
	for &obj, index in pool.active {
		for &enemy in enemies.active {
			hit := checkCollision(obj, enemy)
			if !hit do continue
			// on hit
			hurt(&enemy, 1)
			// At hitflash -> move out of hurt
			startHitStop()
			addTrauma(.large)
			state := EnemyPushback {
				duration  = .35,
				animation = .DODGE_BACKWARD,
				animSpeed = 1,
			}
			enterEnemyState(&enemy, state)
			playSoundPunch()
			// enterEnemyState
			// Sound
			// Push back
			// Particle
		}
		removeAbility(pool, index)
	}
}

updatePlayerHitCollisions :: proc(pool: ^AbilityPool, player: ^Player) {
	// Check collision
	for &obj, index in pool.active {
		defer removeAbility(pool, index)

		hit := checkCollision(obj, player)
		if !hit do continue
		fmt.println("Player hit")
		// on hit
		hurt(player, 1)
		// startHitStop()
		// addTrauma(.large)
	}
}

// ---- Draw
drawAbilityInstances :: proc(pool: ^AbilityPool, color: rl.Color) {
	for instance in pool.active {
		rl.DrawSphereWires(instance.spacial.pos, instance.radious, 8, 8, color)
	}
}

// ---------------------------------
// Move to it's own folder?
checkCollision :: proc(a: Spacial, b: Spacial) -> bool {
	return rl.CheckCollisionSpheres(a.pos, a.radious, b.pos, b.radious)
}
