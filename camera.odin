package main

import rl "vendor:raylib"

mouseInWorld :: proc(camera: ^rl.Camera3D) -> vec3 {
	// rotation
	ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), camera^)
	// check against ground, later make this be relative to player?
	groundHitInfo := rl.GetRayCollisionQuad(
		ray,
		{-50, 0, -50},
		{-50, 0, 50},
		{50, 0, 50},
		{50, 0, -50},
	)

	return groundHitInfo.point
}
