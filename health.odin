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
	hp.showing = rl.Lerp(hp.showing, hp.current, .1)

	hp.hitFlash = rl.Clamp(hp.hitFlash - getDelta() * 4, 0, 1)

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
