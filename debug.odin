package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

model: rl.Model
// animState: AnimationState = {
// 	current = ENEMY.hurt,
// 	speed   = 1,
// }
// animSet: AnimationSet
debugInit :: proc(game: ^Game) {
	using game
}

debugUpdateGame :: proc(game: ^Game) {
	using game

	grid := getSafePointInGrid(&game.enemies, player)
	mouse := mouseInWorld(camera)
	random := getRandomPoint()

	if rl.IsKeyPressed(.Q) {
	}
	if rl.IsKeyPressed(.F) {
		spawnEnemy(&enemies, grid, .Range, true)
	}
	if rl.IsKeyPressed(.G) {
		spawnEnemy(&enemies, grid, .Mele, true)
	}
	if rl.IsKeyPressed(.H) {
		spawnEnemy(&enemies, mouse, .Range, true)
	}
	if rl.IsKeyPressed(.J) {
		debug = !debug
	}
	if rl.IsKeyPressed(.UP) {
		timeScale += .25
		fmt.println(timeScale)
	}
	if rl.IsKeyPressed(.DOWN) {
		timeScale -= .25
		fmt.println(timeScale)
	}

	updateEnemySpanwers(&spawners, &enemies, &objs)
}

// Z coordinate is compared to the appropriate entry in the depth buffer, if that pixel has already been drawn with a closer depth buffer value, then our new pixel isn't rendered at all, it's behind something that is already on the screen.
// Need to render back to front, with my camera, back is positive.
// Z:: [1,-1] 
// Y:: [-1,1]
debug := false
debugDrawGame :: proc(game: ^Game) {
	using game

	// if debug do getEnemyHitResult(&enemies, camera)

}
