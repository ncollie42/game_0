package main

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import rl "vendor:raylib"

// https://bztsrc.gitlab.io/model3d/viewer/
// Linear Algebra : https://www.youtube.com/watch?v=fNk_zzaMoSs&list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab&index=4

// vec2 type
vec2 :: [2]f32
// vec3 type
vec3 :: [3]f32
// vec4 type
vec4 :: [4]f32

UP :: vec3{0, 1, 0}

// Delta
timeScale: f32 = 1

hitStop := struct {
	enable:   bool,
	duration: f32,
	state:    enum {
		waiting,
		fadeIn,
		hold,
		fadeOut,
	},
}{}

startHitStop :: proc() {
	hitStop.enable = true
}

// Ease: https://easings.net/
updateHitStop :: proc() {
	// Only use for player attacks
	// 115 MS, 7 frames, ~.11666 tottal
	// stateDuration: f32 = .04
	inOut: f32 = .03 * 1
	holdTime: f32 = .06 * 1

	switch hitStop.state {
	case .waiting:
		if !hitStop.enable {return}

		hitStop.state = .fadeIn
		hitStop.duration = inOut
		hitStop.enable = false
	case .fadeIn:
		hitStop.duration -= rl.GetFrameTime()

		progress := 1 - (hitStop.duration / inOut) // [0, 1]
		amount := ease.ease(.Cubic_In, progress) // [0,1]
		timeScale = rl.Remap(amount, 1, 0, .05, 1)
		timeScale = clamp(timeScale, .05, 1) // Prevent over shoot on the last tick, progress > 100%

		if hitStop.duration > 0 {return}

		hitStop.state = .hold
		hitStop.duration = holdTime
	case .hold:
		hitStop.duration -= rl.GetFrameTime()

		if hitStop.duration > 0 {return}

		hitStop.state = .fadeOut
		hitStop.duration = inOut
	case .fadeOut:
		hitStop.duration -= rl.GetFrameTime()

		progress := 1 - (hitStop.duration / inOut) // [0, 1]
		amount := ease.ease(.Cubic_Out, progress) // [0, 1]
		timeScale = rl.Remap(amount, 1, 0, 1, .05)
		timeScale = clamp(timeScale, .05, 1) // Prevent over shoot on the last tick, progress > 100%

		if hitStop.duration > 0 {return}

		hitStop.state = .waiting
	case:
		hitStop.state = .waiting
	}
	assert(timeScale > 0, "Timescale can't be negative! Goofed up somewhere")
}

getDelta :: proc() -> f32 {
	// Used for timeScale is used for hitstop, dont use this delta for env visuals IE: particles.
	return rl.GetFrameTime() * timeScale
}

// Key presses
KeyBinding :: union {
	rl.MouseButton,
	rl.KeyboardKey,
}

keyBindings := [4]KeyBinding{ACTION_0, ACTION_1, ACTION_2, ACTION_3}
ACTION_0 :: rl.MouseButton.LEFT
ACTION_1 :: rl.KeyboardKey.Q
ACTION_2 :: rl.KeyboardKey.E
ACTION_3 :: rl.KeyboardKey.R
BLOCK :: rl.KeyboardKey.LEFT_SHIFT
DASH :: rl.KeyboardKey.SPACE
PICKUP :: rl.KeyboardKey.F
// Movement
FORWARD :: rl.KeyboardKey.W
BACKWARD :: rl.KeyboardKey.S
RIGHT :: rl.KeyboardKey.D
LEFT :: rl.KeyboardKey.A

isKeyPressed :: proc(keyBind: KeyBinding) -> bool {
	// TODO: change for pressed work on key down and not key up
	switch key in keyBind {
	case rl.MouseButton:
		if rl.IsMouseButtonReleased(key) {
			return true
		}
	case rl.KeyboardKey:
		if rl.IsKeyPressed(key) {
			return true
		}
	}
	return false
}

isKeyDown :: proc(keyBind: KeyBinding) -> bool {
	// TODO: change for pressed work on key down and not key up
	switch key in keyBind {
	case rl.MouseButton:
		if rl.IsMouseButtonDown(key) {
			return true
		}
	case rl.KeyboardKey:
		if rl.IsKeyDown(key) {
			return true
		}
	}
	return false
}

// Animation: state machine based on current state?
getVector :: proc() -> (dir: vec3) {
	if rl.IsKeyDown(.W) {
		dir += Direction_Vecs[.North]
	}
	if rl.IsKeyDown(.S) {
		dir += Direction_Vecs[.South]
	}
	if rl.IsKeyDown(.A) {
		dir += Direction_Vecs[.West]
	}
	if rl.IsKeyDown(.D) {
		dir += Direction_Vecs[.East]
	}
	return rl.Vector3Normalize(dir)
}

Direction :: enum {
	North,
	East,
	South,
	West,
}

