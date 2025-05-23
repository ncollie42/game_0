package main

import clay "/clay-odin"
import "core:fmt"
import "core:reflect"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"

Game :: struct {
	camera:          ^rl.Camera,
	player:          ^Player,
	objs:            [dynamic]EnvObj,
	enemies:         EnemyPool,
	spawners:        EnemySpanwerPool,
	playerAbilities: ^AbilityPool,
	enemyAbilities:  ^AbilityPool,
	// Testing
	normalAttack:    AbilityConfig,
	chargeAttack:    AbilityConfig,
	bashingAction:   Action, // We might not need AbilityConfig? 
	dash:            State,
	screen:          rl.RenderTexture2D,
	impact:          Flipbook,
	gems:            Gems,
}

discardShader: rl.Shader
whiteTexture: rl.Texture2D
initGame :: proc() -> Game {
	game := Game {
		camera          = newCamera(),
		player          = newPlayer(),
		objs            = initEnv(),
		enemies         = newEnemyPools(),
		spawners        = initEnemySpawner(),
		playerAbilities = initAbilityPool(),
		enemyAbilities  = initAbilityPool(),
		screen          = rl.LoadRenderTexture(P_W, P_H),
		impact          = initFlipbookPool("resources/impact.png", 305, 383, 27),
		gems            = initGems(),
	}

	actionSpawnMeleAtPlayer := ActionSpawnMeleAtPlayer {
		player = game.player,
		pool   = game.playerAbilities,
	}
	game.bashingAction = SpawnBashingMeleAtPlayer {
		player = game.player,
		pool   = game.playerAbilities,
	}
	// NOTE: We could make this global, and not part of the game object
	game.normalAttack = AbilityConfig {
		cost = 1,
		cd = Timer{max = 5},
		usageLimit = Limited{2, 2},
		state = playerStateAttack {
			cancellable  = true,
			animation    = PLAYER.punch,
			action_frame = 10,
			// TODO: add a transition_frame? different than cancel_frame
			cancel_frame = 16, //10 - attack quicker with lower transition frame [10,16]
			speed        = 1,
			action       = actionSpawnMeleAtPlayer,
		},
	}

	game.dash = newPlayerDashAbility(game.player, game.camera)

	discardShader = rl.LoadShader(nil, "shaders/alphaDiscard.fs")
	S_shadow = rl.LoadShader("shaders/shadow.vs", "shaders/shadow.fs")
	S_Black = rl.LoadShader(nil, "shaders/shadow.fs")
	// For pixel look
	rl.SetTextureFilter(game.screen.texture, rl.TextureFilter.POINT)

	whiteImage := rl.GenImageColor(1, 1, rl.WHITE)
	whiteTexture = rl.LoadTextureFromImage(whiteImage)
	rl.UnloadImage(whiteImage)

	gl.EnableBackfaceCulling()
	debugInit(&game)
	return game
}

//https://lospec.com/palette-list/apollo
// TODO: rename colors: ie, Blue0_6, green, brown, brow_2, red, purple, gray, whites
blue_0 := rl.GetColor(0x172038ff) //0
blue_1 := rl.GetColor(0x253a5eff)
blue_2 := rl.GetColor(0x3c5e8bff)
blue_3 := rl.GetColor(0x4f8fbaff)
blue_4 := rl.GetColor(0x73bed3ff)
blue_5 := rl.GetColor(0xa4dddbff)
color6 := rl.GetColor(0x19332dff)
color7 := rl.GetColor(0x25562eff)
color8 := rl.GetColor(0x468232ff)
color9 := rl.GetColor(0x75a743ff)
color10 := rl.GetColor(0xa8ca58ff)
color11 := rl.GetColor(0xd0da91ff)
color12 := rl.GetColor(0x4d2b32ff)
color13 := rl.GetColor(0x7a4841ff)
color14 := rl.GetColor(0xad7757ff)
color15 := rl.GetColor(0xc09473ff)
color16 := rl.GetColor(0xd7b594ff)
color17 := rl.GetColor(0xe7d5b3ff)
color18 := rl.GetColor(0x341c27ff)
color19 := rl.GetColor(0x602c2cff)
color20 := rl.GetColor(0x884b2bff)
color21 := rl.GetColor(0xbe772bff)
color22 := rl.GetColor(0xde9e41ff)
color23 := rl.GetColor(0xe8c170ff)
color24 := rl.GetColor(0x241527ff)
color25 := rl.GetColor(0x411d31ff)
color26 := rl.GetColor(0x752438ff)
color27 := rl.GetColor(0xa53030ff)
color28 := rl.GetColor(0xcf573cff)
color29 := rl.GetColor(0xda863eff)
color30 := rl.GetColor(0x1e1d39ff)
color31 := rl.GetColor(0x402751ff)
color32 := rl.GetColor(0x7a367bff)
color33 := rl.GetColor(0xa23e8cff)
color34 := rl.GetColor(0xc65197ff)
color35 := rl.GetColor(0xdf84a5ff)
black_0 := rl.GetColor(0x090a14ff)
black_1 := rl.GetColor(0x10141fff)
black_2 := rl.GetColor(0x151d28ff)
black_3 := rl.GetColor(0x202e37ff)
black_4 := rl.GetColor(0x394a50ff)
black_5 := rl.GetColor(0x577277ff)
white_0 := rl.GetColor(0x819796ff)
white_1 := rl.GetColor(0xa8b5b2ff)
white_2 := rl.GetColor(0xc7cfccff)
white_3 := rl.GetColor(0xebede9ff) //45

