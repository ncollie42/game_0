package main

import clay "/clay-odin"
import "core:fmt"
import "core:reflect"
import rl "vendor:raylib"

Game :: struct {
	camera:          ^rl.Camera,
	player:          ^Player,
	objs:            [dynamic]EnvObj,
	enemies:         EnemyDummyPool,
	spawners:        EnemySpanwerPool,
	playerAbilities: ^AbilityPool,
	enemyAbilities:  ^AbilityPool,
	// Testing
	normalAttack:    AbilityConfig,
	chargeAttack:    AbilityConfig,
	dash:            State,
	screen:          rl.RenderTexture2D,
	impact:          Flipbook,
}

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
			trigger = .1,
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
			animation = PLAYER.punch,
			speed = 2.3,
			action = actionSpawnMeleAtPlayer,
		},
	}
	game.dash = newPlayerDashAbility(game.player, game.camera)

	// For pixel look
	rl.SetTextureFilter(game.screen.texture, rl.TextureFilter.POINT)

	debugInit(&game)
	return game
}

color0 := rl.GetColor(0x495435ff)
color1 := rl.GetColor(0x8a8e48ff)
color2 := rl.GetColor(0xdebf89ff)
color3 := rl.GetColor(0xa4653eff)
color4 := rl.GetColor(0x902e29ff)
color5 := rl.GetColor(0x24171bff)
color6 := rl.GetColor(0x5d453eff)
color7 := rl.GetColor(0x907c68ff)

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
	updateStamina()

	updateEnemies(&enemies, player^, &objs, enemyAbilities)
	updateEnemyAnimations(&enemies)
	updateEnemyHealth(&enemies) //Add other enemies here too
	applyBoundaryForces(&enemies, &objs)
	updateEnemyHitCollisions(playerAbilities, &enemies, &spawners, &impact)

	updateHitStop()
	updateCameraPos(camera, player^)
	updateCameraShake(camera)

	updateAudio()

	updateFlipbookOneShot(&impact, 60)
	updateFlipbookOneShot(&player.trail, 10)
}

drawGame :: proc(game: ^Game) {
	using game

	rl.BeginTextureMode(screen)
	rl.ClearBackground({})
	rl.BeginMode3D(camera^)

	drawAbilityInstances(playerAbilities, color1)
	drawAbilityInstances(enemyAbilities, color4)

	drawPlayer(player^)
	drawEnemies(&enemies)
	drawEnv(&objs)

	debugDrawGame(game)
	drawFlipbook(camera^, impact, 3, {}, {})
	drawMeleTrail(camera^, player.trail)

	drawCamera(camera)
	// -------------------------------------------------
	rl.EndMode3D()
	rl.EndTextureMode()

	// Render 3D
	w := f32(rl.GetScreenWidth()) * 1
	h := f32(rl.GetScreenHeight()) * 1

	// https://github.com/raysan5/raylib/wiki/Frequently-Asked-Questions#why-is-my-render-texture-upside-down
	rl.DrawTexturePro(screen.texture, {0, 0, -P_W, P_H}, {0, 0, w, h}, {w, h}, 180, rl.WHITE)
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
				staminaBar(Stamina.currentCharge, Stamina.charges)
				// uiText("HELLO", .large)
			}
		}
	}
}
