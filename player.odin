package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "vendor:raylib"

Player :: struct {
	lookAtMouse:   bool,
	model:         rl.Model,
	scale:         f32,
	animState:     AnimationState,
	animSet:       AnimationSet,
	using spacial: Spacial,
	using health:  Health,
	state:         State,
	trail:         Flipbook, // TODO: add left + right trail
	//Test :: Collision
	point:         vec3,
	normal:        vec3,
	edge:          bool,
}

MOVE_SPEED :: 4.5
TURN_SPEED :: 10.0

initPlayer :: proc() -> ^Player {
	player := new(Player)

	modelPath: cstring = "/home/nico/Downloads/warrior/base.m3d"
	texturePath: cstring = "/home/nico/Downloads/warrior/95_p.png"

	player.model = loadModel(modelPath)
	player.animSet = loadM3DAnimationsWithRootMotion(modelPath)

	texture := loadTexture(texturePath)
	player.model.materials[player.model.materialCount - 1].maps[rl.MaterialMapIndex.ALBEDO].texture =
		texture

	player.animState.speed = 1

	player.health = Health {
		max     = 50,
		current = 50,
	}

	shader := rl.LoadShader(nil, "shaders/flash.fs")
	player.model.materials[1].shader = shader
	player.spacial.shape = .8 //radius

	path: cstring = "/home/nico/Downloads/smear.png"
	player.trail = initFlipbookPool(path, 240 / 5, 48, 5)

	player.scale = 5
	return player
}

moveAndSlide :: proc(
	player: ^Player,
	velocity: vec3,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyDummyPool,
) {

	// Projected movement
	projected := player.spacial
	projected.pos += velocity * getDelta()
	for obj in objs {
		if checkCollision(obj, projected) {
			collision := getCollision(obj, projected)

			player.point = collision.point
			player.normal = collision.normal

			// if normal dot is > .7 // mostly facing the same way. sharp corners.
			if linalg.dot(collision.normal, velocity) > .7 {break}

			// Slide: Project velocity onto normal using dot product
			dot := linalg.dot(velocity, collision.normal)
			slide := velocity - (collision.normal * dot)

			player.spacial.pos += slide * getDelta()

			// If colliding after moving, set possition at the edge of object
			if checkCollision(obj, player.spacial) {
				player.spacial.pos =
					collision.point + collision.normal * (player.spacial.shape.(Sphere) * 1.05)
			}
			return
		}
	}

	mapCheck: {
		dist := linalg.distance(projected.pos, vec3{})
		diff := MapGround.shape.(Sphere) - player.spacial.shape.(Sphere)
		player.edge = dist > diff
		if dist > diff {
			// Trying to get out
			col := getCollision(MapGround, projected)
			col.normal *= -1 // point inward

			player.point = col.point
			player.normal = col.normal

			// TODO: maybe add in sliding?
			player.pos = col.point + col.normal * (player.spacial.shape.(Sphere) * 1.05)
			return
		}
	}


	// We COULD collect all collisions and do something off that. But this kinda feels good.
	for enemy in enemies.active {
		if checkCollision(enemy, projected) {
			collision := getCollision(enemy, projected)

			player.point = collision.point
			player.normal = collision.normal

			// if normal dot is > .7 // mostly facing the same way. sharp corners.
			if linalg.dot(collision.normal, velocity) > .7 {break}

			// Slide: Project velocity onto normal using dot product
			dot := linalg.dot(velocity, collision.normal)
			slide := velocity - (collision.normal * dot)

			player.spacial.pos += slide * getDelta()

			return
		}
	}

	player.spacial.pos += velocity * getDelta()
}

moveAndStop :: proc(
	player: ^Player,
	velocity: vec3,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyDummyPool,
) {

	// Projected movement
	projected := player.spacial
	projected.pos += velocity * getDelta()
	for obj in objs {
		if checkCollision(obj, projected) {
			return
		}
	}

	mapCheck: {
		dist := linalg.distance(projected.pos, vec3{})
		diff := MapGround.shape.(Sphere) - player.spacial.shape.(Sphere)
		player.edge = dist > diff
		if dist > diff {
			// Trying to get out
			col := getCollision(MapGround, projected)
			col.normal *= -1 // point inward

			player.point = col.point
			player.normal = col.normal

			// TODO: maybe add in sliding?
			player.pos = col.point + col.normal * (player.spacial.shape.(Sphere) * 1.05)
			return
		}
	}


	// We COULD collect all collisions and do something off that. But this kinda feels good.
	for enemy in enemies.active {
		if checkCollision(enemy, projected) {
			return
		}
	}

	player.spacial.pos += velocity * getDelta()
}

