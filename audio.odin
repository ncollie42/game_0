package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"


// @(private = "file")
grunt := struct {
	sounds: [3]rl.Sound,
	CD:     Timer,
} {
	CD = Timer{max = .75},
}

whoosh := struct {
	sounds: [3]rl.Sound,
}{}

punch := struct {
	sounds: [2]rl.Sound,
}{}

loadSound :: proc(path: cstring) -> rl.Sound {
	sound := rl.LoadSound(path)

	assert(rl.IsSoundValid(sound), "not valid sound")
	return sound
}

initAudio :: proc() {
	rl.InitAudioDevice()
	rl.SetMasterVolume(.2)

	grunts := []cstring {
		"resources/audio/grunt_01.wav",
		"resources/audio/grunt_02.wav",
		"resources/audio/jump_03.wav",
	}
	for path, ii in grunts {
		grunt.sounds[ii] = loadSound(path)
	}

	punchs := []cstring{"resources/audio/Punch_1.wav", "resources/audio/Punch_2.wav"}
	for path, ii in punchs {
		punch.sounds[ii] = loadSound(path)
	}

	whooshs := []cstring {
		"resources/audio/Axe_Whoosh_01.wav",
		"resources/audio/Axe_Whoosh_02.wav",
		"resources/audio/Axe_Whoosh_03.wav",
	}
	for path, ii in whooshs {
		whoosh.sounds[ii] = loadSound(path)
	}
}

updateAudio :: proc() {
	updateTimer(&grunt.CD)
}

playSoundPunch :: proc() {
	sound := rand.choice(punch.sounds[:])
	playSound(sound)
}

playSoundPiched :: proc(sound: rl.Sound) {
	// if rl.IsSoundPlaying(sound) do return // Sound have a lot of dead sound at the end

	pitchMin: f32 = .8
	pitchMax: f32 = 1.2
	pitch := rand.float32_range(pitchMin, pitchMax)
	rl.SetSoundPitch(sound, pitch)
	playSound(sound)
}

playSound :: proc(sound: rl.Sound) {
	assert(rl.IsSoundValid(sound), "invalide sound tried to be played")

	rl.PlaySound(sound)
}


// Mele Attack Sound 1
playSoundWhoosh :: proc() {
	sound := rand.choice(whoosh.sounds[:])
	playSoundPiched(sound)

	playSoundGrunt()
}

playSoundGrunt :: proc() {
	if !isTimerReady(grunt.CD) {return}

	fmt.println("Grunting")
	sound := rand.choice(grunt.sounds[:])
	playSound(sound)
	startTimer(&grunt.CD)
}

// Play footsteps?
// var stepvalue = sin(0.01 * Time.get_ticks_msec())
// if vector and stepvalue is > < +-.8
// 	play random
