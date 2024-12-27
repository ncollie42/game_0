package main

import "core:fmt"
import rl "vendor:raylib"


Health :: struct {
	max:     f32,
	current: f32,
	showing: f32,
}


updateHitCollisions :: proc(enemies: ^EnemyDummyPool)
