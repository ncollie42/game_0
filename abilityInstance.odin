package main

import "core:fmt"
import rl "vendor:raylib"

// MeleInstance 
AbilityInstance :: struct {
	// Can parry: bool, -> move to player list? if range swap Dir
	power:         f32,
	crit:          f32,
	using spacial: Spacial,
	type:          union {
		range,
		mele,
	},
	canParry:      bool,
	effect:        enum {
		NONE,
		pushback,
	},
	// Type :: Magic - Physical
	dmgType:       DamageType,
}

DamageType :: enum {
	Physical,
	Magic,
}
// enum (Timer_based, Single, Other)
// timer
// hit:           bool, 
// Model
// }
mele :: struct {
}
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
	orb:    rl.Model,
	// free:   [dynamic]AbilityInstance,
}

// ----------------------------- New System
// ---- Closure :: Action
// ---- Init
initAbilityPool :: proc() -> ^AbilityPool {
	pool := new(AbilityPool)
	pool.active = make([dynamic]AbilityInstance, 0, 10)

	orb := rl.GenMeshSphere(1, 8, 8)
	pool.orb = rl.LoadModelFromMesh(orb)
	return pool
}

newMeleInstance :: proc(pos: vec3, damage: f32, crit: f32) -> AbilityInstance {
	return AbilityInstance {
		power = damage,
		crit = crit,
		spacial = Spacial{pos = pos, shape = 1},
		type = mele{},
		canParry = true,
		effect = .NONE,
		dmgType = .Physical,
	}
}

newRangeInstance :: proc(pos: vec3, rot: f32, damage: f32, crit: f32) -> AbilityInstance {
	return AbilityInstance {
		power = damage,
		crit = crit,
		spacial = Spacial{pos = pos, shape = 0.6, rot = rot},
		type = range{duration = 1.5, speed = 7},
		canParry = true,
		effect = .NONE,
		dmgType = .Magic,
	}
}
// ---- Spawn
// TODO: add power when spawning ability + add extra arg in callback

spawnAbilityInstance :: proc(pool: ^AbilityPool, ability: AbilityInstance) {
	append(&pool.active, ability)
}

spawnMeleInstance :: proc(pool: ^AbilityPool, pos: vec3, damage: f32, crit: f32) {
	ability := newMeleInstance(pos, damage, crit)
	append(&pool.active, ability)
}

spawnRangeInstance :: proc(pool: ^AbilityPool, pos: vec3, rot: f32, damage: f32, crit: f32) {
	ability := newRangeInstance(pos, rot, damage, crit)
	append(&pool.active, ability)
}

// Enemy spawning
spawnInstanceFrontOfLocation :: proc(pool: ^AbilityPool, loc: ^Spacial) {
	forward := getForwardPoint(loc^)

	append(&pool.active, newMeleInstance(forward + loc.pos, 1, 0))
}

spawnRangeInstanceFrontOfLocation :: proc(pool: ^AbilityPool, loc: ^Spacial) {
	forward := getForwardPoint(loc^)
	append(&pool.active, newRangeInstance(forward + loc.pos, loc.rot, 1, 0))
}

// ---- despawn 
removeAbility :: proc(pool: ^AbilityPool, activeIndex: int) {
	// Swap and remove last
	pool.active[activeIndex] = pop(&pool.active)
	// panic("Swap with unorder_remove")
}

removeAllAbilities :: proc(pool: ^AbilityPool) {
	#reverse for &obj, index in pool.active {
		unordered_remove(&pool.active, index)
	}
}

// ---- Update

updateEnemyHitCollisions :: proc(
	pool: ^AbilityPool,
	enemies: ^EnemyPool,
	spawners: ^EnemySpanwerPool,
	impact: ^Flipbook,
) {
	// Check collision
	#reverse for &obj, index in pool.active {
		switch &v in obj.type {
		case mele:
			updateAbilityMele(&obj, enemies, spawners, impact)
			unordered_remove(&pool.active, index)
		case range:
			v.duration -= getDelta()
			obj.spacial.pos += getForwardPoint(obj) * getDelta() * v.speed
			hit := updateAbilityRange(&obj, enemies, spawners, impact)
			if v.duration <= 0 || hit {
				unordered_remove(&pool.active, index)
			}
		case:
			panic("Ability has no type")
		}
	}
}

