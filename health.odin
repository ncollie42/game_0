package main

import "core:fmt"
import rl "vendor:raylib"


Health :: struct {
	max:      f32,
	current:  f32,
	showing:  f32,
	hitFlash: f32, // [0,1] 
}


updateHealth :: proc(hp: ^Health) {
	assert(hp.max > 0, "Unit needs to have HP")
	hp.showing = rl.Lerp(hp.showing, hp.current, .1)
	hp.hitFlash = rl.Clamp(hp.hitFlash - getDelta() * 4, 0, 1)

	// Temporary for player, reset HP
	// if hp.showing <= 0 {
	// 	hp.current = hp.max
	// }
}

hurt :: proc(hp: ^Health, amount: f32) {
	hp.current -= amount
	fmt.println("Hurt:", hp.max, hp.current)
	hp.hitFlash = 1
}

// Apply hit flash
drawHitFlash :: proc(model: rl.Model, hp: Health) {
	// TODO: assert shader
	// Is it slow to getShaderLocation every time, do we want to move this somewhere else?

	index := model.materialCount - 1 // imported models are 2, generated are 1
	assert(index >= 0, "index is not right")
	shader := model.materials[index].shader
	flashIndex := rl.GetShaderLocation(shader, "flash")

	data := hp.hitFlash
	rl.SetShaderValue(shader, flashIndex, &data, .FLOAT)
}
