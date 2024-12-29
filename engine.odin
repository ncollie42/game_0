package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// https://bztsrc.gitlab.io/model3d/viewer/

// vec2 type
vec2 :: [2]f32
// vec3 type
vec3 :: [3]f32
// vec4 type
vec4 :: [4]f32

UP :: vec3{0, 1, 0}

// Delta
timeScale: f32 = 1.0

getDelta :: proc() -> f32 {
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

// Animations

ANIMATION_FRAME_RATE :: 90 // 60 feels good, but actually be 25 or 30

// Stores all animations for the asset pack
ANIMATION: Animations = {}

ANIMATION_NAME :: enum {
	H1_MELEE_ATTACK_CHOP             = 0,
	H1_MELEE_ATTACK_SLICE_DIAGONAL   = 1,
	H1_MELEE_ATTACK_SLICE_HORIZONTAL = 2,
	H1_MELEE_ATTACK_STAB             = 3,
	H1_RANGED_AIMING                 = 4,
	H1_RANGED_RELOAD                 = 5,
	H1_RANGED_SHOOT                  = 6,
	H1_RANGED_SHOOTING               = 7,
	H2_MELEE_ATTACK_CHOP             = 8,
	H2_MELEE_ATTACK_SLICE            = 9,
	H2_MELEE_ATTACK_SPIN             = 10,
	H2_MELEE_ATTACK_SPINNING         = 11,
	H2_MELEE_ATTACK_STAB             = 12,
	H2_MELEE_IDLE                    = 13,
	H2_RANGED_AIMING                 = 14,
	H2_RANGED_RELOAD                 = 15,
	H2_RANGED_SHOOT                  = 16,
	H2_RANGED_SHOOTING               = 17,
	BLOCK                            = 18,
	BLOCK_ATTACK                     = 19,
	BLOCK_HIT                        = 20,
	BLOCKING                         = 21,
	CHEER                            = 22,
	DEATH_A                          = 23,
	DEATH_B                          = 24,
	DODGE_BACKWARD                   = 25,
	DODGE_FORWARD                    = 26,
	DODGE_LEFT                       = 27,
	DODGE_RIGHT                      = 28,
	DUALWIELD_MELEE_ATTACK_CHOP      = 29,
	DUALWIELD_MELEE_ATTACK_SLICE     = 30,
	DUALWIELD_MELEE_ATTACK_STAB      = 31,
	HIT_A                            = 32,
	HIT_B                            = 33,
	IDLE                             = 34,
	INTERACT                         = 35,
	JUMP_FULL_LONG                   = 36,
	JUMP_FULL_SHORT                  = 37,
	JUMP_IDLE                        = 38,
	JUMP_LAND                        = 39,
	JUMP_START                       = 40,
	LIE_DOWN                         = 41,
	LIE_IDLE                         = 42,
	LIE_STANDUP                      = 43,
	PICKUP                           = 44,
	RUNNING_A                        = 45,
	RUNNING_B                        = 46,
	RUNNING_STRAFE_LEFT              = 47,
	RUNNING_STRAFE_RIGHT             = 48,
	SIT_CHAIR_DOWN                   = 49,
	SIT_CHAIR_IDLE                   = 50,
	SIT_CHAIR_STANDUP                = 51,
	SIT_FLOOR_DOWN                   = 52,
	SIT_FLOOR_IDLE                   = 53,
	SIT_FLOOR_STANDUP                = 54,
	SPELLCAST_LONG                   = 55,
	SPELLCAST_RAISE                  = 56,
	SPELLCAST_SHOOT                  = 57,
	SPELLCASTING                     = 58,
	THROW                            = 59,
	UNARMED_IDLE                     = 60,
	UNARMED_MELEE_ATTACK_KICK        = 61,
	UNARMED_MELEE_ATTACK_PUNCH_A     = 62,
	UNARMED_MELEE_ATTACK_PUNCH_B     = 63,
	USE_ITEM                         = 64,
	WALKING_A                        = 65,
	WALKING_B                        = 66,
	WALKING_BACKWARDS                = 67,
	WALKING_C                        = 68,
}

Animation :: struct {
	finished: bool, // Signal :: Animation just finished
	current:  ANIMATION_NAME, //current anim
	frame:    f32, //active animation frame
	speed:    f32,
}

// We can share this struct for models using the same animations {Adventueres | skeletons}
Animations :: struct {
	total: i32, //total animations
	anims: [^]rl.ModelAnimation,
}

// https://www.youtube.com/live/-LPHV452k1Y?si=JLSJ31LMlaPsKLO0&t=3794
// How to make own function for blending animations
updateAnimation :: proc(model: rl.Model, animation: ^Animation, animations: Animations) {
	frame := i32(math.floor(animation.frame))
	anim := animations.anims[animation.current]

	rl.UpdateModelAnimation(model, anim, frame)

	animation.frame += getDelta() * ANIMATION_FRAME_RATE * animation.speed
	frame = i32(math.floor(animation.frame))

	// Will be set for a single frame until reset next turn.
	animation.finished = false
	if frame >= anim.frameCount {
		animation.finished = true
	}

	animation.frame = rl.Wrap(animation.frame, 0, f32(anim.frameCount))
}

getAnimationProgress :: proc(animation: Animation, animations: Animations) -> f32 {
	return animation.frame / f32(animations.anims[animation.current].frameCount)
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
}


// -------------------------------------------
// Odin version of update model animation, using to later try and blend between 2 animations
updateModelAnimation :: proc(model: rl.Model, anim: rl.ModelAnimation, frame: i32) {
	// Update bones
	rl.UpdateModelAnimationBones(model, anim, frame)
	// Update the mesh using the bones.
	for m in 0 ..< model.meshCount {
		mesh := model.meshes[m]
		animVertex := vec3{}
		animNormal := vec3{}
		boneId: u8 = 0
		boneCounter := 0
		boneWeight: f32 = 0.0
		updated := false
		vValues := mesh.vertexCount * 3

		// Skip if missing bone data, causes segfault without on some models
		if mesh.boneWeights == nil || mesh.boneIds == nil do continue
		for vCounter: i32 = 0; vCounter < vValues; vCounter += 3 {
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
				boneCounter += 1 // Should this be here or above the 2 lines?

				// Early stop when no transformation will be applied
				if boneWeight == 0 {
					continue
				}

				animVertex = vec3 {
					mesh.vertices[vCounter],
					mesh.vertices[vCounter + 1],
					mesh.vertices[vCounter + 2],
				}
				animVertex = rl.Vector3Transform(animVertex, model.meshes[m].boneMatrices[boneId])
				mesh.animVertices[vCounter] += animVertex.x * boneWeight
				mesh.animVertices[vCounter + 1] += animVertex.y * boneWeight
				mesh.animVertices[vCounter + 2] += animVertex.z * boneWeight
				updated = true

				// Normals processing
				// NOTE: We use meshes.base_normals (default normal) to calculate meshes.normals (animated normals)
				if mesh.normals != nil && mesh.animNormals != nil {
					animNormal = vec3 {
						mesh.normals[vCounter],
						mesh.normals[vCounter + 1],
						mesh.normals[vCounter + 2],
					}

					// Matrix symbol is taken
					matrixx := rl.MatrixTranspose(
						rl.MatrixInvert(model.meshes[m].boneMatrices[boneId]),
					)
					animNormal = rl.Vector3Transform(animNormal, matrixx)

					mesh.animNormals[vCounter] += animNormal.x * boneWeight
					mesh.animNormals[vCounter + 1] += animNormal.y * boneWeight
					mesh.animNormals[vCounter + 2] += animNormal.z * boneWeight
				}
			}
		}

		if updated {
			// Update vertex position
			rl.UpdateMeshBuffer(mesh, 0, mesh.animVertices, mesh.vertexCount * 3 * size_of(f32), 0)

			// Update vertex normals
			if mesh.normals != nil {
				rl.UpdateMeshBuffer(
					mesh,
					2,
					mesh.animNormals,
					mesh.vertexCount * 3 * size_of(f32),
					0,
				)
			}
		}
	}
}

// Coppied from randy
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
