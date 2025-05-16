package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

MonolithEnemy :: struct {}

updateEnemyMonolith :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyPool,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	thorn := &enemy.type.(MonolithEnemy) // or else panic
	// Does nothing for now, just blocks space
}
