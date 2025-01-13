package main

import clay "../../clay-odin"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

engineerPath: cstring = "/home/nico/gameDev/resources/KayKit_Adventurers/m3d/Engineer.m3d"
druidPath: cstring = "/home/nico/gameDev/resources/KayKit_Adventurers/m3d/Druid.m3d"

minionPath: cstring = "/home/nico/gameDev/resources/KayKit_Skeletons/m3d/Skeleton_Minion.m3d"

SCREEN_W :: 1920 / 2
SCREEN_H :: 1080 / 2

// PIXEL_LOOK
P_W :: SCREEN_W
P_H :: SCREEN_H
// P_W :: 1920 / 5
// P_H :: 1080 / 5


main :: proc() {
	rl.SetTraceLogLevel(.ERROR)
	// rl.SetConfigFlags({.WINDOW_RESIZABLE})
	// rl.SetConfigFlags({.WINDOW_HIGHDPI, .MSAA_4X_HINT})
	rl.SetConfigFlags({.VSYNC_HINT})

	rl.InitWindow(SCREEN_W, SCREEN_H, "Game")
	defer rl.CloseWindow()

	initClay()

	initAudio()
	defer rl.CloseAudioDevice()

	game := initGame()

	// TODO: maybe change to a union for each state
	app := enum {
		HOME,
		PLAYING,
		OTHER,
	}{}

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground({123, 121, 126, 255})

		switch app {
		case .HOME:
			if rl.IsKeyPressed(.SPACE) {
				resetGame(&game)
				app = .PLAYING
			}
		// Add some UI + button
		case .PLAYING:
			// switch xx { case playing : case paused : case powerUp } // TODO
			if isGameOver(game.player) {
				app = .HOME
				// reset values
			}
			updateGame(&game)
			drawGame(&game)
			drawGameUI(&game)
		case .OTHER:
		}
	}
}

isGameOver :: proc(player: ^Player) -> bool {
	return player.health.current <= 0
}

// EndTexture mode flushes any commands that are pending to the texture target. EndDrawing flushes the commands to the back buffer and then swaps the back with the front buffer
// @kolunmi
// also you probably will have to change the filtering on the texture before you draw it so that it doesn't look blurry
// rather pixelated
// btw, just to be extra clear, do not load the render texture every frame (edited)
// It remains valid across frames
// Unload it when you are done though
// Render textures are just framebuffers like the regular screen, so you can render whatever you want to them
// }

// Juice :: https://www.youtube.com/watch?v=3Omb5exWpd4
// TODO:

// Playable Demo
// -[]Game over screen with Clay
// Improve V1
// -[]Body block
// -[]Partcle
// -[]Combo
// -[]VFX
// -[]Juice
// -[]New character with animations
// -[]Better enemy AI

// How many pools will I need to have, for sure 1 for player 1 for enemy and same for abilities. At least 4.
//   I might also make different kinds of ability pools or enemy pools if I don't group them together.
// player := initPlyaer
// enemies1 := InitEnemies1 // Type 1
// enemies2 := InitEnemies2 // Type 2
// abilitesPlayer := InitAbilities   // Type 1 for Player
// abilitesPlayer2 := InitAbilities2 // Type 2 for player
// abilitesPlayer3 := InitAbilities3 // Type 3 for player
// abilitesEnemies := InitAbilities  // Type 1 for Enemy
