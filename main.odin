package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

engineerPath: cstring = "/home/nico/gameDev/resources/KayKit_Adventurers/m3d/Engineer.m3d"
druidPath: cstring = "/home/nico/gameDev/resources/KayKit_Adventurers/m3d/Druid.m3d"
minionPath: cstring = "/home/nico/gameDev/resources/KayKit_Skeletons/m3d/Skeleton_Minion.m3d"
SCREEN_W :: 1920 / 2
SCREEN_H :: 1080 / 2

main :: proc() {
	rl.SetTraceLogLevel(.ERROR)
	rl.SetConfigFlags({.VSYNC_HINT})

	rl.InitWindow(SCREEN_W, SCREEN_H, "Game")
	defer rl.CloseWindow()

	POS := vec3{0, 0, 0}

	camera := rl.Camera3D {
		position   = {0, 6, -5},
		target     = {},
		up         = {0, 1, 0},
		fovy       = 60,
		projection = .PERSPECTIVE,
	}

	// model := rl.LoadModel(modelPath)
	// assert(model.meshCount != 0, "No mesh")

	// animations := Animations{}
	// animations.anims = rl.LoadModelAnimations(modelPath, &animations.total)
	// assert(animations.total != 0, "No Anim")

	player := initPlayer(engineerPath)

	ANIMATION.anims = rl.LoadModelAnimations(engineerPath, &ANIMATION.total)
	assert(ANIMATION.total != 0, "No Anim")

	enemyPool := initEnemyDummies(minionPath)
	spawnDummyEnemy(&enemyPool, {1, 0, 2})

	melePool := initMeleInstances()

	ability := newSpawnMeleAbilityPlayer(&melePool, &player)

	f: f32 = 0
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		{ 	// :: Player Actions
			updatePlayer(&player, &camera)
			if isKeyPressed(BLOCK) {
				// doAction(ability.action)
				startAction(ability.action, &player, &camera)
			}
			if isKeyPressed(ACTION_0) {
				startAction(ability.action, &player, &camera)
			}
		}
		{ 	// :: Updates
			updateEnemyHitCollisions(&melePool, &enemyPool)

			updateEnemyDummies(&enemyPool, player)
		}
		{ 	// Draw
			rl.BeginMode3D(camera)
			defer rl.EndMode3D()
			rl.DrawGrid(100, .25)

			drawMeleInstances(&melePool)
			drawPlayer(player)
			drawEnemies(&enemyPool)
			rl.DrawSphere(mouseInWorld(&camera), .25, rl.ORANGE)
		}
		{ 	// :: UI
			// https://github.com/raysan5/raygui?tab=readme-ov-file
			// https://github.com/raysan5/raygui/blob/master/src/raygui.h
			// ~/Downloads/rguilayout_v4.0_linux_x64

			rl.GuiSlider({72, 160, 120, 16}, "TimeScale", nil, &timeScale, .1, 3.0)
			rl.GuiLabel({10, 30, 200, 20}, fmt.ctprint(player.spacial.rot))
			rl.DrawFPS(10, 10)
			// TODO: Draw time scale UI < ------ >
		}
	}
}

// TODO:
// 0. Damage Dummy
// 1. Enemy looking at player
// 2. Prevent casting animation while areadying doing animation.
// 6. Try out IamGui or other Clay?


// How many pools will I need to have, for sure 1 for player 1 for enemy and same for abilities. At least 4.
//   I might also make different kinds of ability pools or enemy pools if I don't group them together.
// player := initPlyaer
// enemies1 := InitEnemies1 // Type 1
// enemies2 := InitEnemies2 // Type 2
// abilitesPlayer := InitAbilities   // Type 1 for Player
// abilitesPlayer2 := InitAbilities2 // Type 2 for player
// abilitesPlayer3 := InitAbilities3 // Type 3 for player
// abilitesEnemies := InitAbilities  // Type 1 for Enemy
