package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "vendor:raylib"

Box :: rl.BoundingBox
Sphere :: f32 // radious
// bounds ::union{box, sphere}
Spacial :: struct {
	rot:   f32, // rotation / Orientation in Radians
	pos:   vec3, // position
	shape: union {
		// For collision
		Box,
		Sphere,
	},
}

getBackwardPoint :: proc(obj: ^Spacial) -> vec3 {
	// Return a point between 0 1 [0,0]
	mat := rl.MatrixRotateY(obj.rot)
	point := rl.Vector3Transform({0, 0, -1}, mat)
	point = normalize(point)
	return point
}

getForwardPoint :: proc(obj: Spacial) -> vec3 {
	// Return a point between 0 1 [0,0]
	mat := rl.MatrixRotateY(obj.rot)
	point := rl.Vector3Transform({0, 0, 1}, mat)
	point = normalize(point)
	return point
}

directionFromRotation :: proc(rotation: f32) -> vec3 {
	// Return a point between 0 1 [0,0]
	mat := rl.MatrixRotateY(rotation)
	point := rl.Vector3Transform({0, 0, 1}, mat)
	point = normalize(point)
	return point
}
