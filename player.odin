package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// Move to spacial file?
Spacial :: struct {
	rot: f32, // rotation / Orientation
	pos: vec3, // position
	dir: vec3, // what direction it's going towards  - using for projectiles ; not sure if we need; maybe change to velocity?
}

Player :: struct {
	lookAtMouse: bool,
	model:       rl.Model,
	animation:   Animation,
	spacial:     Spacial,
	state:       State,
}

MOVE_SPEED :: 5
TURN_SPEED :: 10.0

initPlayer :: proc(path: cstring) -> Player {
	player := Player{}
	player.model = rl.LoadModel(path)
	assert(player.model.meshCount != 0, "No mesh")

	player.spacial.dir = {0, 0, 1}
	enterPlayerState(&player, playerStateBase{})
	return player
}

updatePlayer :: proc(player: ^Player, camera: ^rl.Camera3D) {
	// TODO: make dash only move player in direction it's going
	// TODO: Add velocity to movement
	dir := getVector()
	// player.spacial.pos += dir * getDelta() * MOVE_SPEED

	// target rotation is either indirection of movement or mouse location
	target := player.spacial.pos + dir
	if player.lookAtMouse {
		target = mouseInWorld(camera)
	}

	// UPDATE for each State
	switch &s in player.state {
	case playerStateBase:
		player.spacial.pos += dir * getDelta() * MOVE_SPEED

		// Update rotation
		if dir != {} {
			r := lookAtVec3(target, player.spacial.pos)
			player.spacial.rot = lerpRAD(player.spacial.rot, r, getDelta() * TURN_SPEED)
			player.spacial.dir = dir
		}

		if dir != {} {
			player.animation.current = .RUNNING_A
		} else {
			player.animation.current = .IDLE
		}

		if isKeyPressed(DASH) {
			enterPlayerState(player, playerStateDashing{})
		}
	case playerStateDashing:
		player.spacial.pos += player.spacial.dir * getDelta() * MOVE_SPEED * 2
		// Or use Mouse if dir == 0?
		if player.animation.finished {
			enterPlayerState(player, playerStateBase{})
		}
	case playerStateAttack1:
		if isKeyPressed(DASH) {
			enterPlayerState(player, playerStateDashing{})
		}
		if player.animation.finished {
			enterPlayerState(player, playerStateBase{})
		}
		// State update
		progress := getAnimationProgress(player.animation, ANIMATION)
		if progress >= s.trigger && !s.hasTriggered {
			s.hasTriggered = true
			doAction(s.action)
		}
	}

	updateAnimation(player.model, &player.animation, ANIMATION)
}

// New AbilityState into State -> Passed in 
// OR Animation + ability info
enterPlayerState :: proc(player: ^Player, state: State) {
	fmt.println("Going into", state)
	// Enter logic into state
	player.state = state
	player.animation.frame = 0
	switch &s in player.state {
	case playerStateBase:
		player.animation.current = .IDLE
	case playerStateDashing:
		r := lookAtVec3(player.spacial.pos + player.spacial.dir, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)
		player.animation.current = .DODGE_FORWARD
	case playerStateAttack1:
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
