package main

import "core:fmt"
import "core:math"
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
	frame: f32,
	pos:   vec3,
	rot:   f32,
}

spawnImpact :: proc(pool: ^ImpactPool, pos: vec3, rot: f32) {
	if len(pool.active) == cap(pool.active) {
		// Do nothing if there isn't space for a new one.
		return
	}

	impact := Impact{0, pos, rot}
	append(&pool.active, impact)
}

initImpactPool :: proc(path: cstring, width: i32, height: i32, frames: i32) -> ImpactPool {
	texture := rl.LoadTexture(path)
	assert(rl.IsTextureValid(texture), "Not able to load texture")

	pool := ImpactPool {
		active  = make([dynamic]Impact, 0, 15),
		texture = texture,
		rows    = texture.width / width,
		cols    = texture.height / height,
		width   = width,
		height  = height,
		total   = frames,
	}

	return pool
}


// updateOneShotFlipbook
updateImpactPool :: proc(pool: ^ImpactPool, FPS: f32) {

	// Loop in reverse and swap with last element on remove
	#reverse for &impact, index in pool.active {
		impact.frame += rl.GetFrameTime() * FPS
		current := i32(math.floor(impact.frame))
		if current == pool.total {
			unordered_remove(&pool.active, index)
		}
	}
}

drawImpactPool :: proc(camera: rl.Camera, pool: ImpactPool) {
	// NOTE: draw order matters, I might want to make a pass and sort based on z. OR do in insert
	for impact in pool.active {
		current := i32(math.floor(impact.frame))

		down := current / pool.rows
		right := int(current) % int(pool.rows)

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
			impact.pos + {0, 1.8, 0},
			2.8,
			rl.WHITE,
		)
	}
}

drawImpactPoolFlat :: proc(camera: rl.Camera, pool: ImpactPool) {
	// NOTE: draw order matters, I might want to make a pass and sort based on z. OR do in insert
	for impact in pool.active {
		current := i32(math.floor(impact.frame))

		down := current / pool.rows
		right := int(current) % int(pool.rows)

		source_rec := rl.Rectangle {
			x      = f32(pool.width) * f32(right),
			y      = f32(pool.height) * f32(down),
			width  = f32(pool.width),
			height = f32(pool.height),
		}
		fmt.println(current, source_rec, impact.rot)

		size: f32 = 4
		pos := impact.pos + {0, 1, 0}

		// rl.DrawBillboard(camera, pool.texture, impact.pos + {0, 2, 0}, 3, rl.WHITE)
		// rl.DrawBillboardRec(camera, pool.texture, source_rec, pos, size, rl.WHITE)

		rl.DrawBillboardPro(
			camera,
			pool.texture,
			source_rec,
			pos,
			UP,
			size,
			{size / 2, size / 2},
			impact.rot * rl.RAD2DEG + 90,
			rl.WHITE,
		)
	}
}
