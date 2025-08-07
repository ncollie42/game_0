package main

import "core:fmt"
import rl "vendor:raylib"

// NOTE: Making this global for now, not sure if this is actually how I want it.
// This is only used when transitioning to Attack on enemies
// updateRange(warning) -> EnterEnemyState(attack, warning)

Warning :: struct {
	pos:      vec3,
	duration: f32,
}

Warnings: [dynamic]Warning

// TODO: Repalce the ! with an actual model?
// warningModel: rl.Model
initWarnings :: proc() {}

spawnWarning :: proc(pos: vec3) {
	append(&Warnings, Warning{pos, .35})
}

updateWarning :: proc() {
	// Loop in reverse and swap with last element on remove
	#reverse for &warning, index in Warnings {
		warning.duration -= getDelta()
		if warning.duration <= 0 {
			unordered_remove(&Warnings, index)
		}
	}
}

drawWarnings :: proc(camera: rl.Camera) {
	for warning in Warnings {
		rl.DrawBillboard(camera, Textures[.Warning], warning.pos, 1.25, rl.WHITE)
		// // |
		// rl.DrawCube(warning.pos + {0, .5, 0}, .1, .5, .1, rl.RED)
		// // .
		// rl.DrawCube(warning.pos, .1, .1, .1, rl.RED)
	}
}
