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
	hand:            [HandAction]AbilityConfig, // Not using all actions, just the ones in hand
	dash:            State,
	screen:          rl.RenderTexture2D,
	ui:              rl.RenderTexture2D, // test
	upgradeOptions:  [3]UpgradeName,
	impact:          Flipbook,
	gems:            Gems,
	pickups:         Pickup,
	state:           enum {
		PLAYING,
		UPGRADE,
		PAUSE,
	},
}

initGame :: proc() -> Game {
	loadShaders()
	game := Game {
		camera          = newCamera(),
		player          = newPlayer(),
		objs            = initEnv(),
		enemies         = newEnemyPools(),
		spawners        = initEnemySpawner(),
		playerAbilities = initAbilityPool(),
		enemyAbilities  = initAbilityPool(),
		screen          = rl.LoadRenderTexture(P_W, P_H),
		ui              = rl.LoadRenderTexture(P_W, P_H),
		impact          = initFlipbookPool("resources/impact.png", 305, 383, 27),
		gems            = initGems(),
		pickups         = initPickup(),
	}

	Closures[.Mele] = ActionSpawnMeleAtPlayer {
		percent = 1, // 100%
		player  = game.player,
		pool    = game.playerAbilities,
	}
	Closures[.Range] = ActionSpawnRangeAtPlayer {
		percent = .5, // 50%
		player  = game.player,
		pool    = game.playerAbilities,
	}

	game.hand = {}
	game.hand[.Attack] = MeleAttackConfig

	game.dash = newPlayerDashAbility(game.player, game.camera)

	// For pixel look
	rl.SetTextureFilter(game.screen.texture, rl.TextureFilter.POINT)
	rl.SetTextureFilter(game.ui.texture, rl.TextureFilter.BILINEAR)

	// TODO: remove from asset - Textures[]
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
	removeAllAbilities(enemyAbilities)
	removeAllAbilities(playerAbilities)
	initStamina()

	ManaRechargeSpeed = .25
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
	case:
		// Go straight to base state if not initialized.
		enterPlayerState(player, playerStateBase{}, camera, &enemies)
	}
	updateWaves(game)

	updateAnimation(player.model, &player.animState, player.animSet)
	updatePlayerHitCollisions(enemyAbilities, player) // Need to go before update enemies for mele parry
	updateHealth(player)
	updateStamina(player)
	updateMana(&player.mana)
	updateGems(&gems, player)
	updatePickup(&pickups, player)

	updateEnemies(&enemies, player^, &objs, enemyAbilities)
	updateSpawningEnemies(&enemies)
	updateEnemyAnimations(&enemies)
	updateEnemyHealth(&enemies, &pickups, player) //Add other enemies here too
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

	// IF STREACING UI
	// rl.BeginTextureMode(screen)
	// rl.ClearBackground({})
	rl.BeginMode3D(camera^)

	// Draw Env first
	drawEnv(&objs)

	drawAbilityInstances(playerAbilities, blue_1, camera)
	drawAbilityInstances(enemyAbilities, blue_5, camera)

	drawPlayer(player^, camera)
	drawEnemies(&enemies, camera)
	drawSelectedEnemy(&enemies, camera)
	drawGems(&gems, camera)
	drawPickup(&pickups, camera)

	debugDrawGame(game)
	{
		rl.BeginShaderMode(Shaders[.Discard]) // For billboard
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
	// IF STREACING UI
	// w := f32(rl.GetScreenWidth()) * 1
	// h := f32(rl.GetScreenHeight()) * 1

	// // https://github.com/raysan5/raylib/wiki/Frequently-Asked-Questions#why-is-my-render-texture-upside-down
	// rl.DrawTexturePro(screen.texture, {0, 0, -P_W, P_H}, {0, 0, w, h}, {w, h}, 180, rl.WHITE)

}

@(private = "file")
UI := struct {
	debug:   bool,
	hideAll: bool,
}{}

