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
	minion := initPlayer(minionPath)

	ANIMATION.anims = rl.LoadModelAnimations(engineerPath, &ANIMATION.total)
	assert(ANIMATION.total != 0, "No Anim")

	f: f32 = 0
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		{ 	// Player Actions
			updatePlayer(&player, &camera)
		}
		{ 	// Updates

			// TODO update Enemy
			updateAnimation(minion.model, &minion.animation, ANIMATION)
		}
		{ 	// Draw
			rl.BeginMode3D(camera)
			defer rl.EndMode3D()
			rl.DrawGrid(100, .25)

			// rl.DrawModel(player.model, player.spacial.pos, 1, rl.WHITE)
			rl.DrawModelEx(
				player.model,
				player.spacial.pos,
				UP,
				rl.RAD2DEG * player.spacial.rot,
				1,
				rl.WHITE,
			)
			rl.DrawModel(minion.model, minion.spacial.pos, 1, rl.WHITE)
		}
		{ 	// UI
			// https://github.com/raysan5/raygui?tab=readme-ov-file
			// https://github.com/raysan5/raygui/blob/master/src/raygui.h
			// ~/Downloads/rguilayout_v4.0_linux_x64
			rl.DrawFPS(10, 10)
			// TODO: Draw time scale UI < ------ >
		}
	}
}

// TODO:
// 1. Create 2 dummy enemies on different animations ; can we share resources?
// 2. Have player moving
// 3. Enemy looking at player
// 4. Do I have a state machine? or how do I handle that?
// Get player Move, Attack_1, Dash... Do we use a enum for the given states?