Direction_Vecs := [Direction]vec3 {
	.North = {0, 0, +1},
	.West  = {+1, 0, 0},
	.South = {0, 0, -1},
	.East  = {-1, 0, 0},
}

lookAtVec3 :: proc(from, at: vec3) -> f32 {
	diff := from - at
	return math.atan2(diff.x, diff.z)
}

/*
	Trying to handle wrap-around issue between π and −π; prevent from rotating wrong way.
	Get diff betwen angles.
	Wrap diff to stay within range
	Lerp + wrap final incase going over range
*/
lerpRAD :: proc(current, target, amount: f32) -> f32 {
	diff := current - target
	delta := rl.Wrap(diff, -rl.PI, rl.PI) * -1
	// rad := rl.Lerp(current, current + delta, amount * getDelta())
	rad := rl.Lerp(current, current + delta, amount)
	return rl.Wrap(rad, -rl.PI, rl.PI)
}

// Timer
// make f16 -> convert rl.getframeTime to f16 runtime
Timer :: struct {
	max:  f32, //MAX
	left: f32, //Left
	//onShot: bool,
	//ready: bool, 
}

updateTimer :: proc(timer: ^Timer) {
	timer.left -= getDelta()
}

isTimerReady :: proc(timer: Timer) -> bool {
	return timer.left <= 0
}

startTimer :: proc(timer: ^Timer) {
	assert(timer.max > 0, "Timer max value not set")
	timer.left = timer.max
}

// -------------------------------------------
// Odin version of update model animation, using to later try and blend between 2 animations
updateModelAnimation :: proc(model: rl.Model, anim: rl.ModelAnimation, frame: i32) {
	rl.UpdateModelAnimationBones(model, anim, frame)
	// updateModelAnimationBones(model, anim, frame)

	for m in 0 ..< model.meshCount {
		mesh := &model.meshes[m]
		boneId: u8 = 0
		boneCounter := 0
		boneWeight: f32 = 0.0
		updated := false
		vValues := mesh.vertexCount * 3

		// Skip if missing bone data
		if mesh.boneWeights == nil || mesh.boneIds == nil do continue

		// Pre-calculate matrices for each bone to avoid recomputing -> this actually speeds up 10 FPS -> 60 FPS
		invTransposedBoneMatrices := make([]rl.Matrix, anim.boneCount)
		defer delete(invTransposedBoneMatrices)
		for i in 0 ..< anim.boneCount {
			invTransposedBoneMatrices[i] = rl.MatrixTranspose(
				rl.MatrixInvert(model.meshes[m].boneMatrices[i]),
			)
		}

		for vCounter: i32 = 0; vCounter < vValues; vCounter += 3 {
			// #no_bounds_check {
			mesh.animVertices[vCounter] = 0
			mesh.animVertices[vCounter + 1] = 0
			mesh.animVertices[vCounter + 2] = 0

			if mesh.animNormals != nil {
				mesh.animNormals[vCounter] = 0
				mesh.animNormals[vCounter + 1] = 0
				mesh.animNormals[vCounter + 2] = 0
			}

			// Iterates over 4 bones per vertex
			for j in 0 ..< 4 {
				boneWeight = mesh.boneWeights[boneCounter]
				boneId = mesh.boneIds[boneCounter]
				boneCounter += 1

				if boneWeight == 0 do continue

				vert: vec3
				// Load vertex directly into array
				vert.x = mesh.vertices[vCounter]
				vert.y = mesh.vertices[vCounter + 1]
				vert.z = mesh.vertices[vCounter + 2]

				// Transform vertex
				animVertex := rl.Vector3Transform(
					{vert.x, vert.y, vert.z},
					model.meshes[m].boneMatrices[boneId],
				)

				mesh.animVertices[vCounter] += animVertex.x * boneWeight
				mesh.animVertices[vCounter + 1] += animVertex.y * boneWeight
				mesh.animVertices[vCounter + 2] += animVertex.z * boneWeight

				updated = true

				if mesh.normals != nil && mesh.animNormals != nil {
					normal: vec3
					normal.x = mesh.normals[vCounter]
					normal.y = mesh.normals[vCounter + 1]
					normal.x = mesh.normals[vCounter + 2]

					animNormal := rl.Vector3Transform(
						{normal.x, normal.y, normal.z},
						invTransposedBoneMatrices[boneId],
					)

					mesh.animNormals[vCounter] += animNormal.x * boneWeight
					mesh.animNormals[vCounter + 1] += animNormal.y * boneWeight
					mesh.animNormals[vCounter + 2] += animNormal.z * boneWeight
				}
			}
		}

		if updated {
			rl.UpdateMeshBuffer(
				mesh^,
				0,
				mesh.animVertices,
				mesh.vertexCount * 3 * size_of(f32),
				0,
			)

			if mesh.normals != nil {
				rl.UpdateMeshBuffer(
					mesh^,
					2,
					mesh.animNormals,
					mesh.vertexCount * 3 * size_of(f32),
					0,
				)
			}
		}
	}
}

