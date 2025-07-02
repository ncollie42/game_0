package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

model: rl.Model
text: rl.Texture2D
// animState: AnimationState = {
// 	current = ENEMY.hurt,
// 	speed   = 1,
// }
// animSet: AnimationSet
img: rl.Texture2D
hmap2: rl.Model
debugInit :: proc(game: ^Game) {
	using game

	mesh := rl.GenMeshPlane(100, 100, 5, 5)
	model = rl.LoadModelFromMesh(mesh)

	text = rl.LoadTexture("resources/floor/g3_albedo.png")

	rl.SetTextureWrap(text, .REPEAT)
	tileScaleLocation := rl.GetShaderLocation(Shaders[.Tiling], "tileScale")
	tileScale := f32(10.0)
	rl.SetShaderValue(Shaders[.Tiling], tileScaleLocation, &tileScale, .FLOAT)

	model.materials[model.materialCount - 1].maps[rl.MaterialMapIndex.ALBEDO].texture = text
	model.materials[model.materialCount - 1].shader = Shaders[.Tiling]
	// text2 := rl.LoadTexture("resources/floor/g3_normal.png")
	// hmap := rl.LoadTexture("resources/floor/g3_heightmap.png")
	hmap := rl.LoadImage("resources/floor/g3_heightmap.png")
	mesh2 := rl.GenMeshHeightmap(hmap, {100, 1, 100})
	hmap2 = rl.LoadModelFromMesh(mesh2)
	hmap2.materials[hmap2.materialCount - 1].maps[rl.MaterialMapIndex.ALBEDO].texture = text
	// hmap2.materials[hmap2.materialCount - 1].shader = Shaders[.Tiling]
	// 
	// text4 := rl.LoadTexture("resources/floor/g3_emission.png")
	// model.materials[model.materialCount - 1].maps[rl.MaterialMapIndex.NORMAL].texture = text2
	// model.materials[model.materialCount - 1].maps[rl.MaterialMapIndex.HEIGHT].texture = text3
	// model.materials[model.materialCount - 1].maps[rl.MaterialMapIndex.EMISSION].texture = text4
}

debugUpdateGame :: proc(game: ^Game) {
	using game

	grid := getSafePointInGrid(&game.enemies, player)
	mouse := mouseInWorld(camera)
	random := getRandomPoint()

	img = loadTexture("resources/mark_4.png")
	if rl.IsKeyPressed(.N) {
		// doUpgrade(game, .RangeUnlock)
		doUpgrade(game, .GravityUnlock)
	}
	if rl.IsKeyPressed(.F) {
		ability := newBeamInstance(player, 1, 0, camera, &enemies)
		append(&playerAbilities.active, ability)
		fmt.println("Beam->")
		// spawnGravityPoint(&gpoints, mouse)
		// uiStrech = !uiStrech
		// spawnEnemy(&enemies, grid, .Range, true)
	}
	if rl.IsKeyPressed(.G) {
		spawnEnemy(&enemies, grid, .Mele, true)
	}
	if rl.IsKeyPressed(.H) {
		spawnEnemy(&enemies, mouse, .Range, true)
	}
	if rl.IsKeyPressed(.M) {
		game.state = .UPGRADE
	}
	if rl.IsKeyPressed(.J) {
		// debug = !debug
		// startTimer(&hand[.Attack].cd)
	}
	if rl.IsKeyPressed(.UP) {
		// timeScale += .25
	}
	if rl.IsKeyPressed(.DOWN) {
		// timeScale -= .25
	}
	if rl.IsKeyPressed(.U) {
		rl.CloseWindow() // Close more gracefully
	}
	// tileScaleLocation := rl.GetShaderLocation(Shaders[.Tiling], "tileScale")
	// rl.SetShaderValue(Shaders[.Tiling], tileScaleLocation, &tileScale, .FLOAT)

	// TODO: move to update hand section -> input + CD
	for &config, slot in hand {
		updateTimer(&config.cd)
	}

	updateEnemySpanwers(&spawners, &enemies, &objs)


}

