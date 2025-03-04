package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"


updatePlayerInput :: proc(game: ^Game) {
	using game

	if isDashing(player) {
		return
	}
	// Player Actions
	// :: SM Input
	playerInputDash(player, dash, camera)
	// TODO: Put into func swap with 'Hand' logic stuff
	if rl.IsMouseButtonPressed(.LEFT) {
		enterPlayerState(player, normalAttack.state, camera)
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		enterPlayerState(player, chargeAttack.state, camera)
	}
	if rl.IsKeyPressed(.ONE) {
		rl.ToggleBorderlessWindowed() // Less hassle
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
