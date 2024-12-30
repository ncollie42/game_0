package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "vendor:raylib"

Spacial :: struct {
	rot:     f32, // rotation / Orientation
	pos:     vec3, // position
	dir:     vec3, // what direction it's going towards  - using for projectiles ; not sure if we need; maybe change to velocity?
	radious: f32, // For collision
}

getBackwardPoint :: proc(obj: ^Spacial) -> vec3 {
	// Return a point between 0 1 [0,0]
	mat := rl.MatrixRotateY(obj.rot)
	mat = mat * rl.MatrixTranslate(0, 0, -1)
	point := rl.Vector3Transform({}, mat)
	point = linalg.normalize(point)
	return point
}

getForwardPoint :: proc(obj: ^Spacial) -> vec3 {
	// Return a point between 0 1 [0,0]
	mat := rl.MatrixRotateY(obj.rot)
	mat = mat * rl.MatrixTranslate(0, 0, 1)
	point := rl.Vector3Transform({}, mat)
	point = linalg.normalize(point)
	return point
}
