package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

debugInit :: proc(game: ^Game) {

}

debugUpdateGame :: proc(game: ^Game) {
	using game

}

debugDrawGame :: proc(game: ^Game) {
	using game
	// drawFlipbook(camera^, fire^, {5, 1.5, 0}, 3)

}
