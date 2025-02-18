package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

debugInit :: proc(game: ^Game) {
	using game

}

debugUpdateGame :: proc(game: ^Game) {
	using game

	if rl.IsKeyPressed(.F) {
		// spawnEnemySpawner(&spawners)
		// spawnXDummyEnemies(game, 10)

		// spawnEnemyDummy(&enemies, {})
		spawnEnemyMele(&enemies, {})
		// spawnEnemyRange(&enemies, {})
	}

	if rl.IsKeyPressed(.UP) {
		timeScale += .25
		fmt.println(timeScale)
	}
	if rl.IsKeyPressed(.DOWN) {
		timeScale -= .25
		fmt.println(timeScale)
	}

	// updateEnemiesRange(&enemiesRange, player^, &objs, enemyAbilities)
	updateEnemySpanwers(&spawners, &enemies, &objs)
}

debugDrawGame :: proc(game: ^Game) {
	using game

}