// This function is broken --- Fix later
updateModelAnimationBones :: proc(model: rl.Model, anim: rl.ModelAnimation, frame: i32) {
	if !(anim.frameCount > 0 && anim.bones != nil && anim.framePoses != nil) {
		return
	}
	aframe := frame
	if frame >= anim.frameCount {aframe = frame % anim.frameCount}

	// Get first mesh which has bones
	firstMeshWithBones: i32 = -1
	for ii in 0 ..< model.meshCount {
		if model.meshes[ii].boneMatrices != nil {
			if firstMeshWithBones == -1 {
				firstMeshWithBones = ii
				break
			}
		}
	}

	// Update all bones and boneMatrices of first mesh with bones
	for boneId in 0 ..< anim.boneCount {
		// The important part is maintaining the exact same transformation order as the C code
		inTranslation := model.bindPose[boneId].translation
		inRotation := model.bindPose[boneId].rotation
		inScale := model.bindPose[boneId].scale

		outTranslation := anim.framePoses[aframe][boneId].translation
		outRotation := anim.framePoses[aframe][boneId].rotation
		outScale := anim.framePoses[aframe][boneId].scale

		invRotation := 1 / inRotation
		invTranslation := rl.Vector3RotateByQuaternion(-inTranslation, invRotation)
		invScale := vec3{1, 1, 1} / inScale

		// Keep the exact same calculation order as the C code
		boneTranslation :=
			rl.Vector3RotateByQuaternion(outScale * invTranslation, outRotation) + outTranslation
		boneRotation := outRotation * invRotation
		boneScale := outScale * invScale

		// The matrix multiplication order is critical - matching C exactly
		boneMatrix :=
			(rl.QuaternionToMatrix(boneRotation) *
				rl.MatrixTranslate(boneTranslation.x, boneTranslation.y, boneTranslation.z)) *
			rl.MatrixScale(boneScale.x, boneScale.y, boneScale.z)

		model.meshes[firstMeshWithBones].boneMatrices[boneId] = boneMatrix
	}

	if firstMeshWithBones != -1 {
		// Update remaining meshes with bones
		for i := firstMeshWithBones + 1; i < model.meshCount; i += 1 {
			if model.meshes[i].boneMatrices != nil {
				size := model.meshes[i].boneCount * size_of(model.meshes[i].boneMatrices[0])
				intrinsics.mem_copy(
					model.meshes[i].boneMatrices,
					model.meshes[firstMeshWithBones].boneMatrices,
					size,
				)
			}
		}
	}
}

// Coppied from randy
// Easing funcs: https://easings.net/
animateToTargetf32 :: proc(
	value: ^f32,
	target: f32,
	delta_t: f32,
	rate: f32 = 15.0,
	good_enough: f32 = 0.001,
) -> bool {
	value^ += (target - value^) * (1.0 - math.pow_f32(2.0, -rate * delta_t))
	if almostEquals(value^, target, good_enough) {
		value^ = target
		return true // reached
	}
	return false
}

almostEquals :: proc(a: f32, b: f32, epsilon: f32 = 0.001) -> bool {
	return abs(a - b) <= epsilon
}

// animate_to_target_v2 :: proc(
// 	value: ^Vector2,
// 	target: Vector2,
// 	delta_t: f32,
// 	rate: f32 = 15.0,
// 	good_enough: f32 = 0.001,
// ) {
// 	animate_to_target_f32(&value.x, target.x, delta_t, rate, good_enough)
// 	animate_to_target_f32(&value.y, target.y, delta_t, rate, good_enough)
// }

normalize :: proc(vec: vec3) -> vec3 {
	// You can't normalize an empty vector 
	if vec == {} {return {}}

	return linalg.normalize(vec)
}

loadModel :: proc(path: cstring) -> rl.Model {
	// Make sure it's a valid path.  
	// Only glb, obj, m3d work.
	//     No FBX.
	model := rl.LoadModel(path)
	assert(model.meshCount != 0, "Invalid Mesh")
	return model
}

loadModelAnimations :: proc(path: cstring) -> AnimationSet {
	anim := AnimationSet{}
	anim.anims = rl.LoadModelAnimations(path, &anim.total)
	assert(anim.total != 0, "No Anim")

	fmt.println(anim.anims)
	for ii in 0 ..< anim.total {
		animation := anim.anims[ii]
		fmt.printfln(
			"%d %s %d Frames %d",
			ii,
			animation.name,
			animation.boneCount,
			animation.frameCount,
		)
		// Print Bones
		for iii in 0 ..< animation.boneCount {
			fmt.printf("%s %d\n", animation.bones[iii].name, animation.bones[iii].parent)
		}
	}
	return anim
}

loadTexture :: proc(path: cstring) -> rl.Texture2D {
	texture := rl.LoadTexture(path)

	assert(rl.IsTextureValid(texture), fmt.tprint(path))
	assert(rl.IsTextureReady(texture), fmt.tprint(path))
	return texture
}
