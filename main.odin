package main

import clay "../../clay-odin"
import "core:fmt"
import "core:math"
import "core:reflect"
import rl "vendor:raylib"

engineerPath: cstring = "/home/nico/gameDev/resources/KayKit_Adventurers/m3d/Engineer.m3d"
druidPath: cstring = "/home/nico/gameDev/resources/KayKit_Adventurers/m3d/Druid.m3d"

minionPath: cstring = "/home/nico/gameDev/resources/KayKit_Skeletons/m3d/Skeleton_Minion.m3d"

SCREEN_W :: 1920 / 2
SCREEN_H :: 1080 / 2

main :: proc() {
	rl.SetTraceLogLevel(.ERROR)
	// rl.SetConfigFlags({.WINDOW_HIGHDPI, .MSAA_4X_HINT})
	rl.SetConfigFlags({.VSYNC_HINT})

	rl.InitWindow(SCREEN_W, SCREEN_H, "Game")
	defer rl.CloseWindow()

	initClay()
	camera := newCamera()

	player := initPlayer(engineerPath)

	ANIMATION.anims = rl.LoadModelAnimations(engineerPath, &ANIMATION.total)
	assert(ANIMATION.total != 0, "No Anim")

	enemyPool := initEnemyDummies(minionPath)
	spawnDummyEnemy(&enemyPool, {1, 0, 2})
	spawnDummyEnemy(&enemyPool, {2, 0, 3})

	melePool := initMeleInstances()

	ability := newSpawnMeleAbilityPlayer(&melePool, &player)
	p := [dynamic]vec3{}
	ability2 := newSpawnCubeAbilityPlayer(&p, &player)
	dash := newPlayerDashAbility(&player, &camera)

	f: f32 = 0
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground({123, 121, 126, 255})
		{ 	// :: Player Actions
			{
				// SM :: Input
				playerInputDash(&player, dash, &camera)
				// TODO: Put into func; swap with 'Hand' logic stuff
				if isKeyPressed(BLOCK) {
					// doAction(ability.action)
					enterPlayerState(&player, ability.state, &camera)
				}
				if isKeyPressed(ACTION_0) {
					enterPlayerState(&player, ability2.state, &camera)
				}
				if rl.IsKeyPressed(.ONE) {
					rl.ToggleBorderlessWindowed() // Less hassle
				}
			}
			// SM :: Update
			updatePlayerState(&player, &camera)
		}
		{ 	// :: Updates
			updateAnimation(player.model, &player.animation, ANIMATION)

			updateEnemyHitCollisions(&melePool, &enemyPool)
			updateEnemyDummies(&enemyPool, player)
			updateHitStop()
			updateCameraPos(&camera, player)
			updateCameraShake(&camera)
		}
		{ 	// Draw
			rl.BeginMode3D(camera)
			defer rl.EndMode3D()
			rl.DrawGrid(100, .25)

			drawMeleInstances(&melePool)
			drawPlayer(player)
			drawEnemies(&enemyPool)

			for x in p {
				rl.DrawSphere(x, .3, rl.BLACK)
			}
			drawCamera(&camera)
		}
		{ 	// :: UI
			clayFrameSetup()
			clay.BeginLayout()
			defer {
				layout := clay.EndLayout()
				clayRaylibRender(&layout)
			}

			// Start UI
			if clay.UI(clay.ID("root"), clay.Layout(layoutRoot)) {
				if clay.UI(
					clay.ID("top"),
					clay.Layout(
						{sizing = {height = clay.SizingPercent(.2), width = clay.SizingGrow({})}},
					),
					clay.Rectangle(testPannel),
				) {}
				if clay.UI(
					clay.ID("center"),
					clay.Layout({sizing = expand}),
					// clay.Rectangle(testPannel),
				) {
					// if debug... show
					if clay.UI(
						clay.ID("DEBUG"),
						clay.Layout(layoutDebug),
						clay.Rectangle(debugPannel),
					) {
						uiText("DEBUG", .large)
						devider()
						uiText(fmt.tprintf("%d FPS", rl.GetFPS()), .mid)
						for enemy in enemyPool.active {
							state := reflect.union_variant_type_info(enemy.state)
							uiText(fmt.tprint(state), .mid)
							debugEnemyHPBar(enemy.health)
						}
					}
				}
				if clay.UI(
					clay.ID("bottom"),
					clay.Layout(
						{
							sizing = {
								height = clay.SizingPercent(.2),
								width = clay.SizingGrow({}),
							},
							childGap = childGap,
						},
					),
				) {
					if clay.UI(
						clay.ID("HP_XP"),
						clay.Layout(
							{
								sizing = expand,
								layoutDirection = .TOP_TO_BOTTOM,
								childGap = childGap,
							},
						),
						clay.Rectangle(testPannel),
					) {
						playerHPBar(.8)
						// playerHPBar(.8)
					}
					if clay.UI(
						clay.ID("Abilities"),
						clay.Layout({sizing = expand}),
						clay.Rectangle(testPannel),
					) {

					}
					if clay.UI(
						clay.ID("??"),
						clay.Layout({sizing = expand}),
						clay.Rectangle(testPannel),
					) {

					}
				}
			}
		}
	}
}

// Juice :: https://www.youtube.com/watch?v=3Omb5exWpd4
// TODO:
// 1.DamageDummy
// -[x]HitFlash :: player white, enemy red
// -[x]HitReaction
// -[x]HitStop :: with curve; in and out
// -[x]KnockBack 
// 1.5 Camera
// -[x]Camera Follow
// -[x]Screen shake :: different levels 1 2 3 ; hit to player should be less than to enemy
// UI
// -[] CLAY
// SOUND
// -[]Hurt
// -[]swing
// -[]hit
// 2. AI
// -[]Follow player {straight line}
// - States
// -[x]Idle,
// -[x]pushback
// -[]running
// -[]attack
// -[]dead
// -[]hurt
// 3. Player Die
// -[]Health Bar'
// -[]Game over screen with Clay
// 1.9
// -[]Partcle

// How many pools will I need to have, for sure 1 for player 1 for enemy and same for abilities. At least 4.
//   I might also make different kinds of ability pools or enemy pools if I don't group them together.
// player := initPlyaer
// enemies1 := InitEnemies1 // Type 1
// enemies2 := InitEnemies2 // Type 2
// abilitesPlayer := InitAbilities   // Type 1 for Player
// abilitesPlayer2 := InitAbilities2 // Type 2 for player
// abilitesPlayer3 := InitAbilities3 // Type 3 for player
// abilitesEnemies := InitAbilities  // Type 1 for Enemy
