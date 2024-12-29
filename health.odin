package main

import "core:fmt"
import rl "vendor:raylib"


Health :: struct {
	max:          f32,
	current:      f32,
	showing:      f32,
	hitFlashLerp: f32, // between 0 and 255
}


updateHealth :: proc(hp: ^Health) {
	hp.showing = rl.Lerp(hp.showing, hp.current, .1)

	// animateToTargetf32(&hp.hitFlashLerp, 255, getDelta())
	hp.hitFlashLerp = rl.Lerp(hp.hitFlashLerp, 255, getDelta() * 2)

	if hp.showing <= 0 {
		// Game Over if player
		//TODO: Include/Create a game state struct - use to end game
		hp.current = hp.max
	}
}

hurt :: proc(hp: ^Health, amount: f32) {
	hp.current -= amount
	fmt.println("Ouch!", hp.max, hp.current)
}