colorToVec4 :: proc(color: rl.Color) -> vec4 {
	return vec4{f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, 1}
}

spawnXDummyEnemies :: proc(game: ^Game, amount: int) {
	for ii in 0 ..< amount {
		// spawnEnemyMele(&game.enemies, {-3, 0, f32(ii) * .1})
		spawnEnemyDummy(&game.enemies, {-3, 0, f32(ii) * .1})
	}
}

resetGame :: proc(game: ^Game) {
	using game

	// Player :: TODO reset to a base line
	initPlayer(player)
	// Enemies
	despawnAllEnemies(&enemies)
	initEnemyPools(&enemies)

	initWarnings()
	initWaves()
	initDamageNumbers()
	// TODO: Reset spawners
	// TODO: Reset Signs
	// 
	// spawnXDummyEnemies(game, 10)
}

updateGame :: proc(game: ^Game) {
	// TODO: Add substates :: Playing : paused : powerup
	using game

	debugUpdateGame(game)

	// :: Player Actions
	updatePlayerInput(game)

	// Update player states
	switch &s in player.state {
	case playerStateBase:
		updatePlayerStateBase(player, objs, &enemies)
	case playerStateDashing:
		updatePlayerStateDashing(&s, player, objs, &enemies, camera)
	case playerStateAttack:
		updatePlayerStateAttack(&s, player, camera, objs, &enemies)
	case playerStateAttackLeft:
		updatePlayerStateAttackLeft(&s, player, camera, objs, &enemies)
	case playerStateBlocking:
		updatePlayerStateBlocking(&s, player, camera, &enemies, enemyAbilities, playerAbilities)
	// updatePlayerStateBlockingParry(&s, abilities) // TODO: Add this 
	case playerStateBlockBash:
		updatePlayerStateBlockBashing(&s, player, camera, objs, &enemies)
	case:
		// Go straight to base state if not initialized.
		enterPlayerState(player, playerStateBase{}, camera, &enemies)
	}
	updateWaves(game)

	updateAnimation(player.model, &player.animState, player.animSet)
	updatePlayerHitCollisions(enemyAbilities, player)
	updateHealth(player)
	updateStamina(player)
	updateBlock(&player.block)

	updateEnemies(&enemies, player^, &objs, enemyAbilities)
	updateSpawningEnemies(&enemies)
	updateEnemyAnimations(&enemies)
	updateEnemyHealth(&enemies) //Add other enemies here too
	applyBoundaryForces(&enemies, &objs)
	applyBoundaryForcesFromMap(&enemies, &objs)
	updateEnemyHitCollisions(playerAbilities, &enemies, &spawners, &impact)

	updateHitStop()
	updateCameraPos(camera, player^)
	updateCameraShake(camera)

	updateAudio()

	updateFlipbookOneShot(&impact, 60)
	updateFlipbookOneShot(&player.trailRight, 30)
	updateFlipbookOneShot(&player.trailLeft, 30)
	updateWarning()
	updateDamageNumbers()
}

drawGame :: proc(game: ^Game) {
	using game

	rl.BeginTextureMode(screen)
	rl.ClearBackground({})
	rl.BeginMode3D(camera^)

	// Draw Env first
	drawEnv(&objs)

	drawAbilityInstances(playerAbilities, blue_1, camera)
	drawAbilityInstances(enemyAbilities, blue_5, camera)

	drawPlayer(player^, camera)
	drawEnemies(&enemies, camera)
	drawChargeAbleEnemyMarks(&enemies, camera, player)
	drawGems(&gems, camera)

	debugDrawGame(game)
	{
		rl.BeginShaderMode(discardShader) // For billboard
		drawFlipbook(camera^, impact, 3, {}, {})
		drawMeleTrail(camera^, player.trailLeft)
		drawMeleTrail(camera^, player.trailRight)
		rl.EndShaderMode()
	}
	drawWarnings(camera^)
	drawHealthbars(camera, &enemies)

	drawCamera(camera)
	// -------------------------------------------------
	rl.EndMode3D()
	rl.EndTextureMode()

	// Render 3D
	w := f32(rl.GetScreenWidth()) * 1
	h := f32(rl.GetScreenHeight()) * 1

	// https://github.com/raysan5/raylib/wiki/Frequently-Asked-Questions#why-is-my-render-texture-upside-down
	rl.DrawTexturePro(screen.texture, {0, 0, -P_W, P_H}, {0, 0, w, h}, {w, h}, 180, rl.WHITE)

	// drawDamageNumbersUI(camera)
}

