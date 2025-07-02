package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

ThornEnemy :: struct {}

updateEnemyThorn :: proc(enemy: ^Enemy, pool: ^AbilityPool) {
	updateTimer(&enemy.attackCD)
	canAttack := isTimerReady(enemy.attackCD)
	// canAttack := enemy.attackCD.left <= 0
	thorn := &enemy.type.(ThornEnemy) // or else panic

	if !canAttack {
		return
	}
	startTimer(&enemy.attackCD)

	// Spawn damage
	ability := newMeleInstance(enemy.pos, 1, 0)
	append(&pool.active, ability)
}
