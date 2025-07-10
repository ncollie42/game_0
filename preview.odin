package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
// 
// drawPreview_Mouse
// DrawPreview_beam-1
//
// on aimation -> draw preview untill do ability or xx

drawPreviewCircle :: proc(camera: ^rl.Camera, rad: f32) {
	// TODO: Swap with texture + shader
	mouse := mouseInWorld(camera)

	rl.DrawCircle3D(mouse + {0, .1, 0}, rad, {1, 0, 0}, 90, rl.WHITE)
}

// Up to max dist
drawPreviewCircleWithMaxDist :: proc(
	player: ^Player,
	camera: ^rl.Camera,
	rad: f32,
	maxDistance: f32,
) {
	mouse := mouseInWorld(camera)
	dist := min(distance_to(mouse, player.pos), maxDistance)
	target := normalize(mouse - player.pos) * dist
	finalPos := player.pos + target + {0, .1, 0}

	rl.DrawCircle3D(finalPos, rad, {1, 0, 0}, 90, rl.WHITE)
}

// Fixed size
drawPreviewCircleWithDist :: proc(player: ^Player, camera: ^rl.Camera, rad: f32, dist: f32) {
	mouse := mouseInWorld(camera)
	target := normalize(mouse - player.pos) * dist
	finalPos := player.pos + target + {0, .1, 0}

	rl.DrawCircle3D(finalPos, rad, {1, 0, 0}, 90, rl.WHITE)
}

drawPreviewline :: proc(player: ^Player, camera: ^rl.Camera) {
	mouse := mouseInWorld(camera)

	rl.DrawLine3D(player.pos + {0, .1, 0}, mouse + {0, .1, 0}, rl.WHITE)
}

// Up to mouse
drawPreviewRec :: proc(player: ^Player, camera: ^rl.Camera) {
	mouse := mouseInWorld(camera)
	r := lookAtVec3(mouseInWorld(camera), player.spacial.pos) + rl.PI
	// get point left
	{
		mat := rl.MatrixRotateY(r)
		point := rl.Vector3Transform({1, 0, 0}, mat) // left
		point = normalize(point)
		p1 := player.pos + point + {0, .1, 0}
		p2 := mouse + point + {0, .1, 0}

		rl.DrawLine3D(p1, p2, rl.WHITE)
	}
	// get point right
	{
		mat := rl.MatrixRotateY(r)
		point := rl.Vector3Transform({-1, 0, 0}, mat) // left
		point = normalize(point)
		p1 := player.pos + point + {0, .1, 0}
		p2 := mouse + point + {0, .1, 0}

		rl.DrawLine3D(p1, p2, rl.WHITE)
	}
}

// Fixed sized
drawPreviewRecWithDist :: proc(player: ^Player, camera: ^rl.Camera, dist: f32) {
	mouse := mouseInWorld(camera)
	target := normalize(mouse - player.pos) * dist + player.pos

	r := lookAtVec3(mouseInWorld(camera), player.spacial.pos) + rl.PI
	// get point left
	{
		mat := rl.MatrixRotateY(r)
		point := rl.Vector3Transform({1, 0, 0}, mat) // left
		point = normalize(point)
		p1 := player.pos + point + {0, .1, 0}
		p2 := target + point + {0, .1, 0}

		rl.DrawLine3D(p1, p2, rl.WHITE)
	}
	// get point right
	{
		mat := rl.MatrixRotateY(r)
		point := rl.Vector3Transform({-1, 0, 0}, mat) // left
		point = normalize(point)
		p1 := player.pos + point + {0, .1, 0}
		p2 := target + point + {0, .1, 0}

		rl.DrawLine3D(p1, p2, rl.WHITE)
	}
}
