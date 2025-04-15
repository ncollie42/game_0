package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// Add multiple textures, and index :: put all flipbooks in one, and sort before update
Flipbook :: struct {
	fpsCheck: f32,
	texture:  rl.Texture2D,
	rows:     i32,
	cols:     i32,
	// Size of frame
	width:    i32,
	height:   i32,
	// total number of frames in texture
	total:    i32,
	active:   [dynamic]Particle, // inline struct here?
	// One Shot?
}

// Animated Sprite
Particle :: struct {
	frame: f32,
	pos:   vec3,
	rot:   f32,
}

spawnFlipbook :: proc(pool: ^Flipbook, pos: vec3, rot: f32) {
	assert(pool != nil, "flipbook is nil")
	if len(pool.active) == cap(pool.active) {
		// Do nothing if there isn't space for a new one.
		return
	}

	impact := Particle{0, pos, rot}
	append(&pool.active, impact)
}

initFlipbookPool :: proc(path: cstring, width: i32, height: i32, frames: i32) -> Flipbook {
	texture := rl.LoadTexture(path)
	assert(rl.IsTextureValid(texture), "Not able to load texture")

	pool := Flipbook {
		active  = make([dynamic]Particle, 0, 15),
		texture = texture,
		rows    = texture.width / width,
		cols    = texture.height / height,
		width   = width,
		height  = height,
		total   = frames,
	}

	return pool
}


updateFlipbookOneShot :: proc(pool: ^Flipbook, FPS: f32) {
	// Loop in reverse and swap with last element on remove
	#reverse for &impact, index in pool.active {
		impact.frame += rl.GetFrameTime() * FPS
		current := i32(math.floor(impact.frame))
		if current >= pool.total {
			unordered_remove(&pool.active, index)
		}
	}
}

updateFlipbook :: proc(pool: ^Flipbook, FPS: f32) {
	for &impact, index in pool.active {
		impact.frame += rl.GetFrameTime() * FPS
		current := i32(math.floor(impact.frame))
		if current > pool.total {
			impact.frame = 0
		}
	}
}

drawFlipbook :: proc(
	camera: rl.Camera,
	pool: Flipbook,
	size: f32,
	offsetPos: vec3,
	offsetDeg: f32,
) {
	for &impact in pool.active {
		current := i32(math.floor(impact.frame))

		down := current / pool.rows
		right := int(current) % int(pool.rows)

		source_rec := rl.Rectangle {
			x      = f32(pool.width) * f32(right),
			y      = f32(pool.height) * f32(down),
			width  = f32(pool.width),
			height = f32(pool.height),
		}

		pos := impact.pos + offsetPos

		// rl.DrawBillboard(camera, pool.texture, impact.pos + {0, 2, 0}, 3, rl.WHITE)
		// rl.DrawBillboardRec(camera, pool.texture, source_rec, pos, size, rl.WHITE)

		rl.DrawBillboardPro(
			camera,
			pool.texture,
			source_rec,
			pos + {0, size / 2, 0},
			UP,
			size,
			{size / 2, size / 2},
			impact.rot * rl.RAD2DEG + offsetDeg,
			rl.WHITE,
		)
	}
}
drawFireFlipbook :: proc(camera: rl.Camera, pool: Flipbook) {
	drawFlipbook(camera, pool, 4, {0, 0, 0}, 0)
}
drawMeleTrail :: proc(camera: rl.Camera, pool: Flipbook) {
	drawFlipbook(camera, pool, 3, {0, 0, 0}, 180)
}