@(private = "file")
UI := struct {
	debug:   bool,
	hideAll: bool,
}{}

drawGameUI :: proc(game: ^Game) {
	using game

	clayFrameSetup()
	clay.BeginLayout()
	defer {
		layout := clay.EndLayout()
		clayRaylibRender(&layout)
	}
	rl.DrawFPS(10, 10)
	// UI.hideAll = true
	if rl.IsKeyReleased(.TAB) {
		UI.debug = !UI.debug
	}
	if UI.hideAll do return

	drawDamageNumbersUI(camera)
	// Start UI
	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot)) {
		if clay.UI(
			clay.ID("top"),
			clay.Layout(
				{
					sizing = {height = clay.SizingPercent(.2), width = clay.SizingGrow({})},
					childAlignment = {x = .CENTER},
				},
			),
			clay.Rectangle(testPannel),
		) {
			timer := fmt.tprintf("%.1f", Waves.duration)
			uiText(timer, .large)
		}
		if clay.UI(
			clay.ID("center"),
			clay.Layout({sizing = expand}),
			// clay.Rectangle(testPannel),
		) {
			if UI.debug {
				if clay.UI(
					clay.ID("DEBUG"),
					clay.Layout(layoutDebug),
					clay.Rectangle(debugPannel),
				) {
					uiText("DEBUG", .large)
					devider()
					uiText(fmt.tprintf("%d FPS", rl.GetFPS()), .mid)
					devider()
					if buttonText("Spawn Enemies") {
						spawnXDummyEnemies(game, 5)
					}
					uiText(fmt.tprintf("%d Enemies", len(enemies.active)), .mid)
					devider()
					if clay.UI(
						clay.Layout(
							{
								layoutDirection = .LEFT_TO_RIGHT,
								childAlignment = {.CENTER, .CENTER},
							},
						),
					) {
						uiText("TimeScale:", .small)
						if buttonText("-") {
							timeScale = clamp(timeScale - .25, 0, 3)
						}
						uiText(fmt.tprint(timeScale), .small)
						if buttonText("+") {
							timeScale = clamp(timeScale + .25, 0, 3)
						}
					}
					// }
					// for enemy in enemies.active {
					// 	state := reflect.union_variant_type_info(enemy.state)
					// 	uiText(fmt.tprint(state), .mid)
					// 	debugEnemyHPBar(enemy.health)
					// }
				}
			}
		}
		if clay.UI(
			clay.ID("bottom"),
			clay.Layout(
				{
					sizing = {height = clay.SizingPercent(.2), width = clay.SizingGrow({})},
					childGap = childGap,
				},
			),
		) {
			if clay.UI(
				clay.ID("HP_XP"),
				clay.Layout(
					{sizing = expand, layoutDirection = .TOP_TO_BOTTOM, childGap = childGap},
				),
				clay.Rectangle(testPannel),
			) {
				playerHPBar(player)
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
			) {}
		}
		if clay.UI(
			clay.ID("Stamina bars"),
			clay.Floating(
				clay.FloatingElementConfig {
					attachment = {parent = .CENTER_CENTER},
					offset = {-30, 15},
				},
			),
		) {
			if clay.UI(
				clay.Layout(
					clay.LayoutConfig {
						sizing = {width = clay.SizingFixed(30), height = clay.SizingFixed(30)},
						childGap = 3,
					},
				),
				clay.Rectangle(testPannel),
			) {
				// staminaBar(Stamina.currentCharge, Stamina.charges)
				// uiText("HELLO", .large)
			}
		}
	}
}

drawPauseUI :: proc(game: ^Game, app: ^App) {
	using game

	clayFrameSetup()
	clay.BeginLayout()
	defer {
		layout := clay.EndLayout()
		clayRaylibRender(&layout)
	}

	rl.DrawFPS(10, 10)
	// Start UI
	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot)) {
		pos := rl.GetWorldToScreen({}, camera^)
		if clay.UI(clay.Floating(clay.FloatingElementConfig{offset = pos})) {
			if buttonText("Resume") {
				app^ = .PLAYING
			}
			if buttonText("Main Menu") {
				app^ = .HOME
			}
		}
	}
}

drawStatsUI :: proc(game: ^Game) {
	using game

	clayFrameSetup()
	clay.BeginLayout()
	defer {
		layout := clay.EndLayout()
		clayRaylibRender(&layout)
	}

	rl.DrawFPS(10, 10)
	// Start UI
	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot)) {
		pos := rl.GetWorldToScreen({}, camera^)
		if clay.UI(clay.Floating(clay.FloatingElementConfig{offset = pos})) {
			uiText("STATS", .large)
		}
	}
}
