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
hitStopScale: f32 = 1

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
		hitStopScale = rl.Remap(amount, 1, 0, .05, 1)
		hitStopScale = clamp(hitStopScale, .05, 1) // Prevent over shoot on the last tick, progress > 100%

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
		hitStopScale = rl.Remap(amount, 1, 0, 1, .05)
		hitStopScale = clamp(hitStopScale, .05, 1) // Prevent over shoot on the last tick, progress > 100%

		if hitStop.duration > 0 {return}

		hitStop.state = .waiting
	case:
		hitStop.state = .waiting
	}
	assert(hitStopScale > 0, "hitStopScale can't be negative! Goofed up somewhere")
}

getDelta :: proc() -> f32 {
	// Dont use this delta for env visuals IE: particles.
	// timeScale is for engine global time.
	// hitstop is used for attacks
	return rl.GetFrameTime() * timeScale * hitStopScale
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
