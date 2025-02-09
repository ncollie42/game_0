package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

pool := ImpactPool{}
debugInit :: proc(game: ^Game) {
	using game

	// path: cstring = "/home/nico/Downloads/sprite-sheet.png"
	// pool = initImpactPool2(path, 640 / 5, 256 / 2, 10)
	path: cstring = "/home/nico/Downloads/smear.png"
	pool = initImpactPool(path, 240 / 5, 48, 5)
	// path: cstring = "resources/impact.png"
	// pool = initImpactPool2(path, 305, 383, 27)
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
	if rl.IsKeyPressed(.G) {
		debug = !debug
	}
	if rl.IsKeyPressed(.F) {
		// pos := getForwardPoint(player)
		// spawnImpact2Dir(&pool, player.pos + pos, player.rot)

		// spawnEnemySpawner(&spawners)
		// spawnXDummyEnemies(game, 10)
		// spawnEnemyDummy(&enemies, {})
		spawnEnemyMele(&enemies, {})
		// spawnEnemyRange(&enemies, {})
	}

	updateImpactPool(&pool, 10)
	// updateEnemiesRange(&enemiesRange, player^, &objs, enemyAbilities)
	updateEnemySpanwers(&spawners, &enemies, &objs)
}

debugDrawGame :: proc(game: ^Game) {
	using game
	// drawFlipbook(camera^, fire^, {5, 1.5, 0}, 3)

	drawImpactPoolFlat(camera^, pool)
	// drawImpactPool(camera^, pool)
	drawEnemySpanwers(&spawners)
	// drawEnemiesRange(&enemiesRange)
}
