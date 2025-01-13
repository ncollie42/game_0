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
	return player
}

// Look at tribes of midguard player controller for now
updatePlayerState :: proc(player: ^Player, camera: ^rl.Camera3D) {
	// dir := getVector()
	// target rotation is either indirection of movement or mouse location
	// target := player.spacial.pos + dir
	// if player.lookAtMouse { // if player.combatTimer > 0
	// target := mouseInWorld(camera)
	// }

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
			player.animation.current = .UNARMED_IDLE
		}

	case playerStateDashing:
		s.timer.left -= getDelta()
		dir := getForwardPoint(player)

		player.spacial.pos += dir * getDelta() * MOVE_SPEED * 2

		if s.timer.left <= 0 {
			enterPlayerState(player, playerStateBase{}, camera)
		}
	case playerStateAttack1:
		// Input check
		s.timer.left -= getDelta()
		// if s.comboInput && between range {
		// Do we use the same state and update attack values? or do we create a sub state enum
		// eneterState? or
		// update Timer
		// anim
		// action is same?
		// }
		if s.timer.left <= 0 {
			enterPlayerState(player, playerStateBase{}, camera)
		}
		// if player.animation.finished {
		// 	enterPlayerState(player, playerStateBase{}, camera)
		// }
		// State update
		progress := 1 - (s.timer.left / s.timer.max)
		// progress := getAnimationProgress(player.animation, ANIMATION)
		if progress >= s.trigger && !s.hasTriggered {
			s.hasTriggered = true
			doAction(s.action)
		}
	case:
		// If not state is set from init, go straight to Base
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
			// s.comboInput = true
			return
		}
		playSoundWhoosh()
		// if stateChange { set something to true or }
		s.timer.left = s.timer.max
		// Snap to mouse direction before aatack
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
	// comboInput:   bool,
}

// Draw

drawPlayer :: proc(player: Player) {
	drawHitFlash(player.model, player.health)

	rl.DrawModelEx(
		player.model,
		player.spacial.pos,
		UP,
		rl.RAD2DEG * player.spacial.rot,
		1,
		rl.WHITE,
	)
}
