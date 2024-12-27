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

AbilityPool :: [dynamic]AbilityInstance

spawnMeleAtPlayer :: proc(pool: ^[dynamic]vec3, player: ^Player) {
	pos := player.spacial.pos
	mat := rl.MatrixTranslate(pos.x, pos.y, pos.z)
	mat = mat * rl.MatrixRotateY(player.spacial.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	p := rl.Vector3Transform({}, mat)

	spawnCube(pool, p)
}

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
initMeleInstances :: proc() -> AbilityPool {
	return make([dynamic]AbilityInstance, 0, 10)
}

newMeleInstance :: proc(pos: vec3) -> AbilityInstance {
	return AbilityInstance{spacial = Spacial{pos = pos, radious = 1}}
}
// ---- Spawn
spawnMeleInstance :: proc(pool: ^AbilityPool, pos: vec3) {
	append(pool, newMeleInstance(pos))
}

spawnMeleInstanceAtPlayer :: proc(pool: ^AbilityPool, player: ^Player) {
	pos := player.spacial.pos
	mat := rl.MatrixTranslate(pos.x, pos.y, pos.z)
	mat = mat * rl.MatrixRotateY(player.spacial.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	p := rl.Vector3Transform({}, mat)

	append(pool, newMeleInstance(p))
}
// ---- Remove
removeAbility :: proc(pool: ^AbilityPool, activeIndex: int) {
	// Swap and remove last
	pool[activeIndex] = pop(pool)
}

// ---- Update

updateEnemyHitCollisions :: proc(pool: ^AbilityPool, enemies: ^EnemyDummyPool) {
	// Check collision
	for &obj, index in pool {
		for &enemy in enemies.active {
			hit := checkCollision(obj, enemy)
			if !hit do continue
			// on hit
			hurt(&enemy, 1)
		}
		removeAbility(pool, index)
	}
}

// ---- Draw
drawMeleInstances :: proc(pool: ^AbilityPool) {
	for instance in pool {
		rl.DrawSphereWires(instance.spacial.pos, instance.radious, 4, 4, rl.BLACK)
	}
}

// ---------------------------------
// Move to it's own folder?
checkCollision :: proc(a: Spacial, b: Spacial) -> bool {
	return rl.CheckCollisionSpheres(a.pos, a.radious, b.pos, b.radious)
}

hurt :: proc(hp: ^Health, amount: f32) {
	hp.current -= amount
	fmt.println("Ouch!")
}
