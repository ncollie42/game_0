package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

debugInit :: proc(game: ^Game) {
	using game
	// fire = initFlipbookPool("resources/fire.png", 96, 96, 18)

	// -------------------------------------
	// modelPath: cstring = "resources/Human/base.m3d"
	// texturePath: cstring = "resources/Human/base.png"

	// player.model = loadModel(modelPath)
	// player.animSet = loadModelAnimations(modelPath)
	// // Mixamo -> 30 -> blender -> 60
	// fmt.println(PLAYER.idle, player.animSet.anims[PLAYER.idle].frameCount)
	// assert(
	// 	player.animSet.anims[PLAYER.idle].frameCount == 58,
	// 	"Frame count for idle doesn't match, Make sure you exported FPS properly",
	// )
	// texture := loadTexture(texturePath)
}

debugUpdateGame :: proc(game: ^Game) {
	using game

	if rl.IsKeyPressed(.G) {
		debug = !debug
	}
	if rl.IsKeyPressed(.F) {
		// spawnEnemySpawner(&spawners)
		// spawnXDummyEnemies(game, 10)

		spawnEnemyDummy(&enemies, {})
		// spawnEnemyMele(&enemies, {})
		// spawnEnemyRange(&enemies, {})
	}

	// updateEnemiesRange(&enemiesRange, player^, &objs, enemyAbilities)
	updateEnemySpanwers(&spawners, &enemies, &objs)
}

debugDrawGame :: proc(game: ^Game) {
	using game

	drawEnemySpanwers(&spawners)
	// drawEnemiesRange(&enemiesRange)
}
