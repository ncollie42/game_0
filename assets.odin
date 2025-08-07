package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"


Shaders := [ShaderNames]rl.Shader{}
ShaderNames :: enum {
	None,
	GrayScale,
	Flash,
	Discard,
	Shadow,
	Black,
	Hull,
	Light, // TODO: https://youtu.be/yyJ-hdISgnw?si=k1GOwqAXirDFDNBR&t=2112
	Tiling,
}

loadShaders :: proc() {
	// ---------------  Shaders  --------------
	// Shaders[.Flash] = rl.LoadShader(nil, "shaders/flash.fs")
	Shaders[.Flash] = rl.LoadShaderFromMemory(nil, FLASH_FS)
	Shaders[.Hull] = rl.LoadShaderFromMemory(HULL_VS, HULL_FS)
	Shaders[.GrayScale] = rl.LoadShaderFromMemory(nil, GRAY_FS)
	Shaders[.Discard] = rl.LoadShaderFromMemory(nil, DISCARD_FS)
	Shaders[.Shadow] = rl.LoadShaderFromMemory(SHADOW_VS, SHADOW_FS)
	Shaders[.Black] = rl.LoadShaderFromMemory(nil, SHADOW_FS)
	// Shaders[.Light] = rl.LoadShader("shaders/light.vs", "shaders/light.fs")
	Shaders[.Tiling] = rl.LoadShaderFromMemory(nil, TILING_FS)

	// ---------------  Textures  --------------
	whiteImage := rl.GenImageColor(1, 1, rl.WHITE)
	Textures[.White] = rl.LoadTextureFromImage(whiteImage)
	rl.UnloadImage(whiteImage)
	Textures[.Mark1] = memLoadTexture(.Mark1)
	Textures[.Mark2] = memLoadTexture(.Mark2)
	Textures[.Fire] = memLoadTexture(.Fire)
	Textures[.Fist] = memLoadTexture(.Fist)
	Textures[.Synty_01_A] = memLoadTexture(.Synty_01_A)
	Textures[.Thorn] = memLoadTexture(.Thorn)
	Textures[.Monolith] = memLoadTexture(.Monolith)
	Textures[.Spawning] = memLoadTexture(.Spawning)
	Textures[.Warning] = memLoadTexture(.Warning)
	Textures[.Impact] = memLoadTexture(.Impact)
	Textures[.Trail_1] = memLoadTexture(.Trail_1)
	Textures[.Trail_2] = memLoadTexture(.Trail_2)
	Textures[.HalfCircle] = memLoadTexture(.HalfCircle)
}

/* ----------------
      Loaders
 ------------------*/
memLoadModelWithTexture :: proc(m: ModelName, t: TextureName) -> rl.Model {
	model := memLoadModel(m)
	texture := memLoadTexture(t)

	count := model.materialCount - 1
	model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture

	return model
}
/* ----------------------------------------
                  Texture
 ---------------------------------------- */

Textures := [TextureName]rl.Texture2D{}
TextureName :: enum {
	None,
	White,
	Mark1,
	Mark2,
	Fire,
	Fist,
	Synty_01_A,
	Thorn,
	Monolith,
	Spawning,
	Warning,
	Impact,
	Trail_1,
	Trail_2,
	HalfCircle,
	Gem,
}

AssetTexture := [TextureName][]u8 {
	.None       = {},
	.White      = {},
	.Mark1      = #load("resources/mark_1.png"),
	.Mark2      = #load("resources/mark_2.png"),
	.Fire       = #load("resources/fire.png"),
	.Fist       = #load("resources/fist.png"),
	.Synty_01_A = #load("resources/base.png"),
	.Thorn      = #load("resources/thorn/base.png"),
	.Monolith   = #load("resources/monolith/base2.png"),
	.Spawning   = #load("resources/mark_2.png"),
	.Warning    = #load("resources/mark_4.png"),
	.Impact     = #load("resources/impact.png"),
	.Trail_1    = #load("resources/trail_1.png"),
	.Trail_2    = #load("resources/trail_2.png"),
	.HalfCircle = #load("resources/half_circle.png"),
	.Gem        = #load("resources/gems/base.png"),
}

// Direct loading without callbacks -> Use this
memLoadTexture :: proc(name: TextureName) -> rl.Texture2D {
	// Get embedded data directly
	data := AssetTexture[name]

	// Load image from memory
	img := rl.LoadImageFromMemory(
		".png", // or whatever format your textures are
		raw_data(data),
		i32(len(data)),
	)

	// Convert to texture
	texture := rl.LoadTextureFromImage(img)

	// Clean up image
	rl.UnloadImage(img)

	return texture
}

/* ----------------------------------------
                  Models
 ---------------------------------------- */

ModelName :: enum {
	None,
	Player,
	Enemy_Dummy,
	Enemy_Mele,
	Enemy_Range,
	Enemy_Giant,
	Enemy_Thorn,
	Enemy_Monolith,
	Gem,
}

