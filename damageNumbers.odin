package main
import clay "/clay-odin"
import "core:fmt"
import "core:math/ease"
import rl "vendor:raylib"

FloatingText :: enum {
	Default,
	Normal,
	Crit,
	// XP
}
DamageNumber :: struct {
	text:     cstring,
	pos:      vec3,
	duration: f32,
	type:     FloatingText,
}

DamageNumbers: [dynamic]DamageNumber

// NOTE: Making this global for now, not sure if this is actually how I want it.
initDamageNumbers :: proc() {
	shrink(&DamageNumbers)
	// warningModel := loadModel()
}

// spawnFloatingText :: proc(pos, text, duration, type)
spawnDamangeNumber :: proc(pos: vec3, amount: f32) {
	// TODO: add randomness so they don't overlap or use some other system.
	append(&DamageNumbers, DamageNumber{fmt.ctprint(amount), pos, DamageNumberDuration, .Default})
}

updateDamageNumbers :: proc() {
	// Loop in reverse and swap with last element on remove
	#reverse for &warning, index in DamageNumbers {
		warning.duration -= getDelta()
		if warning.duration <= 0 {
			unordered_remove(&DamageNumbers, index)
			//TODO: free the cstring?
		}
	}
}

drawDamageNumbers :: proc() {
	// pos := rl.GetWorldToScreen({}, camera^)
	for number in DamageNumbers {
		rl.DrawCube(number.pos, .5, .5, .5, rl.BLUE)
	}
}

DamageNumberDuration :: .8
DamageNumberSize :: 25

drawDamageNumbersUI :: proc(camera: ^rl.Camera) {
	rl.BeginMode2D(rl.Camera2D{zoom = f32(rl.GetScreenHeight()) / f32(P_H)})

	zoom := f32(rl.GetScreenHeight()) / f32(P_H)
	for number in DamageNumbers {
		pos := rl.GetWorldToScreen(number.pos, camera^)
		pos.x -= f32(rl.MeasureText(number.text, DamageNumberSize)) / 2 // Center text on point
		progress := (number.duration / DamageNumberDuration) // [0, 1]
		size: f32 = DamageNumberSize
		switch number.type {
		case .Default:
		case .Normal:
			pos += {0, -1} * rl.Remap(progress, 0, 1, 50, 0)
		case .Crit:
			size = ease.ease(.Exponential_In, progress) // [0,1]
			size = rl.Remap(size, 1, 0, DamageNumberSize * 4, DamageNumberSize * 2)
		}
		rl.DrawText(number.text, i32(pos.x / zoom), i32(pos.y / zoom), i32(size), rl.WHITE)
	}

	rl.EndMode2D()
}
