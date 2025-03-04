package main

import "core:fmt"

Stamina := struct {
	charges:       f32, //MAX
	currentCharge: f32,
	// CD
}{3, 0}

STAMINA_RECHARGE_SPEED: f32 = 2 //.5

updateStamina :: proc(player: ^Player) {
	if isDashing(player) do return
	Stamina.currentCharge += getDelta() * STAMINA_RECHARGE_SPEED
	Stamina.currentCharge = clamp(Stamina.currentCharge, 0, Stamina.charges)
}

canDash :: proc(player: ^Player) -> bool {
	dashing := isDashing(player)
	// Idle base state
	// _, base := player.state.(playerStateBase)
	return !dashing
}

isDashing :: proc(player: ^Player) -> bool {
	_, dashing := player.state.(playerStateDashing)
	return dashing
}

hasEnoughStamina :: proc() -> bool {
	return Stamina.currentCharge >= 1
}

consumeStamina :: proc() {
	Stamina.currentCharge -= 1
}
