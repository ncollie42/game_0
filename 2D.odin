package main

import "core:fmt"
import rl "vendor:raylib"

// Animated Sprite
Flipbook :: struct {
	texture:  rl.Texture2D,
	// size of a frame
	width:    i32,
	height:   i32,
	// 
	rows:     i32,
	cols:     i32,
	// Frames
	FPSCheck: f32, // We can remove this to a shared thing?
	current:  i32,
	total:    i32,
	// One Shot?
}

// TODO: make pool

// W/H of a frame
initFlipbook :: proc(path: cstring, width: i32, height: i32, frames: i32) -> ^Flipbook {
	texture := rl.LoadTexture(path)
	assert(rl.IsTextureValid(texture), "Not able to load texture")

	book := new(Flipbook)
	book^ = Flipbook {
		texture = texture,
		width   = width,
		height  = height,
		rows    = texture.width / width,
		cols    = texture.height / height,
		current = 0,
		total   = frames,
	}
	return book
}

FPS: f32 = 1.0 / 60.0 // impact
// FPS: f32 = 1.0 / 30.0 // Fire
// 1 / 24

// updateFlipbookImpact :: proc(flipbook: ^Flipbook) {

updateFlipbook :: proc(flipbook: ^Flipbook) {
	flipbook.FPSCheck += rl.GetFrameTime()
	// Only Up every X amount of time
	if flipbook.FPSCheck <= FPS {
		return
	}
	flipbook.FPSCheck = 0
	flipbook.current = (flipbook.current + 1) % flipbook.total
	// if flipbook.current == flipbook.total
	r += rl.GetFrameTime() * 80
}

r: f32 = 0
drawFlipbook :: proc(camera: rl.Camera, flipbook: Flipbook, pos: vec3, scale: vec2 = 1) {
	down := flipbook.current / flipbook.rows
	right := int(flipbook.current) % int(flipbook.rows)

	source_rec := rl.Rectangle {
		x      = f32(flipbook.width) * f32(right),
		y      = f32(flipbook.height) * f32(down),
		width  = f32(flipbook.width),
		height = f32(flipbook.height),
	}
	// rl.DrawBillboard(camera, flipbook.texture, pos, 3, rl.WHITE)
	rl.DrawBillboardRec(camera, flipbook.texture, source_rec, pos, scale, rl.WHITE)

	// rotate around origin
	// Here we choose to rotate the image center
	// rl.DrawBillboardPro(
	// 	camera,
	// 	flipbook.texture,
	// 	source_rec,
	// 	{0, 0, 0},
	// 	{0, 1, 0}, // Upvector
	// 	{3, 3},
	// 	{1.5, 0}, // Origin. // Offset wtih half of the scale
	// 	0,
	// 	rl.WHITE,
	// )
}
