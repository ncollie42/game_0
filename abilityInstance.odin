package main

import "core:fmt"
import rl "vendor:raylib"

// Your abilities should compound (not just add) -> helps lead to the fantacy power at the end of the round.
// Don't fight the power fantasy in minutes 15-25. Let players feel broken. The dopamine hit of "I'm unstoppable" is exactly what you want before the match ends.
// 
// MeleInstance 
AbilityInstance :: struct {
	// Can parry: bool, -> move to player list? if range swap Dir
	using spacial: Spacial,
	// Damage 
	power:         f32,
	crit:          f32,
	dmgType:       enum {
		Physical,
		Magic,
	},
	canParry:      bool,
	effect:        enum {
		NONE,
		pushback,
	},
	type:          union {
		Range,
		Mele,
		Aoe_Tick,
		Beam,
	},
}

Mele :: struct {
}

Range :: struct {
	speed:    f32,
	duration: f32, //0 would be == 0 mele
	// Visual :: Particles
	tick:     Timer, // for particle spawn
	trail:    [dynamic]vec3,
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
		type = Mele{},
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
		type = Range{duration = 1.5, speed = 7, tick = Timer{.02, 0}},
		canParry = true,
		effect = .NONE,
		dmgType = .Magic,
	}
}

// ---- Spawn
// TODO: add power when spawning ability + add extra arg in callback

// spawnRangeInstance :: proc(pool: ^AbilityPool, pos: vec3, rot: f32, damage: f32, crit: f32) {
// 	ability := newRangeInstance(pos, rot, damage, crit)
// 	append(&pool.active, ability)
// }

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

updateEnemyHitCollisions :: proc(pool: ^AbilityPool, enemies: ^EnemyPool, impact: ^Flipbook) {
	// Check collision
	#reverse for &obj, index in pool.active {
		switch &v in obj.type {
		case Mele:
			hurtEnemies(&obj, enemies, impact)
			unordered_remove(&pool.active, index)
		case Range:
			// Damage
			hit := hurtEnemies(&obj, enemies, impact)
			// Remove
			v.duration -= getDelta()
			if v.duration <= 0 || hit {
				unordered_remove(&pool.active, index)
			}
			// Move
			obj.spacial.pos += getForwardPoint(obj) * getDelta() * v.speed

			// Particle Emit
			if tickTimer(&v.tick) {
				append(&v.trail, obj.pos)
			}
			if len(v.trail) >= 20 {
				ordered_remove(&v.trail, 0)
			}
		// Particle Update
		case Aoe_Tick:
			// remove when expire
			v.duration -= getDelta()
			if v.duration <= 0 do unordered_remove(&pool.active, index)

			if tickTimer(&v.tick) {
				hurtEnemies(&obj, enemies, impact)
			}
		case Beam:
			// Update
			size := obj.spacial.shape.(Sphere)
			mouse := mouseInWorld(v.camera)
			dist := distance_to(v.startPos, mouse)
			dist = min(dist, v.maxDistance)
			target := normalize(mouse - v.startPos)

			// For each chunck in beam
			for xx in 1 ..= v.maxDistance {
				obj.pos = v.startPos + target * xx
				hit := false
				for &enemy in v.enemies.active {
					hit = checkCollision(obj, enemy)
					if hit do break
				}
				v.endPos = obj.pos
				if hit do break
			}

			if tickTimer(&v.tick) {
				hurtEnemies(&obj, enemies, impact)
			}
		// fmt.println("b:", distance_to({}, mouse))
		// hitUnit := false
		// for &enemy in enemies.active {
		// 	hit := checkCollision(obj, enemy)
		// }
		// update poss based mouse and enemies in front of player
		// loop over enemies
		// get points of enemies damage closest one
		// On tick -> do damage at tip
		// 1. draw from player to mouse
		// 2. do damage at mouse
		// 3. loop over enemies -> update mouse
		// 4. add player state
		// 5. check player state
		case:
			panic("Ability has no type")
		}
	}
}

hurtEnemies :: proc(obj: ^AbilityInstance, enemies: ^EnemyPool, impact: ^Flipbook) -> bool {
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
	return hitUnit
}

// Abilities that hurt player
updatePlayerHitCollisions :: proc(pool: ^AbilityPool, player: ^Player) {
	// Check collision
	for &obj, index in pool.active {
		switch &v in obj.type {
		case Mele:
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
		case Range:
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
		case Aoe_Tick:
			// remove when expire
			v.duration -= getDelta()
			if v.duration <= 0 do unordered_remove(&pool.active, index)
			// Ticket damage 
			updateTimer(&v.tick)
			if !isTimerReady(v.tick) do continue
			// hurtEnemies(&obj, enemies, impact) -> change for player
			startTimer(&v.tick)
		case Beam:
		case:
			panic("Ability has no type")
		}
	}
}

