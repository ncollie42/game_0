package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "vendor:raylib"

isBlocking :: proc(player: Player) -> bool {
	_, blocking := player.state.(playerStateBlocking)
	return blocking
}

Attack :: struct {
	current: f32, // showing
	max:     f32,
}

canAttack :: proc(attack: ^Attack) -> bool {
	return attack.current >= 1
}

doAttack :: proc(attack: ^Attack) {
	attack.current -= 1
}

updateAttack :: proc(attack: ^Attack) {
	attack.current += getDelta() * .25 // very slow

	attack.current = clamp(attack.current, 0, attack.max)
}

// showing, max, pos, barwidth, height, 
drawAttackbar :: proc(attack: Attack, camera: ^rl.Camera, pos: vec3) {
	// TODO: - set width based on hp max
	width: f32 = healthBarWidth
	height: f32 = healthBareHeight
	pos2 := pos - {0, height / 2, 0} // buffer
	pos2 -= {0, height, 0} // hight over health bar
	pos2 += {-width / 2, 0, 0} // Move All the way to the right
	pos2 += {height / 2, 0, 0} // center

	for charge in 0 ..< attack.max {
		amount := math.max(0, math.min(1, attack.current - f32(charge)))

		pos3 := pos2 + {height * 1.5 * charge, 0, 0}
		color := rl.BLACK
		if amount == 1 do color = rl.BLUE

		rl.DrawBillboardRec(camera^, whiteTexture, {}, pos3, {height, height}, color)
	}
}
