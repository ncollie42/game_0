package main

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"

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

Hand :: [HandAction]AbilityConfig // Not using all actions, just the ones in hand

HandAction :: enum {
	Nil,
	Attack, // Basic
	Power, // Nuke
	Special, // CC / AOE
	// Defence, //
	Ult,
}

ActionNames :: enum {
	Nil,
	One,
	Two,
	Three,
	Four,
	Dash,
	Block,
	Forward,
	Backward,
	Right,
	Left,
	Pause,
}

// Basic mele, x, x, defensive
bindings := [ActionNames]KeyBinding {
	.Nil      = nil,
	.One      = rl.MouseButton.LEFT, // Mele
	.Two      = rl.KeyboardKey.Q,
	.Three    = rl.KeyboardKey.E,
	.Four     = rl.KeyboardKey.R,
	.Dash     = rl.KeyboardKey.SPACE,
	.Block    = rl.MouseButton.RIGHT,
	.Forward  = rl.KeyboardKey.W,
	.Backward = rl.KeyboardKey.S,
	.Right    = rl.KeyboardKey.D,
	.Left     = rl.KeyboardKey.A,
	.Pause    = rl.KeyboardKey.ESCAPE,
}

isActionPressed :: proc(action: ActionNames) -> bool {
	binding := bindings[action]
	switch key in binding {
	case rl.MouseButton:
		if rl.IsMouseButtonPressed(key) {
			return true
		}
	case rl.KeyboardKey:
		if rl.IsKeyPressed(key) {
			return true
		}
	}
	return false
}

isActionDown :: proc(action: ActionNames) -> bool {
	binding := bindings[action]
	switch key in binding {
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
}

tickTimer :: proc(tick: ^Timer) -> bool {
	if isTimerReady(tick^) {
		startTimer(tick)
		return true
	}
	updateTimer(tick)
	return false
}

timerPercent :: proc(tt: Timer) -> f32 {
	return tt.left / tt.max
}

updateTimer :: proc(timer: ^Timer) {
	timer.left -= getDelta()
	timer.left = clamp(timer.left, 0, timer.max)
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
distance_to :: proc(a: vec3, b: vec3) -> f32 {
	return linalg.length(a - b)
}

normalize :: proc(vec: vec3) -> vec3 {
	// You can't normalize an empty vector 
	if vec == {} {return {}}

	return linalg.normalize(vec)
}

loadModel :: proc(path: cstring) -> rl.Model {
	assert(rl.IsPathFile(path))
	assert(
		!strings.has_suffix(string(path), ".fbx"),
		fmt.tprint("[loadModel] does not support FBX files :", path),
	)
	// Make sure it's a valid path.  
	// Only glb, obj, m3d work.
	//     No FBX.
	model := rl.LoadModel(path)
	// fmt.println(path, model.boneCount)
	assert(model.meshCount != 0, fmt.tprintf("[loadModel] Invalid Mesh %s", path))
	return model
}

loadModelAnimations :: proc(path: cstring) -> AnimationSet {
	anim := AnimationSet{}
	anim.anims = rl.LoadModelAnimations(path, &anim.total)
	assert(anim.total != 0, "No Anim")

	return anim
}


loadTexture :: proc(path: cstring) -> rl.Texture2D {
	texture := rl.LoadTexture(path)

	assert(rl.IsTextureValid(texture), fmt.tprint("[loadTexture]", path))
	assert(rl.IsTextureReady(texture), fmt.tprint("[loadTexture]", path))
	return texture
}

loadModelWithTexture :: proc(modelPath: cstring, texturePath: cstring) -> rl.Model {
	model := loadModel(modelPath)
	texture := loadTexture(texturePath)

	count := model.materialCount - 1
	model.materials[count].maps[rl.MaterialMapIndex.ALBEDO].texture = texture

	return model
}

drawShadow :: proc(model: rl.Model, spacial: Spacial, scale: f32, camera: ^rl.Camera) {
	count := model.materialCount - 1
	prevShader := model.materials[count].shader
	modelMatrix := getSpacialMatrix(spacial, scale)

	// TODO: pull out and save into shadow.locs ?
	// Shaderloc :: enum {
	// 	modelMatrix,
	// 	projectionMatrix,
	// 	viewMatrix,
	// }
	l1 := rl.GetShaderLocation(Shaders[.Shadow], "modelMatrix")
	l2 := rl.GetShaderLocation(Shaders[.Shadow], "viewMatrix") // Camera
	l3 := rl.GetShaderLocation(Shaders[.Shadow], "projectionMatrix")

	rl.SetShaderValueMatrix(Shaders[.Shadow], l1, modelMatrix)
	rl.SetShaderValueMatrix(Shaders[.Shadow], l2, rl.GetCameraViewMatrix(camera))
	// NOTE: we can optimize later, these don't change often. can move out to a global?
	aspect := f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight())
	rl.SetShaderValueMatrix(Shaders[.Shadow], l3, rl.GetCameraProjectionMatrix(camera, aspect))

	model.materials[count].shader = Shaders[.Shadow]
	rl.DrawModel(model, spacial.pos, scale, rl.WHITE)
	model.materials[count].shader = prevShader
}

drawOutline :: proc(
	model: rl.Model,
	spacial: Spacial,
	scale: f32,
	camera: ^rl.Camera,
	color: vec4,
) {
	count := model.materialCount - 1
	prevShader := model.materials[count].shader
	modelMatrix := getSpacialMatrix(spacial, scale)

	l1 := rl.GetShaderLocation(Shaders[.Hull], "model")
	l2 := rl.GetShaderLocation(Shaders[.Hull], "view") // Camera
	l3 := rl.GetShaderLocation(Shaders[.Hull], "projection")
	l4 := rl.GetShaderLocation(Shaders[.Hull], "outlineColor")

	rl.SetShaderValueMatrix(Shaders[.Hull], l1, modelMatrix)
	rl.SetShaderValueMatrix(Shaders[.Hull], l2, rl.GetCameraViewMatrix(camera))
	// NOTE: we can optimize later, these don't change often. can move out to a global?
	aspect := f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight())
	rl.SetShaderValueMatrix(Shaders[.Hull], l3, rl.GetCameraProjectionMatrix(camera, aspect))

	c := color
	rl.SetShaderValue(Shaders[.Hull], l4, &c, .VEC4)

	gl.SetCullFace(.FRONT)
	model.materials[count].shader = Shaders[.Hull]
	rl.DrawModel(model, spacial.pos, scale, rl.WHITE)
	model.materials[count].shader = prevShader
	gl.SetCullFace(.BACK)
}


// -------------------- Tiling
// rl.SetTextureWrap(text, .REPEAT)
// tileScaleLocation := rl.GetShaderLocation(Shaders[.Tiling], "tileScale")
// tileScale := f32(10.0)
// rl.SetShaderValue(Shaders[.Tiling], tileScaleLocation, &tileScale, .FLOAT)