updatePlayerStateBase :: proc(player: ^Player, objs: [dynamic]EnvObj, enemies: ^EnemyDummyPool) {

	// Add a sub state - Idle and moving
	dir := getVector()
	// Update rotation while moving
	if dir != {} {
		target := player.spacial.pos + dir
		r := lookAtVec3(target, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, getDelta() * TURN_SPEED)
	}

	speed := getRootMotionSpeed(&player.animState, player.animSet, player.scale)
	moveAndSlide(player, dir * speed, objs, enemies)

	player.animState.current = (dir != {}) ? PLAYER.run : PLAYER.idle
}

updatePlayerStateDashing :: proc(
	dashing: ^playerStateDashing,
	player: ^Player,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyDummyPool,
	camera: ^rl.Camera3D,
) {
	dashing.timer.left -= getDelta()
	dir := getForwardPoint(player)

	speed := getRootMotionSpeed(&player.animState, player.animSet, player.scale)
	moveAndSlide(player, dir * speed * 2, objs, enemies)

	if dashing.timer.left <= 0 {
		enterPlayerState(player, playerStateBase{}, camera)
	}
}

updatePlayerStateAttack1 :: proc(
	attack: ^playerStateAttack1,
	player: ^Player,
	camera: ^rl.Camera3D,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyDummyPool,
) {
	attack.timer.left -= getDelta()

	speed := getRootMotionSpeed(&player.animState, player.animSet, player.scale)
	dir := getForwardPoint(player)
	moveAndSlide(player, dir * speed, objs, enemies)

	// Action
	progress := getAnimationProgress(player.animState, player.animSet)
	if progress >= attack.trigger && !attack.hasTriggered {
		attack.hasTriggered = true
		doAction(attack.action)
	}

	// Use animation legth for now, later go back to attack.timer
	if player.animState.finished {
		// if attack.timer.left <= 0 {
		if attack.comboInput && attack.comboCount < 1 {
			attack.comboInput = false
			attack.comboCount += 1
			attack.hasTriggered = false

			playSoundWhoosh()
			// attack.timer.left = attack.timer.max
			// Snap to mouse direction before next attack
			r := lookAtVec3(mouseInWorld(camera), player.spacial.pos)
			player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

			pos := getForwardPoint(player)
			spawnFlipbook(&player.trail, player.pos + pos, player.rot)

			player.animState.current = PLAYER.punch2
			return
		}
		enterPlayerState(player, playerStateBase{}, camera)
	}
}

updatePlayerStateAttackLong :: proc(
	attack: ^playerStateAttackLong,
	player: ^Player,
	camera: ^rl.Camera3D,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyDummyPool,
) {
	// Input check
	attack.timer.left -= getDelta()

	// Action
	progress := 1 - (attack.timer.left / attack.timer.max)
	if progress >= attack.trigger && !attack.hasTriggered {
		attack.hasTriggered = true
		doAction(attack.action)
	}

	r := lookAtVec3(mouseInWorld(camera), player.spacial.pos)
	player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)
	if progress > .5 { 	// Move .5 to struct?
		dir := getForwardPoint(player)
		moveAndStop(player, dir * MOVE_SPEED * 3, objs, enemies) // IF stoped -> trigger action? TODO: make func return collision
	}
	if attack.timer.left <= 0 {
		enterPlayerState(player, playerStateBase{}, camera)
	}
}

playerInputDash :: proc(player: ^Player, state: State, camera: ^rl.Camera3D) {
	// Make 'ability' for dash

	// if ability is interruptable
	if !hasEnoughStamina() {return}
	if !isKeyPressed(DASH) {return}
	if !canDash(player) {return}

	consumeStamina()
	enterPlayerState(player, state, camera)
}

