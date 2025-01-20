package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
// Stores all animations for the asset pack
PLAYER :: enum {
	run,
	punch2,
	punch1,
	roll,
	idle,
}

// enum is 1 shifted down from what they are in the file
SKELE :: enum {
	idle,
	hurt,
	run,
	attack,
}

ANIMATION_NAMES :: union {
	PLAYER,
	SKELE,
}

// Animations
ANIMATION_FRAME_RATE :: 60 // 60 feels good, but actually be 25 or 30

AnimationState :: struct {
	finished: bool, // Signal :: Animation just finished
	current:  ANIMATION_NAMES, //current anim
	frame:    f32, //active animation frame
	speed:    f32,
}

// We can share this struct for models using the same animations {Adventueres | skeletons}
AnimationSet :: struct {
	total: i32, //total animations
	anims: [^]rl.ModelAnimation,
}

// https://www.youtube.com/live/-LPHV452k1Y?si=JLSJ31LMlaPsKLO0&t=3794
// How to make own function for blending animations
updateAnimation :: proc(model: rl.Model, state: ^AnimationState, set: AnimationSet) {
	assert(set.total != 0, "empty set")
	assert(
		state.speed != 0,
		fmt.tprint("Animation speed is Zero, do we want that?", model, state^, set),
	)
	frame := i32(math.floor(state.frame))

	current: i32
	switch v in state.current {
	case PLAYER:
		current = i32(v)
	case SKELE:
		current = i32(v)
	}

	anim := set.anims[current]
	rl.UpdateModelAnimation(model, anim, frame)

	state.frame += getDelta() * ANIMATION_FRAME_RATE * state.speed
	frame = i32(math.floor(state.frame))

	// Will be set for a single frame until reset next turn.
	state.finished = false
	if frame >= anim.frameCount {
		state.finished = true
	}

	state.frame = rl.Wrap(state.frame, 0, f32(anim.frameCount))
}

getAnimationProgress :: proc(state: AnimationState, set: AnimationSet) -> f32 {
	current: i32
	switch v in state.current {
	case PLAYER:
		current: i32 = i32(v)
	case SKELE:
		current = i32(v)
	}

	return state.frame / f32(set.anims[current].frameCount)
}