updateAbilityRange :: proc(
	obj: ^AbilityInstance,
	enemies: ^EnemyPool,
	spawners: ^EnemySpanwerPool,
	impact: ^Flipbook,
) -> bool {
	hitUnit := false
	for &enemy in enemies.active {
		hit := checkCollision(obj, enemy)
		if !hit do continue
		// on hit
		{
			// TODO: check if crit
			hurt(&enemy, obj.power)
			spawnDamangeNumber(enemy.pos + enemy.dmgIndicatorOffset, obj.power, .Default)
			// At hitflash -> move out of hurt
			startHitStop() // TODO: only apply from some abilities, like mele - else it feels off. IE a dot would be bad
			addTrauma(.large)
			// TODO : add to the ability? as enum or full struct
			state := EnemyPushback {
				animation = ENEMY.hurt,
				animSpeed = 1,
			}

			switch v in enemy.type {
			case DummyEnemy:
				enterEnemyDummyState(&enemy, state)
			case MeleEnemy:
				enterEnemyMeleState(&enemy, state)
			case RangeEnemy:
				enterEnemyRangeState(&enemy, state)
			case GiantEnemy:
				enterEnemyGiantState(&enemy, state)
			case ThornEnemy:
			// Do nothing, no state
			case MonolithEnemy:
			// Do nothing, no state
			}
			playSoundPunch()
			spawnFlipbook(impact, enemy.pos, 0) // TODO replace with impact based on ability used
			// TODO: add hurt VFX :: blood or dust or rocks.
			// spawnFlipbook(impact, enemy.pos, 0) enemy.hurtVFX
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
			hurt(&enemy, obj.power)
			// At hitflash -> move out of hurt
			startHitStop() // TODO: only apply from some abilities, like mele - else it feels off. IE a dot would be bad
			addTrauma(.large)
			playSoundPunch()
			spawnFlipbook(impact, enemy.pos, 0)
		}
		hitUnit = true
	}
	return hitUnit
}

updateAbilityMele :: proc(
	obj: ^AbilityInstance,
	enemies: ^EnemyPool,
	spawners: ^EnemySpanwerPool,
	impact: ^Flipbook,
) {
	for &enemy in enemies.active {
		hit := checkCollision(obj, enemy)
		if !hit do continue
		// on hit
		{

			hurt(&enemy, obj.power)
			spawnDamangeNumber(enemy.pos + enemy.dmgIndicatorOffset, obj.power, .Default)
			// At hitflash -> move out of hurt
			startHitStop() // TODO: only apply from some abilities, like mele - else it feels off. IE a dot would be bad
			addTrauma(.large)
			playSoundPunch()
			spawnFlipbook(impact, enemy.pos, 0)

			if obj.effect == .NONE do continue

			// TODO : add to the ability? as enum or full struct
			state := EnemyPushback {
				animation = ENEMY.hurt,
				animSpeed = 1,
			}

			switch v in enemy.type {
			case DummyEnemy:
				enterEnemyDummyState(&enemy, state)
			case MeleEnemy:
				enterEnemyMeleState(&enemy, state)
			case RangeEnemy:
				enterEnemyRangeState(&enemy, state)
			case GiantEnemy:
				enterEnemyGiantState(&enemy, state)
			case ThornEnemy:
			// Do nothing no enemy
			case MonolithEnemy:
			// Do nothing no enemy
			}
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
			hurt(&enemy, obj.power)
			// At hitflash -> move out of hurt
			startHitStop() // TODO: only apply from some abilities, like mele - else it feels off. IE a dot would be bad
			addTrauma(.large)
			playSoundPunch()
			spawnFlipbook(impact, enemy.pos, 0)
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


			if isBlocking(player^) {
				// doBlock(&player.block, &player.attack)
				// if block, take no damage? or take less damage?
				hurt(player, obj.power * .5)
			} else {
				hurt(player, obj.power)
			}
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
			if isBlocking(player^) {
				// doBlock(&player.block, &player.attack)
				// if block, take no damage? or take less damage?
				hurt(player, obj.power * .5)
			} else {
				hurt(player, obj.power)
			}

			removeAbility(pool, index) // swap later
		case:
			panic("Ability has no type")
		}
	}
}

// ---- Draw
drawAbilityInstances :: proc(pool: ^AbilityPool, color: rl.Color, camera: ^rl.Camera) {
	for obj in pool.active {
		switch &v in obj.type {
		case mele:
		// rl.DrawSphereWires(obj.spacial.pos, obj.spacial.shape.(Sphere), 8, 8, color)
		case range:
			// rl.DrawSphereWires(obj.spacial.pos, obj.spacial.shape.(Sphere), 8, 8, color)
			size := obj.spacial.shape.(Sphere)
			red := colorToVec4(color27)
			green := colorToVec4(color9)
			// color := obj.canParry ? green : red
			color := red
			ss := obj.spacial
			ss.pos += {0, 1, 0}

			drawOutline(pool.orb, ss, size, camera, color)
			drawShadow(pool.orb, obj.spacial, size, camera)
			rl.DrawModel(pool.orb, ss.pos, size * .9, white_3) //black_3
		case:
			panic("Ability has no type")
		}
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

// ------------------------------------------ Parry

PARRY_WINDOW :: .4
PARRY_DIST :: 2.0
parryAbility :: proc(p1_index: int, p1: ^AbilityPool, p2: ^AbilityPool) {
	// swap ability from p1 to p2
	aa := p1.active[p1_index]
	aa.rot += rl.PI
	switch &v in aa.type {
	case range:
		// make it go faster?
		v.speed *= 2
	case mele:
	}
	aa.effect = .pushback
	append(&p2.active, aa)
	unordered_remove(&p1.active, p1_index)
	// TODO:
	// extend duration
	// screen shake or time snow
	// particle
}