drawGameUI :: proc(game: ^Game) {
	using game

	if uiStrech {
		rl.BeginTextureMode(ui)
		rl.ClearBackground({})
	}

	clayFrameSetup()
	clay.BeginLayout()
	// UI.hideAll = true
	if rl.IsKeyReleased(.TAB) {
		UI.debug = !UI.debug
	}
	if UI.hideAll do return

	drawDamageNumbersUI(camera)
	// Start UI
	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot)) {
		layout := clay.LayoutConfig {
			sizing = {height = clay.SizingPercent(.2), width = clay.SizingGrow({})},
			padding = {0, 0, 0, 0},
			childGap = childGap,
			childAlignment = {.CENTER, .TOP},
			layoutDirection = .LEFT_TO_RIGHT,
		}
		if clay.UI(clay.ID("top"), clay.Layout(layout), clay.Rectangle(testPannel)) {
			timer := fmt.tprintf("%.1f", Waves.duration)
			uiText(timer, .large)
		}
		if clay.UI(clay.ID("center"), clay.Layout({sizing = expand}), clay.Rectangle(testPannel)) {
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
				}
			}
			// drawUpgradeUI(game)
		}
		// Bottom 20% of screen
		layout = clay.LayoutConfig {
			sizing = {height = clay.SizingPercent(.2), width = clay.SizingGrow({})},
			padding = {0, 0, 0, 0},
			childGap = childGap,
			childAlignment = {.CENTER, .BOTTOM},
			layoutDirection = .LEFT_TO_RIGHT,
		}
		if clay.UI(clay.ID("bottom"), clay.Layout(layout)) {
			layout = clay.LayoutConfig {
				sizing          = expand,
				padding         = {0, 0, 0, 0},
				childGap        = childGap,
				childAlignment  = {.LEFT, .BOTTOM},
				layoutDirection = .TOP_TO_BOTTOM,
			}
			if clay.UI(clay.ID("HP_XP"), clay.Layout(layout), clay.Rectangle(testPannel)) {
				playerHPBar(player)
			}

			// Player Abilities 
			playerHand(&hand, player)
			// Right Bottom 
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
	layout := clay.EndLayout()
	clayRaylibRender(&layout)

	if uiStrech {
		rl.EndTextureMode()

		w := f32(rl.GetScreenWidth()) * 1
		h := f32(rl.GetScreenHeight()) * 1

		rl.DrawTexturePro(ui.texture, {0, 0, -P_W, P_H}, {0, 0, w, h}, {w, h}, 180, rl.WHITE)
	}
}

drawPauseUI :: proc(game: ^Game, app: ^App) {
	using game

	clayFrameSetup()
	clay.BeginLayout()

	// Start UI
	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot)) {
		layout := clay.LayoutConfig {
			sizing          = expand,
			padding         = {0, 0, 0, 0},
			childGap        = childGap,
			childAlignment  = {.CENTER, .CENTER},
			layoutDirection = .TOP_TO_BOTTOM,
		}
		if clay.UI(clay.ID("Pause"), clay.Layout(layout), clay.Rectangle(testPannel)) {
			if buttonText("Resume") {
				app^ = .PLAYING
			}
			if buttonText("Main Menu") {
				app^ = .HOME
			}
			if buttonText("QUIT") {
				rl.CloseWindow() // Close more gracefully
			}
		}
		// pos := rl.GetWorldToScreen({}, camera^)
		// if clay.UI(clay.Floating(clay.FloatingElementConfig{offset = pos})) {
		// }
	}
	layout := clay.EndLayout()
	clayRaylibRender(&layout)
}

drawStatsUI :: proc(game: ^Game) {
	using game

	clayFrameSetup()
	clay.BeginLayout()

	// Start UI
	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot)) {
		layout := clay.LayoutConfig {
			sizing          = expand,
			padding         = {0, 0, 0, 0},
			childGap        = childGap,
			childAlignment  = {.CENTER, .CENTER},
			layoutDirection = .TOP_TO_BOTTOM,
		}
		if clay.UI(clay.ID("Pause"), clay.Layout(layout), clay.Rectangle(testPannel)) {
			uiText("STATS", .large)
		}
	}

	layout := clay.EndLayout()
	clayRaylibRender(&layout)
}


