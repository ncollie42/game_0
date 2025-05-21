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

// hurt :: proc(hp: ^Health, amount: f32, armor :f32) {
hurt :: proc(hp: ^Health, amount: f32) {
	hp.current -= amount
	fmt.println("Hurt:", hp.max, hp.current, amount)
	hp.hitFlash = 1
}

// Apply hit flash
drawHitFlash :: proc(model: rl.Model, hp: Health) {
	// TODO: assert shader
	// Is it slow to getShaderLocation every time, do we want to move this somewhere else?

	index := model.materialCount - 1 // imported models are 2, generated are 1
	assert(index >= 0, "index is not right")
	shader := model.materials[index].shader
	// TODO: set inside shader.locs :: or do it in the spot
	flashIndex := rl.GetShaderLocation(shader, "flash")

	data := hp.hitFlash
	rl.SetShaderValue(shader, flashIndex, &data, .FLOAT)
}

drawHealthbars :: proc(camera: ^rl.Camera, enemies: ^EnemyPool) {
	for enemy in enemies.active {
		if enemy.health.current == enemy.health.max {
			continue
		}
		drawHealthbar(enemy.health, camera, enemy.pos + enemy.dmgIndicatorOffset)
	}
}

healthBarWidth :: 1.0
healthBareHeight :: .15
drawHealthbar :: proc(hp: Health, camera: ^rl.Camera, pos: vec3) {
	// TODO: - set width based on hp max
	width: f32 = healthBarWidth
	height: f32 = healthBareHeight
	rl.DrawBillboardRec(camera^, whiteTexture, {}, pos, {width, height}, rl.BLACK)
	percent := hp.showing / hp.max
	whitePos := pos + {0, 0, -.003} // Bring forward from black
	whitePos += {(-percent / 2) * width + width / 2, 0, 0} // Center left
	rl.DrawBillboardRec(camera^, whiteTexture, {}, whitePos, {width * percent, height}, rl.WHITE)
	percent = hp.current / hp.max
	redPos := pos + {0, 0, -.006} // Bring forward from white
	redPos += {(-percent / 2) * width + width / 2, 0, 0} // Center left
	// redPos += {-(percent / 2 + width / 2), 0, 0} // Center left
	//Make 1.1 bigger, to prevent forground issues with white and black
	rl.DrawBillboardRec(camera^, whiteTexture, {}, redPos, {width * percent, height} * 1.1, rl.RED)
	// We're using 3 billboards, maybe we can use a single billboard with a shader in the future?
}
