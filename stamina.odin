package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Stamina := struct {
	charges:       f32, //MAX
	currentCharge: f32,
	// CD
}{2, 2}

STAMINA_RECHARGE_SPEED: f32 = .3 // 2 // .5

updateStamina :: proc(player: ^Player) {
	if isDashing(player) do return
	Stamina.currentCharge += getDelta() * STAMINA_RECHARGE_SPEED
	Stamina.currentCharge = clamp(Stamina.currentCharge, 0, Stamina.charges)
	// fmt.println(Stamina.currentCharge)
}

canDash :: proc(player: ^Player) -> bool {
	dashing := isDashing(player)
	// Idle base state
	// _, base := player.state.(playerStateBase)
	return !dashing
}

isDashing :: proc(player: ^Player) -> bool {
	_, dashing := player.state.(playerStateDashing)
	_, bashing := player.state.(playerStateBlockBash)
	return dashing || bashing
}

hasEnoughStamina :: proc() -> bool {
	return Stamina.currentCharge >= 1
}

consumeStamina :: proc() {
	Stamina.currentCharge -= 1
}

drawStamina :: proc(camera: ^rl.Camera, pos: vec3) {
	// TODO: - set width based on hp max
	width: f32 = healthBarWidth
	height: f32 = healthBareHeight
	pos2 := pos - {0, height / 2, 0} // buffer
	pos2 -= {0, height, 0} // hight over health bar
	pos2 += {-width / 2, 0, 0} // Move All the way to the right
	pos2 += {height / 2, 0, 0} // center

	for charge in 0 ..< Stamina.charges {
		amount := math.max(0, math.min(1, Stamina.currentCharge - f32(charge)))

		pos3 := pos2 + {height * 1.5 * charge, 0, 0}
		color := rl.BLACK
		if amount == 1 do color = rl.WHITE

		rl.DrawBillboardRec(camera^, whiteTexture, {}, pos3, {height, height}, color)
	}
}
