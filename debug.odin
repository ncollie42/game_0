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
		spawnEnemyMele(&enemies, {})
	}
	if rl.IsKeyPressed(.H) {
		spawnEnemyDummy(&enemies, {})
		// spawnEnemyRange(&enemies, {})
	}
	// TODO: add range small guy in next
	if rl.IsKeyPressed(.G) {
		spawnEnemyRange(&enemies, {})
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

// Z coordinate is compared to the appropriate entry in the depth buffer, if that pixel has already been drawn with a closer depth buffer value, then our new pixel isn't rendered at all, it's behind something that is already on the screen.
// Need to render back to front, with my camera, back is positive.
// Z:: [1,-1] 
// Y:: [-1,1]
debugDrawGame :: proc(game: ^Game) {
	using game

	drawEnemySpanwers(&spawners)
}
