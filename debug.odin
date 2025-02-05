package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

debugInit :: proc(game: ^Game) {
	using game

}

debugUpdateGame :: proc(game: ^Game) {
	using game

	if rl.IsKeyPressed(.PAGE_DOWN) {
		// timeScale = clamp(timeScale - .25, 0, 3)
		MapGround.shape = clamp(MapGround.shape.(Sphere) - .25, 0, 20)
	}
	if rl.IsKeyPressed(.PAGE_UP) {
		// timeScale = clamp(timeScale + .25, 0, 3)
		MapGround.shape = clamp(MapGround.shape.(Sphere) + .25, 0, 20)
	}
	if rl.IsKeyPressed(.F) {
		spawnEnemySpawner(&spawners)
		// spawnEnemyDummy(&enemies, {})
		// spawnEnemyMele(&enemies, {})
		// spawnEnemyRange(&enemies, {})
	}

	// updateEnemiesRange(&enemiesRange, player^, &objs, enemyAbilities)
	updateEnemySpanwers(&spawners, &enemies, &objs)
}

debugDrawGame :: proc(game: ^Game) {
	using game
	// drawFlipbook(camera^, fire^, {5, 1.5, 0}, 3)

	drawEnemySpanwers(&spawners)
	// drawEnemiesRange(&enemiesRange)
}
