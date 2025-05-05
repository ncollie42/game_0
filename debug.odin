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
	model = rl.LoadModel("/home/nico/Downloads/rock.glb")
}

debugUpdateGame :: proc(game: ^Game) {
	using game

	// spawnEnemySpawner(&spawners)
	// spawnXDummyEnemies(game, 10)
	if rl.IsKeyPressed(.F) {
		spawn := pointAtEdgeOfMap()
		spawnEnemyMele(&enemies, spawn * 1.4)
	}
	if rl.IsKeyPressed(.G) {
		spawnEnemyRange(&enemies, {})
	}
	if rl.IsKeyPressed(.H) {
		spawnEnemyGiant(&enemies, {})
	}
	if rl.IsKeyPressed(.J) {
		spawnEnemyDummy(&enemies, {})
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

	drawHealthbar(player.health, camera, player.pos + {0, 2.8, 0})
	drawEnemySpanwers(&spawners)
}
