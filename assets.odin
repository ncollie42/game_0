package main

import rl "vendor:raylib"


AssetNames :: enum {
	None,
}

allAssets := [AssetNames][]u8 {
	.None = {},
	// .GrayScaleFS = #load("shaders/grayScale.fs"),
}

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

Textures := [TextureName]rl.Texture2D{}
whiteTexture: rl.Texture2D
TextureName :: enum {
	None,
	White,
	Mark1,
	Mark2,
}
loadShaders :: proc() {
	Shaders[.Flash] = rl.LoadShader(nil, "shaders/flash.fs")
	Shaders[.Hull] = rl.LoadShader("shaders/hull.vs", "shaders/hull.fs")
	Shaders[.GrayScale] = rl.LoadShader(nil, "shaders/grayScale.fs")
	Shaders[.Discard] = rl.LoadShader(nil, "shaders/alphaDiscard.fs")
	Shaders[.Shadow] = rl.LoadShader("shaders/shadow.vs", "shaders/shadow.fs")
	Shaders[.Black] = rl.LoadShader(nil, "shaders/shadow.fs")
	// Shaders[.Light] = rl.LoadShader("shaders/light.vs", "shaders/light.fs")
	Shaders[.Tiling] = rl.LoadShader(nil, "shaders/tiling.fs")

	Textures[.Mark1] = rl.LoadTexture("resources/mark_1.png")
	Textures[.Mark2] = rl.LoadTexture("resources/mark_2.png")
	whiteImage := rl.GenImageColor(1, 1, rl.WHITE)
	Textures[.White] = rl.LoadTextureFromImage(whiteImage)
	rl.UnloadImage(whiteImage)
	// rl.LoadFontFromMemory()
	// rl.LoadImageFromMemory()
	// rl.LoadWaveFromMemory()
}
