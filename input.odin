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

	switch &s in player.state {
	case playerStateBase:
		if isActionPressed(.One) && canAttack(&player.mana) && hasActiveSlot(hand, .Attack) {
			useMana(&player.mana, hand[.Attack].cost)
			enterPlayerState(player, hand[.Attack].state, camera, &enemies)
		}
		if isActionPressed(.Two) && canAttack(&player.mana) && hasActiveSlot(hand, .Power) {
			useMana(&player.mana, hand[.Power].cost)
			enterPlayerState(player, hand[.Power].state, camera, &enemies)
		}
		if isActionPressed(.Block) {
			enterPlayerState(player, playerStateBlocking{}, camera, &enemies)
		}
	case playerStateDashing:
	case playerStateAttack:
		if isActionPressed(.Block) do enterPlayerState(player, playerStateBlocking{}, camera, &enemies)
		if !isActionPressed(.One) do break
		frame := i32(math.floor(player.animState.duration * FPS_30))
		if frame < s.cancel_frame do break
		if !canAttack(&player.mana) do break
		if s.comboInput == true do break // already triggered

		useMana(&player.mana, hand[.Attack].cost)
		s.comboInput = true
	case playerStateAttackLeft:
		if isActionPressed(.Block) do enterPlayerState(player, playerStateBlocking{}, camera, &enemies)
		if !isActionPressed(.One) do break
		frame := i32(math.floor(player.animState.duration * FPS_30))
		if frame < s.cancel_frame do break
		if !canAttack(&player.mana) do break
		if s.comboInput == true do break // already triggered

		useMana(&player.mana, hand[.Attack].cost)
		s.comboInput = true
	case playerStateBlocking:
		if !isActionDown(.Block) {
			enterPlayerState(player, playerStateBase{}, camera, &enemies)
		}
	}
}
