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
	playerAbilities: ^AbilityPool,
	enemyAbilities:  ^AbilityPool,
	// Testing
	ability:         AbilityConfig,
	dash:            State,
	screen:          rl.RenderTexture2D,
	fire:            ^Flipbook,
}

initGame :: proc() -> Game {
	game := Game {
		camera          = newCamera(),
		player          = initPlayer(engineerPath),
		objs            = initEnv(),
		enemies         = initEnemyDummies(minionPath),
		playerAbilities = initAbilityPool(),
		enemyAbilities  = initAbilityPool(),
		screen          = rl.LoadRenderTexture(P_W, P_H),
		fire            = initFlipbook("resources/fire.png", 96, 96, 18),
	}
	// impact := initFlipbook("resources/impact.png", 305, 383, 27)

	game.ability = newSpawnMeleAbilityPlayer(game.playerAbilities, game.player)
	game.dash = newPlayerDashAbility(game.player, game.camera)

	ANIMATION.anims = rl.LoadModelAnimations(engineerPath, &ANIMATION.total)
	assert(ANIMATION.total != 0, "No Anim")


	// For pixel look
	rl.SetTextureFilter(game.screen.texture, rl.TextureFilter.POINT)


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
		spawnDummyEnemy(&game.enemies, {-3, 0, f32(ii) * .1})
	}
}

resetGame :: proc(game: ^Game) {
	using game

	// Player
	player.health = Health {
		max     = 5,
		current = 5,
	}
	// Enemies
	despawnAllEnemies(&enemies)

	spawnXDummyEnemies(game, 10)
}

updateGame :: proc(game: ^Game) {
	// TODO: Add substates :: Playing : paused : powerup
	using game

	// :: Player Actions
	{
		// SM :: Input
		playerInputDash(player, dash, camera)
		// TODO: Put into func swap with 'Hand' logic stuff
		if isKeyPressed(ACTION_0) {
			// doAction(ability.action)
			enterPlayerState(player, ability.state, camera)
		}
		if rl.IsKeyPressed(.ONE) {
			rl.ToggleBorderlessWindowed() // Less hassle
		}
	}
	// Update player states
	switch &s in player.state {
	case playerStateBase:
		updatePlayerStateBase(player, objs, &enemies)
	case playerStateDashing:
		updatePlayerStateDashing(&s, player, objs, &enemies, camera)
	case playerStateAttack1:
		updatePlayerStateAttack1(&s, player, camera, objs, &enemies)
	case:
		// Go straight to base state if not initialized.
		enterPlayerState(player, playerStateBase{}, camera)
	}

	updateAnimation(player.model, &player.animation, ANIMATION)
	updatePlayerHitCollisions(enemyAbilities, player)
	updateHealth(player)

	updateEnemyDummies(&enemies, player^, &objs, enemyAbilities)
	applyBoundaryForces(&enemies, &objs)
	updateEnemyHitCollisions(playerAbilities, &enemies)

	updateHitStop()
	updateCameraPos(camera, player^)
	updateCameraShake(camera)

	updateAudio()

	updateFlipbook(fire)
}

drawGame :: proc(game: ^Game) {
	using game

	rl.BeginTextureMode(screen)
	rl.ClearBackground({})
	rl.BeginMode3D(camera^)

	// rl.DrawGrid(100, .25)
	rl.DrawPlane({}, {25, 25}, color5)

	drawAbilityInstances(playerAbilities, color1)
	drawAbilityInstances(enemyAbilities, color4)

	drawPlayer(player^)
	drawEnemies(&enemies)
	drawEnv(&objs)

	// drawFlipbook(camera^, fire^, {5, 1.5, 0}, 3)

	drawCamera(camera)
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
			clay.Layout({sizing = {height = clay.SizingPercent(.2), width = clay.SizingGrow({})}}),
			clay.Rectangle(testPannel),
		) {}
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
	}
}
