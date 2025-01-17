package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "vendor:raylib"

Player :: struct {
	lookAtMouse:   bool,
	model:         rl.Model,
	animation:     Animation,
	using spacial: Spacial,
	using health:  Health,
	state:         State,
	// collision:   Collision,
	//Test
	point:         vec3,
	normal:        vec3,
}

MOVE_SPEED :: 5
TURN_SPEED :: 10.0

initPlayer :: proc(path: cstring) -> ^Player {
	player := new(Player)

	player.model = rl.LoadModel(path)
	assert(player.model.meshCount != 0, "No mesh")

	player.health = Health {
		max     = 5,
		current = 5,
	}

	shader := rl.LoadShader(nil, "shaders/flash.fs")
	player.model.materials[1].shader = shader
	player.spacial.shape = .8 //radius
	return player
}

moveAndSlide :: proc(
	player: ^Player,
	dir: vec3,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyDummyPool,
	speed: f32,
) {

	// Projected movement
	projected := player.spacial
	projected.pos += dir * getDelta() * MOVE_SPEED
	for obj in objs {
		if checkCollision(obj, projected) {
			collision := getCollision(obj, projected)

			player.point = collision.point
			player.normal = collision.normal

			// if normal dot is > .7 // mostly facing the same way. sharp corners.
			if linalg.dot(collision.normal, dir) > .7 {break}

			// Slide: Project velocity onto normal using dot product
			dot := linalg.dot(dir, collision.normal)
			slide := dir - (collision.normal * dot)

			player.spacial.pos += slide * getDelta() * speed

			// If colliding after moving, set possition at the edge of object
			if checkCollision(obj, player.spacial) {
				player.spacial.pos =
					collision.point + collision.normal * (player.spacial.shape.(Sphere) * 1.05)
			}
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
			if linalg.dot(collision.normal, dir) > .7 {break}

			// Slide: Project velocity onto normal using dot product
			dot := linalg.dot(dir, collision.normal)
			slide := dir - (collision.normal * dot)

			player.spacial.pos += slide * getDelta() * speed

			return
		}
	}

	player.spacial.pos += dir * getDelta() * speed
}
updatePlayerStateBase :: proc(player: ^Player, objs: [dynamic]EnvObj, enemies: ^EnemyDummyPool) {

	// Add a sub state - Idle and moving
	dir := getVector()
	moveAndSlide(player, dir, objs, enemies, MOVE_SPEED)

	// Update rotation while moving
	if dir != {} {
		target := player.spacial.pos + dir
		r := lookAtVec3(target, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, getDelta() * TURN_SPEED)
	}

	if dir != {} {
		player.animation.current = .RUNNING_A
	} else {
		player.animation.current = .UNARMED_IDLE
	}

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

	moveAndSlide(player, dir, objs, enemies, MOVE_SPEED * 2)

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
	// Input check
	attack.timer.left -= getDelta()
	fmt.println(attack.timer.left, player.animation.current, attack.comboCount)

	dir := getForwardPoint(player)
	moveAndSlide(player, dir, objs, enemies, MOVE_SPEED * .35)

	// if s.comboInput && between range {
	// Do we use the same state and update attack values? or do we create a sub state enum
	// eneterState? or
	// update Timer
	// anim
	// action is same?
	// }

	// Action
	progress := 1 - (attack.timer.left / attack.timer.max)
	if progress >= attack.trigger && !attack.hasTriggered {
		attack.hasTriggered = true
		doAction(attack.action)
	}

	if attack.timer.left <= 0 {
		// TODO: startAttack[0] - [1] - [2], Add array of statefields
		if attack.comboInput && attack.comboCount < 2 {
			attack.comboInput = false
			attack.comboCount += 1
			attack.hasTriggered = false

			fmt.println("COMBO", attack.comboCount)

			playSoundWhoosh()
			attack.timer.left = attack.timer.max
			// Snap to mouse direction before attack
			r := lookAtVec3(mouseInWorld(camera), player.spacial.pos)
			player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

			player.animation.speed = attack.speed
			player.animation.current = .UNARMED_MELEE_ATTACK_KICK
			// attack.comboCount == 1 ? .UNARMED_MELEE_ATTACK_PUNCH_A : .UNARMED_MELEE_ATTACK_KICK
			return
		}
		enterPlayerState(player, playerStateBase{}, camera)
	}
}

playerInputDash :: proc(player: ^Player, state: State, camera: ^rl.Camera3D) {
	// Make 'ability' for dash

	// check current state
	// check if already in dash?
	// if ability is interruptable
	if isKeyPressed(DASH) {
		enterPlayerState(player, state, camera)
	}

}

// New AbilityState into State -> Passed in 
// OR Animation + ability info
enterPlayerState :: proc(player: ^Player, state: State, camera: ^rl.Camera3D) {
	// Enter logic into state
	stateChange :=
		reflect.get_union_variant_raw_tag(player.state) != reflect.get_union_variant_raw_tag(state)
	if stateChange {
		// assert? maybe this should not be a thing when we enter with checks
		player.animation.frame = 0
		player.state = state
	}

	switch &s in player.state {
	case playerStateBase:
		// Look at movemment
		player.animation.speed = 1.0
		player.animation.current = .IDLE
	case playerStateDashing:
		playSoundGrunt()
		// Snap to player movement or forward dir if not moving
		dir := getVector()
		s.timer.left = s.timer.max
		if dir == {} do dir = getForwardPoint(player)

		r := lookAtVec3(player.spacial.pos + dir, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

		player.animation.speed = s.speed
		player.animation.current = s.animation
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

		player.animation.speed = s.speed
		player.animation.current = s.animation
	}
}

State :: union {
	playerStateBase,
	playerStateDashing,
	playerStateAttack1, // DO we have one state of all abilities or each one has it's own?
	//	AbiltiyPreviewState
}

playerStateBase :: struct {}

playerStateDashing :: struct {
	// TODO: maybe add Actions or other fields
	timer:     Timer,
	animation: ANIMATION_NAME, // TODO group these 2
	speed:     f32,
}

// Can only be set from player_input checks with other abilitys and not in update
playerStateAttack1 :: struct {
	// Can cancel
	cancellable:  bool,
	// Need timer to know how deep into the state we are
	timer:        Timer,
	// Animation Data
	animation:    ANIMATION_NAME,
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

// Draw
drawPlayer :: proc(player: Player) {
	drawHitFlash(player.model, player.health)

	// rl.DrawSphereWires(player.pos, player.shape.(Sphere), 10, 10, rl.BLACK)
	// rl.DrawCylinderWires(player.pos, player.shape.(Sphere), player.shape.(Sphere), 2, 10, rl.BLACK)

	// rl.DrawSphere(player.point, .35, rl.RED)
	// rl.DrawCapsule(player.point, player.point + player.normal, .15, 8, 8, rl.PURPLE)
	// rl.DrawLine3D(player.pos, player.pos + player.normal, rl.PURPLE)

	rl.DrawModelEx(
		player.model,
		player.spacial.pos,
		UP,
		rl.RAD2DEG * player.spacial.rot,
		1,
		rl.WHITE,
	)
}
