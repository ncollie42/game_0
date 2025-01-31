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
	longPunch,
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

// Export maximo at 30 fps -> blender at 60 -> render FPS at 30 here
FPS_30 :: 30

AnimationState :: struct {
	duration: f32,
	finished: bool, // Signal :: Animation just finished
	current:  ANIMATION_NAMES, //current anim
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
	frame := i32(math.floor(state.duration * FPS_30))

	current: i32
	switch v in state.current {
	case PLAYER:
		current = i32(v)
	case SKELE:
		current = i32(v)
	}

	anim := set.anims[current]
	rl.UpdateModelAnimation(model, anim, frame)

	state.duration += getDelta() * state.speed
	// fmt.printfln("%.1f frame:%d total:%d", state.duration, frame, anim.frameCount)

	// Will be set for a single frame until reset next turn.
	state.finished = false
	if frame >= anim.frameCount {
		state.finished = true
		state.duration = 0
	}
}

getAnimationProgress :: proc(state: AnimationState, set: AnimationSet) -> f32 {
	current: i32
	switch v in state.current {
	case PLAYER:
		current: i32 = i32(v)
	case SKELE:
		current = i32(v)
	}

	frame := i32(math.floor(state.duration * FPS_30))
	anim := set.anims[current]
	return f32(frame) / f32(anim.frameCount)
}
