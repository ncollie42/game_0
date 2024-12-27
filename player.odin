package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

// Move to spacial file?
Spacial :: struct {
	rot:     f32, // rotation / Orientation
	pos:     vec3, // position
	dir:     vec3, // what direction it's going towards  - using for projectiles ; not sure if we need; maybe change to velocity?
	radious: f32, // For collision
}

Player :: struct {
	lookAtMouse: bool,
	model:       rl.Model,
	animation:   Animation,
	spacial:     Spacial,
	state:       State,
	// collision:   Collision,
}

MOVE_SPEED :: 5
TURN_SPEED :: 10.0

initPlayer :: proc(path: cstring) -> Player {
	player := Player{}
	player.model = rl.LoadModel(path)
	assert(player.model.meshCount != 0, "No mesh")

	player.spacial.dir = {0, 0, 1}
	// enterPlayerState(&player, playerStateBase{})
	return player
}

// Look at tribes of midguard player controller for now
updatePlayer :: proc(player: ^Player, camera: ^rl.Camera3D) {
	// dir := getVector()
	// target rotation is either indirection of movement or mouse location
	// target := player.spacial.pos + dir
	// if player.lookAtMouse { // if player.combatTimer > 0
	// target := mouseInWorld(camera)
	// }

	// UPDATE for each State
	switch &s in player.state {
	case playerStateBase:
		dir := getVector()
		player.spacial.pos += dir * getDelta() * MOVE_SPEED

		// Update rotation while moving
		if dir != {} {
			target := player.spacial.pos + dir
			r := lookAtVec3(target, player.spacial.pos)
			player.spacial.rot = lerpRAD(player.spacial.rot, r, getDelta() * TURN_SPEED)
		}

		if dir != {} {
			player.animation.current = .RUNNING_A
		} else {
			player.animation.current = .IDLE
		}

		if isKeyPressed(DASH) {
			enterPlayerState(player, playerStateDashing{}, camera)
		}
	case playerStateDashing:
		dir := getPlayerForwardPoint(player)

		player.spacial.pos += dir * getDelta() * MOVE_SPEED * 2
		if player.animation.finished {
			enterPlayerState(player, playerStateBase{}, camera)
		}
	case playerStateAttack1:
		if isKeyPressed(DASH) { 	// if ability is interruptable
			enterPlayerState(player, playerStateDashing{}, camera)
		}
		if player.animation.finished {
			enterPlayerState(player, playerStateBase{}, camera)
		}
		// State update
		progress := getAnimationProgress(player.animation, ANIMATION)
		if progress >= s.trigger && !s.hasTriggered {
			s.hasTriggered = true
			doAction(s.action)
		}
	case:
		// If not state is set from init, go straight to Base
		enterPlayerState(player, playerStateBase{}, camera)
	}

	updateAnimation(player.model, &player.animation, ANIMATION)
}

getPlayerForwardPoint :: proc(player: ^Player) -> vec3 {
	// Return a point between 0 1 [0,0]
	mat := rl.MatrixRotateY(player.spacial.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	point := rl.Vector3Transform({}, mat)
	point = linalg.normalize(point)
	return point
}

// New AbilityState into State -> Passed in 
// OR Animation + ability info
enterPlayerState :: proc(player: ^Player, state: State, camera: ^rl.Camera3D) {
	// fmt.println("Going into", state)
	// Enter logic into state
	player.state = state
	player.animation.frame = 0
	switch &s in player.state {
	case playerStateBase:
		// Look at movemment
		player.animation.current = .IDLE
	case playerStateDashing:
		// Snap to player movement or forward dir if not moving
		dir := getVector()
		if dir == {} do dir = getPlayerForwardPoint(player)

		r := lookAtVec3(player.spacial.pos + dir, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

		player.animation.current = .DODGE_FORWARD
	case playerStateAttack1:
		// Snap to mouse direction before aatack
		r := lookAtVec3(mouseInWorld(camera), player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

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

playerStateDashing :: struct {}

playerStateAttack1 :: struct {
	hasTriggered: bool,
	trigger:      f32, // between 0 and 1
	animation:    ANIMATION_NAME,
	action:       Action,
	// canCancel: bool, // Do we put this here?
	// Location??
	// Speed?
}

// Draw

drawPlayer :: proc(player: Player) {
	rl.DrawModelEx(
		player.model,
		player.spacial.pos,
		UP,
		rl.RAD2DEG * player.spacial.rot,
		1,
		rl.WHITE,
	)
}
