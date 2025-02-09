package main

import "core:fmt"
import rl "vendor:raylib"

// MeleInstance 
AbilityInstance :: struct {
	using spacial: Spacial,
	type:          union {
		range,
		mele,
	},
}
// enum (Timer_based, Single, Other)
// timer
// hit:           bool, 
// Model
// }
mele :: struct {}
range :: struct {
	speed:    f32,
	duration: f32, //0 would be == 0 mele
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
	return AbilityInstance{spacial = Spacial{pos = pos, shape = 1.0}, type = mele{}}
}

newRangeInstance :: proc(pos: vec3, rot: f32) -> AbilityInstance {
	return AbilityInstance {
		spacial = Spacial{pos = pos, shape = 1.0, rot = rot},
		type = range{duration = 1.5, speed = 7},
	}
}
// ---- Spawn
spawnMeleInstance :: proc(pool: ^AbilityPool, pos: vec3) {
	append(&pool.active, newMeleInstance(pos))
}

spawnRangeInstance :: proc(pool: ^AbilityPool, pos: vec3, rot: f32) {
	append(&pool.active, newRangeInstance(pos, rot))
}

spawnMeleInstanceAtPlayer :: proc(pool: ^AbilityPool, player: ^Player) {
	pos := player.spacial.pos
	mat := rl.MatrixTranslate(pos.x, pos.y, pos.z)
	mat = mat * rl.MatrixRotateY(player.spacial.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	p := rl.Vector3Transform({}, mat)

	append(&pool.active, newMeleInstance(p))
}

spawnRangeInstanceAtPlayer :: proc(pool: ^AbilityPool, player: ^Player) {
	// TODO: replace with getForwardpoint
	pos := player.spacial.pos
	mat := rl.MatrixTranslate(pos.x, pos.y, pos.z)
	mat = mat * rl.MatrixRotateY(player.spacial.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	p := rl.Vector3Transform({}, mat)

	spawnRangeInstance(pool, p, player.rot)
}

spawnInstanceFrontOfLocation :: proc(pool: ^AbilityPool, loc: ^Spacial) {
	forward := getForwardPoint(loc^)

	append(&pool.active, newMeleInstance(forward + loc.pos))
}

spawnRangeInstanceFrontOfLocation :: proc(pool: ^AbilityPool, loc: ^Spacial) {
	forward := getForwardPoint(loc^)
	fmt.println("Spawn")
	append(&pool.active, newRangeInstance(forward + loc.pos, loc.rot))
}

// ---- despawn 
removeAbility :: proc(pool: ^AbilityPool, activeIndex: int) {
	// Swap and remove last
	pool.active[activeIndex] = pop(&pool.active)
}

// ---- Update

updateEnemyHitCollisions :: proc(
	pool: ^AbilityPool,
	enemies: ^EnemyDummyPool,
	spawners: ^EnemySpanwerPool,
	impact: ^ImpactPool,
) {
	// Check collision
	for &obj, index in pool.active {
		switch &v in obj.type {
		case mele:
			updateAbilityMele(&obj, enemies, spawners, impact)
			removeAbility(pool, index)
		case range:
			v.duration -= getDelta()
			obj.spacial.pos += getForwardPoint(obj) * getDelta() * v.speed
			hit := updateAbilityRange(&obj, enemies, spawners, impact)
			if v.duration <= 0 || hit {
				removeAbility(pool, index)
			}
		case:
			panic("Ability has no type")
		}
	}
}

updateAbilityRange :: proc(
	obj: ^AbilityInstance,
	enemies: ^EnemyDummyPool,
	spawners: ^EnemySpanwerPool,
	impact: ^ImpactPool,
) -> bool {
	hitUnit := false
	for &enemy in enemies.active {
		hit := checkCollision(obj, enemy)
		if !hit do continue
		// on hit
		{

			hurt(&enemy, 1)
			// At hitflash -> move out of hurt
			startHitStop() // TODO: only apply from some abilities, like mele - else it feels off. IE a dot would be bad
			addTrauma(.large)
			// TODO : add to the ability? as enum or full struct
			state := EnemyPushback {
				duration  = .4,
				animation = SKELE.hurt,
				animSpeed = 1,
			}

			switch v in enemy.type {
			case meleEnemy:
				enterEnemyMeleState(&enemy, state)
			case rangeEnemy:
				enterEnemyRangeState(&enemy, state)
			case dummyEnemy:
				enterEnemyDummyState(&enemy, state)
			}
			playSoundPunch()
			spawnImpact(impact, enemy.pos, 0)
		}
		hitUnit = true
		// enterEnemyState
		// Push back
		// Particle
	}
	for &enemy in spawners.active {
		hit := checkCollision(obj, enemy)
		if !hit do continue
		// on hit
		{
			hurt(&enemy, 1)
			// At hitflash -> move out of hurt
			startHitStop() // TODO: only apply from some abilities, like mele - else it feels off. IE a dot would be bad
			addTrauma(.large)
			playSoundPunch()
			spawnImpact(impact, enemy.pos, 0)
		}
		hitUnit = true
	}
	return hitUnit
}

updateAbilityMele :: proc(
	obj: ^AbilityInstance,
	enemies: ^EnemyDummyPool,
	spawners: ^EnemySpanwerPool,
	impact: ^ImpactPool,
) {
	for &enemy in enemies.active {
		hit := checkCollision(obj, enemy)
		if !hit do continue
		// on hit
		{

			hurt(&enemy, 1)
			// At hitflash -> move out of hurt
			startHitStop() // TODO: only apply from some abilities, like mele - else it feels off. IE a dot would be bad
			addTrauma(.large)
			// TODO : add to the ability? as enum or full struct
			state := EnemyPushback {
				duration  = .4,
				animation = SKELE.hurt,
				animSpeed = 1,
			}

			switch v in enemy.type {
			case meleEnemy:
				enterEnemyMeleState(&enemy, state)
			case rangeEnemy:
				enterEnemyRangeState(&enemy, state)
			case dummyEnemy:
				enterEnemyDummyState(&enemy, state)
			}
			playSoundPunch()
			spawnImpact(impact, enemy.pos, 0)
		}
		// enterEnemyState
		// Push back
		// Particle
	}
	for &enemy in spawners.active {
		hit := checkCollision(obj, enemy)
		if !hit do continue
		// on hit
		{
			hurt(&enemy, 1)
			// At hitflash -> move out of hurt
			startHitStop() // TODO: only apply from some abilities, like mele - else it feels off. IE a dot would be bad
			addTrauma(.large)
			playSoundPunch()
			spawnImpact(impact, enemy.pos, 0)
		}
	}
}

// Abilities that hurt player
updatePlayerHitCollisions :: proc(pool: ^AbilityPool, player: ^Player) {
	// Check collision
	for &obj, index in pool.active {
		switch &v in obj.type {
		case mele:
			defer removeAbility(pool, index)
			hit := checkCollision(obj, player)
			if !hit do continue
			hurt(player, 1)
		// startHitStop()
		// addTrauma(.large)
		case range:
			v.duration -= getDelta()
			if v.duration <= 0 {
				removeAbility(pool, index)
			}

			obj.spacial.pos += getForwardPoint(obj) * getDelta() * v.speed
			hit := checkCollision(obj, player)
			if !hit do continue
			hurt(player, 1)
			removeAbility(pool, index)
		case:
			panic("Ability has no type")
		}
	}
}

// ---- Draw
drawAbilityInstances :: proc(pool: ^AbilityPool, color: rl.Color) {
	for instance in pool.active {
		rl.DrawSphereWires(instance.spacial.pos, instance.spacial.shape.(Sphere), 8, 8, color)
	}
}

// ---------------------------------
// Move to it's own folder?
checkCollision :: proc(a: Spacial, b: Spacial) -> bool {
	assert(a.shape != nil, "No collision shape on a")
	assert(b.shape != nil, "No collision shape on b")

	switch aa in a.shape {
	case Box:
		switch bb in b.shape {
		case Box:
			boxA := getBoundingBox(a)
			boxB := getBoundingBox(b)
			return rl.CheckCollisionBoxes(boxA, boxB)
		case Sphere:
			box := getBoundingBox(a)
			return rl.CheckCollisionBoxSphere(box, b.pos, bb)
		}
	case Sphere:
		switch bb in b.shape {
		case Box:
			box := getBoundingBox(b)
			return rl.CheckCollisionBoxSphere(box, a.pos, aa)
		case Sphere:
			return rl.CheckCollisionSpheres(a.pos, aa, b.pos, bb)
		}
	}
	assert(true, "Should not land here")
	return false
}

Collision :: struct {
	point:  vec3,
	normal: vec3,
}

getCollision :: proc(a: Spacial, b: Spacial) -> Collision {
	switch s in a.shape {
	case Box:
		box := getBoundingBox(a)
		impact := vec3 {
			clamp(b.pos.x, box.min.x, box.max.x),
			0,
			clamp(b.pos.z, box.min.z, box.max.z),
		}
		normal := get_box_normal(box, impact)
		return Collision{point = impact, normal = normal}
	case Sphere:
		offset := b.pos - a.pos
		impact := a.pos + normalize(offset) * s
		normal := normalize(offset)
		return Collision{point = impact, normal = normal}
	}
	assert(false, "Should not be here")
	assert(true, "Should not be here")
	return {}
}

get_box_normal :: proc(box: rl.BoundingBox, collision_point: rl.Vector3) -> rl.Vector3 {
	// Get distances to each face
	dx_min := abs(collision_point.x - box.min.x)
	dx_max := abs(collision_point.x - box.max.x)
	dy_min := abs(collision_point.y - box.min.y)
	dy_max := abs(collision_point.y - box.max.y)
	dz_min := abs(collision_point.z - box.min.z)
	dz_max := abs(collision_point.z - box.max.z)

	// Find smallest distance to determine which face was hit
	min_dist := min(dx_min, min(dx_max, min(dy_min, min(dy_max, min(dz_min, dz_max)))))

	normal := rl.Vector3{0, 0, 0}

	// Set normal based on which face was hit
	switch min_dist {
	case dx_min:
		normal.x = -1
	case dx_max:
		normal.x = 1
	// case dy_min:
	// 	normal.y = -1
	// case dy_max:
	// 	normal.y = 1
	case dz_min:
		normal.z = -1
	case dz_max:
		normal.z = 1
	}

	return normal
}
