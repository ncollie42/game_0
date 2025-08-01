package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

model: rl.Model
// text: rl.Texture2D
// animState: AnimationState = {
// 	current = ENEMY.run,
// 	speed   = 1,
// }
// animSet: AnimationSet
debugInit :: proc(game: ^Game) {
	using game

	// model = rl.LoadModel("/home/nico/Godot/test2/grid_map.gltf")
	// model = rl.LoadModel("/home/nico/Downloads/ground.m3d")

	mesh := rl.GenMeshPlane(10, 10, 5, 5)
	model = rl.LoadModelFromMesh(mesh)

	count := model.materialCount - 1
	model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = Textures[.Synty_01_A]
}

debugUpdateGame :: proc(game: ^Game) {
	using game

	grid := getSafePointInGrid(&game.enemies, player)
	mouse := mouseInWorld(camera)
	random := getRandomPoint()

	if rl.IsKeyPressed(.N) {
		// doUpgrade(game, .RangeUnlock)
		doUpgrade(game, .GravityUnlock)
	}
	if rl.IsKeyPressed(.F) {
		ability := newBeamInstance(player, 1, 0, camera, &enemies)
		append(&playerAbilities.active, ability)
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

	rl.DrawModel(model, {}, 1, rl.WHITE)
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
// [ ] Deck + Auto loot card on timer | Disard pile
//    What happens on disard.
//    What is loot timer + Mana timer
// 
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
// [ Menu ] -> Visual?
//    [ Settings ] [ Keybindings | Audio | ]
//
// [ Ability Description ] - Hoverover hand | upgrade section
//
//
//
//-----------------------------------------------------
// Animation
//   | Ability Preview
//   | Spawn ability
//   | Cancel Frame
//
// Ability
//   | { Some Basic Damage + Some interesting resource } Particle {Stone | Fire | Gems | Mana | Hand | Tree | Grass | Void | Turrets | wind}
//
// 1. Parry | Anim
//    - Duration
//    - Show duration over head
//    - If hit while parry -> Spawn ability
// 2. Beam |
//    - Preview always | Rec
//    - On tick do damage
//    - Connect beam to player - Cancel if state is broken. TODO:
// 3. Range |
//    - Preview | Rec
//
// ------------------- TODO:
// New Animations:
// - Parry
// - Beam
// - Range + State
// ------------------- TODO:
// P0
// - [ ] Gems give XP
// - [ ] Hud With Mana | Card draw on timer
// - [ ] Ability planning | ~9 per resource
// P1
// - New Animations + Abilitys
// p2
// - New Models + Color pallets
// - New Env floor
// - New Shader for bounds
//
//
//
// ------------------ Bro's load file call back --------------------
// package assets

// import runtime "base:runtime"
// import fmt "core:fmt"
// import rl "vendor:raylib"

// import genmesh "../genmesh"
// import types "../types"

// init :: proc() {
// 	genmesh.init()
// 	init_asset_path_to_id_map()
// 	rl.SetLoadFileDataCallback(rl_load_file_data_callback)
// }

// quit :: proc() {
// 	genmesh.quit()
// 	delete(asset_path_to_id)
// }


// // for file loading
// asset_path_to_id: map[cstring]types.AssetName
// @(private)
// init_asset_path_to_id_map :: proc() {
// 	asset_path_to_id = make_map(map[cstring]types.AssetName)
// 	reserve(&asset_path_to_id, cast(int)types.AssetName.Generated - 1)
// 	for asset_info, key in assets {
// 		if key != types.AssetName.Generated && key != types.AssetName.None {
// 			asset_path_to_id[asset_info.path] = key
// 		}
// 	}
// 	fmt.println("Asset map: ", asset_path_to_id)
// }

// @(private)
// rl_load_file_data_callback :: proc "c" (fileName: cstring, dataSize: ^i32) -> [^]u8 {
// 	if asset_path_to_id == nil || fileName == nil || dataSize == nil {
// 		return nil
// 	}
// 	asset_id, ok := asset_path_to_id[fileName]
// 	if !ok {
// 		return nil
// 	}
// 	assets := assets
// 	asset_info := assets[asset_id]
// 	dataSize^ = cast(i32)len(asset_info.file)

// 	// data unallocated by raylib with UnloadModelAnimation and UnloadModel
// 	data: [^]u8 = ([^]u8)(rl.MemAlloc(cast(u32)dataSize^))
// 	if data == nil {
// 		return nil
// 	}

// 	runtime.mem_copy(data, raw_data(asset_info.file), len(asset_info.file))
// 	return data
// }
