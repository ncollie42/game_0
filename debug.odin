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
	// text3 := rl.LoadTexture("resources/floor/g3_heightmap.png")
	// text4 := rl.LoadTexture("resources/floor/g3_emission.png")
	// model.materials[model.materialCount - 1].maps[rl.MaterialMapIndex.NORMAL].texture = text2
	// model.materials[model.materialCount - 1].maps[rl.MaterialMapIndex.HEIGHT].texture = text3
	// model.materials[model.materialCount - 1].maps[rl.MaterialMapIndex.EMISSION].texture = text4
}
tileScale := 1.0
debugUpdateGame :: proc(game: ^Game) {
	using game

	grid := getSafePointInGrid(&game.enemies, player)
	mouse := mouseInWorld(camera)
	random := getRandomPoint()

	img = loadTexture("resources/mark_4.png")
	if rl.IsKeyPressed(.P) {
		doUpgrade(game, .RangeUnlock)
	}
	if rl.IsKeyPressed(.F) {
		uiStrech = !uiStrech
		spawnEnemy(&enemies, grid, .Range, true)
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
		debug = !debug
	}
	if rl.IsKeyPressed(.UP) {
		// timeScale += .25
		tileScale += 1
	}
	if rl.IsKeyPressed(.DOWN) {
		// timeScale -= .25
		tileScale -= 1
	}
	// fmt.println(tileScale)
	// tileScaleLocation := rl.GetShaderLocation(Shaders[.Tiling], "tileScale")
	// rl.SetShaderValue(Shaders[.Tiling], tileScaleLocation, &tileScale, .FLOAT)

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
	rl.DrawModel(model, {0, 0, 0}, 1, rl.WHITE)
}

// Preflight
// lazyGit - Odin - helix - brew - git
// Shader for floor w/ some circular drop off?
// Google docs of what is needed
