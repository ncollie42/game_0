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
	// Action 1 2 3 4 -> hand[1, 2, 3, 4] -> [0].one, .Attack
	switch &s in player.state {
	case playerStateBase:
		// NOTE: maybe rename from attack / power / spacial / ext.. might not be needed here.
		if isActionPressed(.One) {
			if !isActiveSlot(hand, .Attack) do break
			if !hasEnoughMana(&player.mana, hand[.Attack].cost) do break
			// Check CD
			useMana(&player.mana, hand[.Attack].cost)
			enterPlayerState(player, hand[.Attack].state, camera, &enemies)

			useAbilityCharge(&hand[.Attack]) // UsageLimit
			if !hasAbilityCharge(&hand[.Attack]) {
				discard(&deck, &hand, .Attack)
			}
		}
		if isActionPressed(.Two) {
			if !isActiveSlot(hand, .Power) do break
			if !hasEnoughMana(&player.mana, hand[.Power].cost) do break
			// Check CD
			useMana(&player.mana, hand[.Power].cost)
			enterPlayerState(player, hand[.Power].state, camera, &enemies)

			useAbilityCharge(&hand[.Power]) // UsageLimit
			if !hasAbilityCharge(&hand[.Power]) {
				discard(&deck, &hand, .Power)
			}
		}
		if isActionPressed(.Three) {
			if !isActiveSlot(hand, .Special) do break
			if !hasEnoughMana(&player.mana, hand[.Special].cost) do break
			// Check CD
			useMana(&player.mana, hand[.Special].cost)
			enterPlayerState(player, hand[.Special].state, camera, &enemies)

			useAbilityCharge(&hand[.Special]) // UsageLimit
			if !hasAbilityCharge(&hand[.Special]) {
				discard(&deck, &hand, .Special)
			}
		}
		if isActionPressed(.Four) {
			if !isActiveSlot(hand, .Ult) do break
			if !hasEnoughMana(&player.mana, hand[.Ult].cost) do break
			// Check CD
			useMana(&player.mana, hand[.Ult].cost)
			enterPlayerState(player, hand[.Ult].state, camera, &enemies)

			useAbilityCharge(&hand[.Ult]) // UsageLimit
			if !hasAbilityCharge(&hand[.Ult]) {
				discard(&deck, &hand, .Ult)
			}
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
		if !hasEnoughMana(&player.mana, 1) do break // TOOD: replace with actual cost
		if s.comboInput == true do break // already triggered

		useMana(&player.mana, hand[.Attack].cost)
		s.comboInput = true
	case playerStateAttackLeft:
		if isActionPressed(.Block) do enterPlayerState(player, playerStateBlocking{}, camera, &enemies)
		if !isActionPressed(.One) do break
		frame := i32(math.floor(player.animState.duration * FPS_30))
		if frame < s.cancel_frame do break
		if !hasEnoughMana(&player.mana, 1) do break // TOOD: replace with actual cost
		if s.comboInput == true do break // already triggered

		useMana(&player.mana, hand[.Attack].cost)
		s.comboInput = true
	case playerStateBlocking:
		if !isActionDown(.Block) {
			enterPlayerState(player, playerStateBase{}, camera, &enemies)
		}
	case playerStateBeam:
	}
}
