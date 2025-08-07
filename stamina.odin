package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Stamina := struct {
	max:       f32, //MAX
	current:   f32,
	timeAtMax: f32,
	// CD
}{2, 2, 1} // TODO: add into player

STAMINA_RECHARGE_SPEED: f32 = .3 // 2 // .5

initStamina :: proc() {
	Stamina = {2, 2, 1}
}

updateStamina :: proc(player: ^Player) {
	if isDashing(player) do return
	Stamina.current += getDelta() * STAMINA_RECHARGE_SPEED
	Stamina.current = clamp(Stamina.current, 0, Stamina.max)
	if Stamina.current != Stamina.max do return
	Stamina.timeAtMax += getDelta()
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
	return Stamina.current >= 1
}

consumeStamina :: proc() {
	Stamina.current -= 1
	Stamina.timeAtMax = 0
}

drawStamina :: proc(camera: ^rl.Camera, pos: vec3) {
	if Stamina.current == Stamina.max {
		if Stamina.timeAtMax >= 1 do return
	}

	// TODO: - set width based on hp max
	width: f32 = healthBarWidth
	height: f32 = healthBareHeight
	aboveBlock: {
		// pos2 := pos + {0, height, 0} // buffer
		// pos2 += {0, height * 2, 0} // hight over block bar
		// pos2 += {-width / 2, 0, 0} // Move All the way to the right
		// pos2 += {height / 2, 0, 0} // center

		// for charge in 0 ..< Stamina.max {
		// 	amount := math.max(0, math.min(1, Stamina.current - f32(charge)))

		// 	pos3 := pos2 + {height * 1.5 * charge, 0, 0}
		// 	color := rl.BLACK
		// 	if amount == 1 do color = rl.WHITE

		// 	rl.DrawBillboardRec(camera^, whiteTexture, {}, pos3, {height, height}, color)
		// }
	}
	nextTohp: {
		pos2 := pos + {-height, 0, 0} // buffer
		// pos2 += {0, 0, height * 2, 0} // hight over block bar
		pos2 += {-width / 2, 0, 0} // Move All the way to the right
		pos2 -= {height / 2, 0, 0} // center

		for charge in 0 ..< Stamina.max {
			amount := math.max(0, math.min(1, Stamina.current - f32(charge)))

			pos3 := pos2 - {height * 1.5 * charge, 0, 0}
			color := rl.BLACK
			if amount == 1 do color = rl.WHITE

			rl.DrawBillboardRec(camera^, Textures[.White], {}, pos3, {height, height}, color)
		}
	}
}
