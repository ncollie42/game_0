package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import rl "vendor:raylib"


// https://www.youtube.com/watch?v=tu-Qe66AvtY
// https://www.youtube.com/watch?v=2JXR7IASSog

camDist: vec3 = {0, 6, -5} * 2
CAMERA_SPEED :: 5

screenShake := struct {
	trauma: f32, // [0,1]
	shake:  f32, // trauma^2 or ^3
	debug:  bool, // Prevent trauma from going down linear
} {
	trauma = 0,
	shake  = 0,
	debug  = false,
}

newCamera :: proc() -> ^rl.Camera3D {
	camera := new(rl.Camera3D)
	camera^ = rl.Camera3D {
		position   = camDist,
		target     = {}, // what the camera is looking at
		up         = {0, 1, 0},
		// fovy       = 30,
		// projection = .ORTHOGRAPHIC,
		fovy       = 60,
		projection = .PERSPECTIVE,
	}
	return camera
}

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

SHAKE_DEPLETION :: 1
SHAKE_DISTANCE :: .03
SHAKE_SPEED :: 2
// Figuring out what to move for screen shake
// YAW and PITCH both probably wont work, they move the camera target.
// MOVE UP/DOWN RIGHT/LEFT -> might be alrigh
// ROLL could also work but I need to find a way to reset the values.
updateCameraShake :: proc(camera: ^rl.Camera3D) {
	screenShake.trauma -= getDelta() * SHAKE_DEPLETION
	screenShake.trauma = rl.Clamp(screenShake.trauma, 0, 1)
	screenShake.shake = screenShake.trauma * screenShake.trauma

	maxRoll: f32 = rl.PI / 2
	roll := maxRoll * screenShake.shake * noise.noise_2d(1, {0, rl.GetTime()})

	noice1 := noise.noise_2d(1, {0, rl.GetTime() * SHAKE_SPEED})
	noice2 := noise.noise_2d(2, {0, rl.GetTime() * SHAKE_SPEED})
	noice3 := noise.noise_2d(2, {0, rl.GetTime() * SHAKE_SPEED})

	leftRightAmount := SHAKE_DISTANCE * screenShake.shake * noice1
	upDownAmount := SHAKE_DISTANCE * screenShake.shake * noice2

	// SHAKE
	rl.CameraMoveRight(camera, leftRightAmount, getDelta())
	rl.CameraMoveUp(camera, upDownAmount)
	// rl.CameraRoll(camera, 0) // Maybe

	//Add to camera for that frame, preserve the base camerar
}


addTrauma :: proc(amount: enum {
		small,
		mid,
		large,
	}) {
	switch amount {
	case .small:
		screenShake.trauma += .3
	case .mid:
		screenShake.trauma += .5
	case .large:
		screenShake.trauma = 1
	}
}

zoomOut :: proc(camera: ^rl.Camera3D) {
	rl.CameraMoveToTarget(camera, 1)
}

zoomIn :: proc(camera: ^rl.Camera3D) {
	rl.CameraMoveToTarget(camera, -1)
}

updateCameraPos :: proc(camera: ^rl.Camera3D, player: Player) {
	// Should we take into account the mouse? mid point between the 2?
	targetPos := player.spacial.pos + camDist
	// Move 10% closer every frame
	camera.position += (targetPos - camera.position) * .1
	camera.target = camera.position - camDist

	if rl.IsKeyDown(.T) {
		zoomOut(camera)
	}
	if rl.IsKeyDown(.Y) {
		zoomIn(camera)
	}
}

drawCamera :: proc(camera: ^rl.Camera3D) {
	pos := mouseInWorld(camera)
	rl.DrawCubeWires(pos, .25, .25, .25, rl.RED)
	rl.DrawCube(pos, .1, .1, .1, rl.GREEN)
}
