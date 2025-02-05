package main

import "core:fmt"
import rl "vendor:raylib"

// Make global?  or put into game obj. we're only going to have 1.
Waves := struct {
	duration:     f32,
	waveDuration: f32,
	state:        enum {
		ONE,
		TWO,
		THREE,
		LAST,
	},
}{}

updateWaves :: proc(game: ^Game) {
	Waves.duration += rl.GetFrameTime()
	Waves.waveDuration += rl.GetFrameTime()

	switch Waves.state {
	case .ONE:
		// Start next wave right away
		Waves.waveDuration = 0
		// spawnXDummyEnemies(game, 5)
		spawnEnemySpawner(&game.spawners)
		Waves.state = .TWO
	case .TWO:
		// Start next wave after X seconds
		if Waves.waveDuration > 30 {
			Waves.waveDuration = 0
			// spawnXDummyEnemies(game, 10)
			spawnEnemySpawner(&game.spawners)
			Waves.state = .TWO
		}
	case .THREE:
		// Start next wave after X seconds
		if Waves.waveDuration > 30 {
			Waves.waveDuration = 0
			// spawnXDummyEnemies(game, 10)
			spawnEnemySpawner(&game.spawners)
			Waves.state = .THREE
		}
	case .LAST:

	}
}
