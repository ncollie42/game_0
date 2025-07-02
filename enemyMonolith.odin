package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

MonolithEnemy :: struct {}

updateEnemyMonolith :: proc(enemy: ^Enemy) {
	monolith := &enemy.type.(MonolithEnemy) // or else panic
	// Does nothing for now, just blocks space
}
