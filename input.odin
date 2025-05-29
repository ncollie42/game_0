package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"


updatePlayerInput :: proc(game: ^Game) {
	using game

	if isDashing(player) {
		return
	}
	// TODO: Put into func swap with 'Hand' logic stuff
	// Player Actions
	// :: SM Input
	playerInputDash(player, dash, camera, &enemies)
	if rl.IsKeyPressed(.ONE) {
		rl.ToggleBorderlessWindowed() // Less hassle, full screen breaks
	}
	switch &s in player.state {
	case playerStateBase:
		if rl.IsMouseButtonPressed(.LEFT) && canAttack(&player.attack) {
			enterPlayerState(player, normalAttack.state, camera, &enemies)
		}
		if rl.IsMouseButtonDown(.RIGHT) && canBlock(&player.block) {
			enterPlayerState(player, playerStateBlocking{}, camera, &enemies)
		}
	case playerStateDashing:
	case playerStateAttack:
		if rl.IsMouseButtonDown(.RIGHT) && canBlock(&player.block) {
			enterPlayerState(player, playerStateBlocking{}, camera, &enemies)
		}
		if !rl.IsMouseButtonDown(.LEFT) do break
		frame := i32(math.floor(player.animState.duration * FPS_30))
		if frame < s.cancel_frame do return
		if !canAttack(&player.attack) do return
		s.comboInput = true
	case playerStateAttackLeft:
		if !rl.IsMouseButtonDown(.LEFT) do break
		frame := i32(math.floor(player.animState.duration * FPS_30))
		if frame < s.cancel_frame do return
		if !canAttack(&player.attack) do return
		s.comboInput = true
	case playerStateBlocking:
		if rl.IsMouseButtonUp(.RIGHT) {
			enterPlayerState(player, playerStateBase{}, camera, &enemies)
		}

		if !hasEnoughStamina() do break
		return

	// if !isTimerReady(player.bashCD) do break
	// result := getEnemyHitResult(&enemies, camera)
	// // TODO: Check distance
	// // TODO: play sound if we can dash
	// if !result.hit do break
	// // Enter Dashing attack if inrange
	// if rl.IsMouseButtonPressed(.LEFT) {
	// 	// startTimer(&player.bashCD)
	// 	consumeStamina()

	// 	enterPlayerState(player, normalAttack.state, camera, &enemies)
	// 	// enterPlayerState(
	// 	player,
	// 	playerStateBlockBash{target = result.pos, action = bashingAction},
	// 	camera,
	// 	&enemies,
	// )
	// }
	case playerStateBlockBash:

	}
}


// Example on how to maybe do button hold / regular click for attacks
// MousePress := union {
// 	Idle,
// 	Press,
// }{}

// Idle :: struct {}
// Press :: struct {
// 	duration: f32,
// }
// CheckMousePress: {
// 	_, idle := MousePress.(Idle)
// 	_, longAttack := player.state.(playerStateAttackLong)

// 	if rl.IsMouseButtonPressed(.LEFT) && idle && !longAttack { 	// Don't attack while doing long Attack
// 		MousePress = Press{}
// 	}

// 	switch &state in MousePress {
// 	case Idle:
// 	case Press:
// 		state.duration += getDelta()

// 		if state.duration > .3 { 	// Durration of a normal auto
// 			MousePress = Idle{}
// 			enterPlayerState(player, chargeAttack.state, camera)
// 		}
// 		if rl.IsMouseButtonReleased(.LEFT) {
// 			MousePress = Idle{}
// 			enterPlayerState(player, normalAttack.state, camera)
// 		}
// 	case:
// 		state = Idle{}
// 	}
// }