// ---- Draw
drawAbilityInstances :: proc(pool: ^AbilityPool, color: rl.Color, camera: ^rl.Camera) {
	for &obj in pool.active {
		switch &v in obj.type {
		case Mele:
		// rl.DrawSphereWires(obj.spacial.pos, obj.spacial.shape.(Sphere), 8, 8, color)
		case Range:
			// Projectile
			// rl.DrawSphereWires(obj.spacial.pos, obj.spacial.shape.(Sphere), 8, 8, color)
			size := obj.spacial.shape.(Sphere)
			red := colorToVec4(color27)
			green := colorToVec4(color9)

			color := red
			ss := obj.spacial
			ss.pos += {0, 1, 0}

			drawOutline(pool.orb, ss, size, camera, color)
			drawShadow(pool.orb, obj.spacial, size, camera)
			rl.DrawModel(pool.orb, ss.pos, size * .9, white_3) //black_3
			// Trail
			ll := len(v.trail)
			for pp, index in v.trail {
				// if index == 0 do continue
				// rl.DrawCapsule(
				// 	v.trail[index] + {0, 1, 0},
				// 	v.trail[index - 1] + {0, 1, 0},
				// 	f32(index) / f32(ll) * .5,
				// 	3,
				// 	3,
				// 	rl.BLACK,
				// )
				rl.DrawSphere(pp + {0, 1, 0}, .1, rl.WHITE)
			}
		case Aoe_Tick:
			size := obj.spacial.shape.(Sphere)
			rl.DrawSphereWires(obj.pos, size, 8, 8, rl.BLACK)
		// rl.DrawCircle3D(obj.pos, size, {0, 0, 1}, 0, rl.WHITE)
		case Beam:
			// Draw
			size := obj.spacial.shape.(Sphere)
			// startPoint := p.pos
			// mouse := mouseInWorld(v.camera)
			// dist := distance_to(startPoint, mouse)
			// dist = min(dist, v.maxDistance)
			// target := normalize(mouse - {})
			// endPoint := target * dist
			// // For each chunck
			// for xx in 1 ..= v.maxDistance {
			// 	obj.pos = target * xx
			// 	hit := false
			// 	for &enemy in v.enemies.active {
			// 		hit = checkCollision(obj, enemy)
			// 		if hit do break
			// 	}
			// 	rl.DrawSphereWires(obj.pos, size, 8, 8, rl.WHITE)
			// 	endPoint = target * xx
			// 	if hit do break
			// }

			rl.DrawCapsuleWires(v.startPos, v.endPos, size, 8, 8, rl.BLACK)
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
	case Range:
		// make it go faster?
		v.speed *= 2
	case Mele:
	case Aoe_Tick:
	case Beam:
	}
	aa.effect = .pushback
	append(&p2.active, aa)
	unordered_remove(&p1.active, p1_index)
	// TODO:
	// extend duration
	// screen shake or time snow
	// particle
}

// ------------------------------------- AOE Tick Ability --------------------------

Aoe_Tick :: struct {
	// Damage
	duration: f32,
	tick:     Timer,
	// Visual :: Particles
}

newAoEInstance :: proc(pos: vec3, damage: f32, crit: f32) -> AbilityInstance {
	return AbilityInstance {
		power = damage,
		crit = crit,
		spacial = Spacial{pos = pos, shape = 3},
		type = Aoe_Tick{3, {.5, 0}},
		canParry = true,
		effect = .NONE,
		dmgType = .Magic,
	}
}


// Add range limit for mouse -> Add 
Beam :: struct {
	maxDistance: f32,
	camera:      ^rl.Camera, // For mouse
	enemies:     ^EnemyPool,
	tick:        Timer,
	player:      ^Player,
	// onUpdate
	startPos:    vec3,
	endPos:      vec3,
}

newBeamInstance :: proc(
	player: ^Player,
	damage: f32,
	crit: f32,
	camera: ^rl.Camera,
	enemies: ^EnemyPool,
) -> AbilityInstance {
	return AbilityInstance {
		power = damage,
		crit = crit,
		spacial = Spacial{pos = player.pos, shape = 1},
		type = Beam {
			maxDistance = 10,
			camera = camera,
			enemies = enemies,
			tick = {.2, 0},
			player = player,
			startPos = player.pos,
			endPos = {},
		},
		canParry = true,
		effect = .NONE,
		dmgType = .Magic,
	}
}
