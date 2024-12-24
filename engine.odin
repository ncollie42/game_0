package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
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

ANIMATION_FRAME_RATE :: 60 // 60 feels good, but actually be 25 or 30

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

	animation.frame += getDelta() * ANIMATION_FRAME_RATE
	frame = i32(math.floor(animation.frame))

	// Will be set for a single frame until reset next turn.
	animation.finished = false
	if frame == anim.frameCount {
		animation.finished = true
	}

	animation.frame = rl.Wrap(animation.frame, 0, f32(anim.frameCount))
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
	rad := rl.Lerp(current, current + delta, amount * rl.GetFrameTime())
	return rl.Wrap(rad, -rl.PI, rl.PI)
}
