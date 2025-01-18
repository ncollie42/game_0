package main

import "core:fmt"
import rl "vendor:raylib"

ImpactPool :: struct {
	fpsCheck: f32,
	texture:  rl.Texture2D,
	rows:     i32,
	cols:     i32,
	// Size of frame
	width:    i32,
	height:   i32,
	// total number of frames in texture
	total:    i32,
	active:   [dynamic]Impact, // inline struct here?
}

// Animated Sprite
Impact :: struct {
	current: i32, // Active frame
	pos:     vec3,
}


FPS_IMPACT: f32 = 1.0 / 160.0 // impact


spawnImpact :: proc(pool: ^ImpactPool, pos: vec3) {
	if len(pool.active) == cap(pool.active) {
		// Do nothing if there isn't space for a new one.
		return
	}

	impact := Impact{0, pos}
	append(&pool.active, impact)
}


initImpactPool :: proc(path: cstring, width: i32, height: i32, frames: i32) -> ImpactPool {

	texture := rl.LoadTexture(path)
	assert(rl.IsTextureValid(texture), "Not able to load texture")

	pool := ImpactPool {
		active  = make([dynamic]Impact, 1, 15),
		texture = texture,
		rows    = texture.width / width,
		cols    = texture.height / height,
		width   = width,
		height  = height,
		total   = frames,
	}

	return pool
}


updateImpactPool :: proc(pool: ^ImpactPool) {
	pool.fpsCheck += rl.GetFrameTime()
	if pool.fpsCheck >= FPS_IMPACT {
		pool.fpsCheck = 0
		return
	}

	// Loop in reverse and swap with last element on remove
	#reverse for &impact, index in pool.active {
		impact.current += 1
		if impact.current == pool.total {
			unordered_remove(&pool.active, index)
		}
	}
}

drawImpactPool :: proc(camera: rl.Camera, pool: ImpactPool) {
	// NOTE: draw order matters, I might want to make a pass and sort based on z. OR do in insert
	for impact in pool.active {
		down := impact.current / pool.rows
		right := int(impact.current) % int(pool.rows)

		source_rec := rl.Rectangle {
			x      = f32(pool.width) * f32(right),
			y      = f32(pool.height) * f32(down),
			width  = f32(pool.width),
			height = f32(pool.height),
		}
		// rl.DrawBillboard(camera, pool.texture, impact.pos, 3, rl.WHITE)
		rl.DrawBillboardRec(
			camera,
			pool.texture,
			source_rec,
			impact.pos + {0, 1.5, 0},
			1.5,
			rl.WHITE,
		)
	}
}