// Z coordinate is compared to the appropriate entry in the depth buffer, if that pixel has already been drawn with a closer depth buffer value, then our new pixel isn't rendered at all, it's behind something that is already on the screen.
// Need to render back to front, with my camera, back is positive.
// Z:: [1,-1] 
// Y:: [-1,1]
debug := false
debugDrawGame :: proc(game: ^Game) {
	using game


	// if debug do getEnemyHitResult(&enemies, camera)
	// When drawing with DrawTexturePro, you can tile by using source rectangles larger than the texture
	// source := rl.Rectangle{0, 0, text.width * 4, text.height * 4} // Tile 4x4
	// dest := rl.Rectangle{0, 0, 800, 600}
	// rl.DrawTexturePro(text, source, dest, {0, 0}, 0, rl.WHITE)

	// Flat tile
	// rl.DrawModel(model, {0, 0, 0}, 1, rl.WHITE)

	drawPreviewCircle(camera, 4)
	drawPreviewCircleWithMaxDistance(player, camera, 4, 10)
	// drawPreviewline(player, camera)
	// drawPreviewCapsule(player, camera)
	drawPreviewRec(player, camera)
	// Heightmap
	// rl.DrawModel(hmap2, {-50, 0, -50}, 1, rl.WHITE)
}

// Preflight
// Shader for floor w/ some circular drop off?
// Google docs of what is needed
//
// on CD - show mana + cost / charges + hover>
// If abilities expire -> where do they go? what is the deck of cards
// If every action was a card
// 
// 1. Change border color based on CD - Free - Inuse
// 2. Add background when doing an action -> Not sure how to map yet.
//  - maybe make it all dark when not idle or running, not sure how to map back to the key yet.
// 3. charges -> Might need larger spacing?
// 4. Fix unlock for ability - Click doesn't work
// 5. Do hover over {Text} + cost + charges + Mana} when on a given game state - pause? or mouse free?``
// 6. Multi level upgrades for abilities ie: Heroes of hamer watch + deadlock
//   - Would this force you into 1 or 2 abilities? what about a full deck?
//   - Do we want to leave charges for later? or do nowmake it feel good with a select set of abilities that dont expire.
// -
//
// I need to look at different types of abilities (Basic - Damage ones) -> see the compnents needed
//   (Projectile - In place - timer - ticker - Beam?) - what kind of shaders + models do I need for these?
//    1. Hero of hammer watch
//    2. Tribes of midguard
//    3. Ravens watch
// Then I also want to create more interesting cards ->
//    1. Dead lock
//    2. Card game mechanics ( Looking at the resources that are already in the game ie: gems, or rule breaking ) 
//
// If I have cost on mana AND abilities will be able to be picked up then I might need charges OR Cool down. This might be too many limitations
// Abilitiy Charges or CD or Mana cost are all limitations on how we want the abilities to be used.
//
// CD is Enough for abiltiies, but we're using Mana.
// If we're using mana, we probably don't need CD if there are charges becuase you'll want to limit your self.
// but we probably still want a GCD.
// If we're using mana, And we have charges -> how do we get them back?
// 
// What is the MVP?
// [X] Ability + mana cost
// [ ] Ability + mana cost + charges ->
//    What is the deck building like?
// [ Optional ] Add CD if we feel like it's needed to limit play.
//
// [ Content ] Steps to develop - Conent
// [p0][ Create basic damage cards ] - 4 [Beam, 1 projectile, mele, ??]
// [ Create interesting cards ] - 3 [ around 1 resource ? Gem]
// [p0][ Create Basic damage Enemies ] - [Mele | Range | Carge ]
// [ Create Interesting Enemy ] - [ Around 1 resource ? Gem]
//
// [ Audio ] -> Out source or spend a week or 2? Starting when.
// 
// [p0][ Env ] -> [ Floor shader | grass / Debre ]
//     - How to do shadows with a new floor -> If we project solid color -> bad?
// 
// [p0][ VFX ] -> Outline visual req for abilities 
// 
// [ Menu ] -> Visual?
//    [ Settings ] [ Keybindings | Audio | ]
//
// [ Ability Description ] - Hoverover hand | upgrade section
//
//
//
//
//
//
//
//
//-----------------------------------------------------