AssetModel := [ModelName][]u8 {
	.None           = {},
	.Player         = #load("resources/player/base.m3d"),
	.Enemy_Dummy    = #load("resources/enemy_giant/base.m3d"),
	.Enemy_Mele     = #load("resources/enemy_mele/base.m3d"),
	.Enemy_Range    = #load("resources/enemy_range/base.m3d"),
	.Enemy_Giant    = #load("resources/enemy_giant/base.m3d"),
	.Enemy_Thorn    = #load("resources/thorn/base.m3d"),
	.Enemy_Monolith = #load("resources/monolith/base.m3d"),
	.Gem            = #load("resources/gems/base.m3d"),
}

// Sometimes writing to a temp file is simpler
// loadModelEmb :: proc(name: ModelName) -> rl.Model {
// 	asset := AssetModel[name]
// 	// assert(ok, "Model not found")

// 	// Create temp file path -> Assume we only use m3d
// 	temp_path := fmt.tprintf("/tmp/temp_model_%v.m3d", name)
// 	fmt.println("Temp path", temp_path)
// 	temp_cstr := strings.clone_to_cstring(temp_path, context.temp_allocator)

// 	// Write to temp file
// 	os.write_entire_file(temp_path, asset)
// 	defer os.remove(temp_path) // Clean up

// 	// Load normally
// 	return rl.LoadModel(temp_cstr)
// }

// Callback for model loading
rl_load_model_callback :: proc "c" (fileName: cstring, dataSize: ^i32) -> [^]byte {
	context = runtime.default_context()

	// fmt.println("[Model Load]", fileName)
	extentions := []string{".m3d", ".glb", ".gltf", ".obj"}
	// Check each model
	for name in ModelName {
		data := AssetModel[name]
		// Try different extensions
		for ext in extentions {
			expected := fmt.ctprintf("%v%s", name, ext)
			if strings.compare(string(fileName), string(expected)) == 0 {
				if dataSize != nil {
					dataSize^ = i32(len(data))
				}

				// Allocate and copy
				result := cast([^]u8)rl.MemAlloc(u32(len(data)))
				runtime.mem_copy(result, raw_data(data), len(data))
				return result
			}
		}
	}

	// fmt.println("Model not found:", fileName)
	return nil
}

FileExtention :: enum {
	m3d,
	glb,
	gltf,
	obj,
}

memLoadModel :: proc(name: ModelName) -> rl.Model {
	// Assume it's all m3d
	return loadModelEmbAll(name, .m3d)
}

// Load model using callback
loadModelEmbAll :: proc(name: ModelName, extension: FileExtention) -> rl.Model {
	// Set callback
	rl.SetLoadFileDataCallback(rl_load_model_callback)

	// Create path that will trigger the callback
	path := fmt.ctprintf("%v.%v", name, extension) // TODO: free?

	// Load model (will use callback)
	model := rl.LoadModel(path)

	assert(rl.IsModelReady(model), "Failed to load model")
	assert(model.meshCount != 0, fmt.tprintf("[loadModel] Invalid Mesh %s", name))

	// Reset callback
	rl.SetLoadFileDataCallback(nil)
	return model
}

/* ----------------------------------------
                  Fonts
 ---------------------------------------- */

FontName :: enum {
	Default,
}

// Embedded font data
AssetFonts := [FontName][]u8 {
	.Default = #load("resources/fonts/Calistoga-Regular.ttf"),
}

loadFontEmb :: proc(name: FontName, fontSize: i32) -> rl.Font {
	data := AssetFonts[name]

	// Determine file type from data or store it
	fileType: cstring = ".ttf" // or ".otf"

	// Load font directly from memory!
	font := rl.LoadFontFromMemory(
		fileType,
		raw_data(data),
		i32(len(data)),
		fontSize * 2,
		nil, // Default characters
		0, // Default glyph count
	)

	return font
}

/* ----------------------------------------
                  Sound
 ---------------------------------------- */
SoundName :: enum {
	Grunt_1,
	Grunt_2,
	Grunt_3,
	Punch_1,
	Punch_2,
	Whoosh_1,
	Whoosh_2,
	Whoosh_3,
}

// MusicName :: enum {
//     Menu,
//     Battle,
//     Victory,
// }
AssetSounds := [SoundName][]u8 {
	.Grunt_1  = #load("resources/audio/grunt_01.wav"),
	.Grunt_2  = #load("resources/audio/grunt_02.wav"),
	.Grunt_3  = #load("resources/audio/jump_03.wav"),
	.Punch_1  = #load("resources/audio/Punch_1.wav"),
	.Punch_2  = #load("resources/audio/Punch_2.wav"),
	.Whoosh_1 = #load("resources/audio/Axe_Whoosh_01.wav"),
	.Whoosh_2 = #load("resources/audio/Axe_Whoosh_02.wav"),
	.Whoosh_3 = #load("resources/audio/Axe_Whoosh_03.wav"),
}

// Load sound directly from memory
// loadSoundFromMemory :: proc(name: SoundName) -> rl.Sound {
loadSoundEmb :: proc(name: SoundName) -> rl.Sound {
	data := AssetSounds[name]

	// assume file type is always .wav for now
	fileType: cstring = ".wav" // NOTE: we can loop and try all other options too.

	// Load wave from memory
	wave := rl.LoadWaveFromMemory(fileType, raw_data(data), i32(len(data)))

	// Convert to sound
	sound := rl.LoadSoundFromWave(wave)

	// Clean up wave data (sound has its own copy now)
	rl.UnloadWave(wave)

	return sound
}