// ---------------- UPGRADE UI ------------------------------
a1 := Upgrade {
	name   = .RangeUnlock,
	img    = .Mark1,
	type   = .Ability,
	rarity = .Common,
}

a2 := Upgrade {
	name   = .Mana,
	img    = .Mark1,
	type   = .Ability,
	rarity = .Common,
}

a3 := Upgrade {
	name   = .Stamina,
	img    = .Mark1,
	type   = .Ability,
	rarity = .Common,
}
drawUpgradeUI :: proc(game: ^Game) {
	using game

	clayFrameSetup()
	clay.BeginLayout()

	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot)) {
		layout := clay.LayoutConfig {
			sizing          = expand,
			padding         = {0, 0, 0, 0},
			childGap        = childGap,
			childAlignment  = {.CENTER, .CENTER},
			layoutDirection = .TOP_TO_BOTTOM,
		}
		if clay.UI(clay.ID("Upgrades"), clay.Layout(layout), clay.Rectangle(testPannel)) {
			// game.upgradeOptions -> TODO: load and loop from here
			// Upgrades show ->
			uiText("Choose One:", .large)
			if drawUpgradeUIItem(game, a1) ||
			   drawUpgradeUIItem(game, a2) ||
			   drawUpgradeUIItem(game, a3) {
				game.state = .PLAYING
			}
		}
	}

	layout := clay.EndLayout()
	clayRaylibRender(&layout)
}

drawUpgradeUIItem :: proc(game: ^Game, upgrade: Upgrade) -> bool {
	size: f32 = 64 * 1.5
	padding: u16 = 10
	layout := clay.LayoutConfig { 	// Background container
		sizing = {
			width = clay.SizingFixed((size * 4 + f32(padding * 2))),
			height = clay.SizingFixed(size + f32(padding * 2)),
		},
		padding = {padding, padding, padding, padding},
		childGap = childGap,
		childAlignment = {},
		layoutDirection = .LEFT_TO_RIGHT,
	}
	rec := clay.RectangleElementConfig { 	// background
		color        = light_05,
		cornerRadius = {uiCorners, uiCorners, uiCorners, uiCorners},
	}
	hovered := false
	if clay.UI() { 	// Need to wrap in an extra clay.ui for hover reasons
		if clay.UI(
			clay.Layout(layout),
			clay.BorderAllRadius(
				{width = borderThick, color = clay.Hovered() ? light_100 : light_05},
				uiCorners,
			),
			clay.Rectangle(rec),
		) {
			layout = clay.LayoutConfig { 	// Image 
				sizing = {width = clay.SizingFixed(size), height = clay.SizingFixed(size)},
				padding = {0, 0, 0, 0},
				childGap = {},
				childAlignment = {},
				layoutDirection = .LEFT_TO_RIGHT,
			}
			if clay.UI(clay.Layout(layout), clay.Image({imageData = &Textures[upgrade.img]})) {}

			layout = clay.LayoutConfig { 	// Text container
				sizing          = expand,
				padding         = {0, 0, 0, 0},
				childGap        = {},
				childAlignment  = {},
				layoutDirection = .TOP_TO_BOTTOM,
			}
			if clay.UI(clay.Layout(layout)) {
				hovered = clay.Hovered()
				type := fmt.tprint(upgrade.type)
				uiText(type, .large)
				devider()
				str := upgradeDescription(game, upgrade.name)
				uiText(str, .mid)
			}
		}
	}

	clicked := hovered && rl.IsMouseButtonPressed(.LEFT)
	if clicked do doUpgrade(game, upgrade.name)


	// imageData = &Textures[config.img],
	return clicked
}