// New AbilityState into State -> Passed in 
// OR Animation + ability info
enterPlayerState :: proc(player: ^Player, state: State, camera: ^rl.Camera3D) {
	// Enter logic into state
	stateChange :=
		reflect.get_union_variant_raw_tag(player.state) != reflect.get_union_variant_raw_tag(state)
	if stateChange {
		// assert? maybe this should not be a thing when we enter with checks
		player.animState.duration = 0
		// player.animState.frame = 0
		player.state = state
	}

	switch &s in player.state {
	case playerStateBase:
		// Look at movemment
		player.animState.speed = 1
		player.animState.current = PLAYER.idle
	case playerStateDashing:
		playSoundGrunt()
		// Snap to player movement or forward dir if not moving
		dir := getVector()
		s.timer.left = s.timer.max
		if dir == {} do dir = getForwardPoint(player)

		r := lookAtVec3(player.spacial.pos + dir, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

		player.animState.speed = s.speed
		player.animState.current = s.animation
	case playerStateAttack1:
		if !stateChange {
			progress := 1 - (s.timer.left / s.timer.max)
			if progress < .5 {return} 	// Only combo if past 70%
			s.comboInput = true
			return
		}

		playSoundWhoosh()
		s.timer.left = s.timer.max
		// Snap to mouse direction before attack
		r := lookAtVec3(mouseInWorld(camera), player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

		pos := getForwardPoint(player)
		spawnFlipbook(&player.trail, player.pos + pos, player.rot)

		player.animState.speed = s.speed
		player.animState.current = s.animation
	case playerStateAttackLong:
		// playSOundChARGEc
		// playSoundWhoosh() -> playSoundCharge
		s.timer.left = s.timer.max
		player.animState.speed = s.speed
		player.animState.current = s.animation
	}
}

State :: union {
	playerStateBase,
	playerStateDashing,
	playerStateAttack1, // DO we have one state of all abilities or each one has it's own?
	playerStateAttackLong, // DO we have one state of all abilities or each one has it's own?
	//	AbiltiyPreviewState
}

playerStateBase :: struct {}

playerStateDashing :: struct {
	// TODO: maybe add Actions or other fields
	timer:     Timer,
	animation: ANIMATION_NAMES, // TODO group these 2
	speed:     f32,
}

// Can only be set from player_input checks with other abilitys and not in update
playerStateAttack1 :: struct {
	// Can cancel
	cancellable:  bool,
	// Need timer to know how deep into the state we are
	timer:        Timer,
	// Animation Data
	animation:    ANIMATION_NAMES,
	speed:        f32,
	// Action Data TODO: Move into its own struct, take in array
	hasTriggered: bool,
	trigger:      f32, // between 0 and 1
	action:       Action,
	// CanChainTo?
	// combo
	comboInput:   bool,
	comboCount:   i32,
}

playerStateAttackLong :: struct {
	// Can cancel
	cancellable:  bool,
	// Need timer to know how deep into the state we are
	timer:        Timer,
	// Animation Data
	animation:    ANIMATION_NAMES,
	speed:        f32,
	// Action Data TODO: Move into its own struct, take in array
	hasTriggered: bool,
	trigger:      f32, // between 0 and 1
	action:       Action,
}


// Draw
drawPlayer :: proc(player: Player) {
	drawHitFlash(player.model, player.health)

	color := player.edge ? color1 : color2
	// rl.DrawSphereWires(player.pos, player.shape.(Sphere), 10, 10, color)
	// rl.DrawCylinderWires(player.pos, player.shape.(Sphere), player.shape.(Sphere), 2, 10, rl.BLACK)

	// rl.DrawSphere(player.point, .35, rl.RED)
	// rl.DrawCapsule(player.point, player.point + player.normal, .15, 8, 8, rl.PURPLE)
	// rl.DrawLine3D(player.pos, player.pos + player.normal, rl.PURPLE)


	// Draw player
	assert(player.scale != 0, "Scale is 0")
	rl.DrawModelEx(
		player.model,
		player.spacial.pos,
		UP,
		rl.RAD2DEG * player.spacial.rot,
		player.scale,
		rl.WHITE,
	)

}
