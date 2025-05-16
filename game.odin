package main

import clay "/clay-odin"
import "core:fmt"
import "core:reflect"
import rl "vendor:raylib"

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
	dash:            State,
	screen:          rl.RenderTexture2D,
	impact:          Flipbook,
	gems:            Gems,
}

discardShader: rl.Shader
shadow: rl.Shader
whiteTexture: rl.Texture2D
initGame :: proc() -> Game {
	game := Game {
		camera          = newCamera(),
		player          = initPlayer(),
		objs            = initEnv(),
		enemies         = initEnemyDummies(),
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
	// NOTE: We could make this global, and not part of the game object
	game.normalAttack = AbilityConfig {
		cost = 1,
		cd = Timer{max = 5},
		usageLimit = Limited{2, 2},
		state = playerStateAttack1 {
			cancellable = true,
			timer = Timer{max = .3},
			animation = PLAYER.punch,
			action_frame = 10,
			// TODO: add a transition_frame? different than cancel_frame
			cancel_frame = 16, //10 - attack quicker with lower transition frame [10,16]
			speed = 1,
			action = actionSpawnMeleAtPlayer,
		},
	}
	game.chargeAttack = AbilityConfig {
		cost = 1,
		cd = Timer{max = 5},
		usageLimit = Limited{2, 2},
		state = playerStateAttackLong {
			cancellable = true,
			timer = Timer{max = .5},
			trigger = 1, //[0,1]
			animation = PLAYER.kick,
			speed = 2.3,
			action = actionSpawnMeleAtPlayer,
		},
	}
	game.dash = newPlayerDashAbility(game.player, game.camera)

	discardShader = rl.LoadShader(nil, "shaders/alphaDiscard.fs")
	shadow = rl.LoadShader("shaders/shadow.vs", "shaders/shadow.fs")
	// For pixel look
	rl.SetTextureFilter(game.screen.texture, rl.TextureFilter.POINT)

	whiteImage := rl.GenImageColor(1, 1, rl.WHITE)
	whiteTexture = rl.LoadTextureFromImage(whiteImage)
	rl.UnloadImage(whiteImage)

	debugInit(&game)
	return game
}

//https://lospec.com/palette-list/apollo
color0 := rl.GetColor(0x172038ff)
color1 := rl.GetColor(0x253a5eff)
color2 := rl.GetColor(0x3c5e8bff)
color3 := rl.GetColor(0x4f8fbaff)
color4 := rl.GetColor(0x73bed3ff)
color5 := rl.GetColor(0xa4dddbff)
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
color36 := rl.GetColor(0x090a14ff)
color37 := rl.GetColor(0x10141fff)
color38 := rl.GetColor(0x151d28ff)
color39 := rl.GetColor(0x202e37ff)
color40 := rl.GetColor(0x394a50ff)
color41 := rl.GetColor(0x577277ff)
color42 := rl.GetColor(0x819796ff)
color43 := rl.GetColor(0xa8b5b2ff)
color44 := rl.GetColor(0xc7cfccff)
color45 := rl.GetColor(0xebede9ff)

spawnXDummyEnemies :: proc(game: ^Game, amount: int) {
	for ii in 0 ..< amount {
		// spawnEnemyMele(&game.enemies, {-3, 0, f32(ii) * .1})
		spawnEnemyDummy(&game.enemies, {-3, 0, f32(ii) * .1})
	}
}

resetGame :: proc(game: ^Game) {
	using game

	// Player :: TODO reset to a base line
	player.health.current = player.health.max
	// Enemies
	despawnAllEnemies(&enemies)

	initWarnings()
	initWaves()
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
	case playerStateAttack1:
		updatePlayerStateAttack1(&s, player, camera, objs, &enemies)
	case playerStateAttackLong:
		updatePlayerStateAttackLong(&s, player, camera, objs, &enemies)
	case:
		// Go straight to base state if not initialized.
		enterPlayerState(player, playerStateBase{}, camera)
	}
	// updateWaves(game)

	updateAnimation(player.model, &player.animState, player.animSet)
	updatePlayerHitCollisions(enemyAbilities, player)
	updateHealth(player)
	updateStamina(player)

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

	drawAbilityInstances(playerAbilities, color1)
	drawAbilityInstances(enemyAbilities, color4)

	drawPlayer(player^, camera)
	drawEnemies(&enemies, camera)
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
