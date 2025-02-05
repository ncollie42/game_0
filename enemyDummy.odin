package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

dummyEnemy :: struct {
	state: union {
		EnemyStateIdle,
		EnemyPushback,
		EnemyStateRunning,
	},
}
EnemyStateRunning :: struct {}
EnemyStateIdle :: struct {}

ATTACK_RANGE_DUMMY :: (2 - .2) // Attack range == ability spawn point + radius, 1 unit away w/ 1 unit radius == 2 - some distance to hit
updateEnemyDummy :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyDummyPool,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	dummy := &enemy.type.(dummyEnemy) or_else panic("Invalid enemy type")
	switch &s in dummy.state {
	case EnemyStateRunning:
		if linalg.distance(enemy.pos, player.pos) > ATTACK_RANGE_DUMMY {return}

		enterEnemyDummyState(enemy, EnemyStateIdle{})
	case EnemyStateIdle:
		// Face player :: 
		target := normalize(player.pos - enemy.pos)
		r := lookAtVec3(target, {})
		enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * ENEMY_TURN_SPEED)
	case EnemyPushback:
		dir := getBackwardPoint(enemy)
		enemy.spacial.pos += dir * getDelta() * PUSH_BACK_SPEED

		if enemy.animState.finished {
			enterEnemyDummyState(enemy, EnemyStateIdle{})
		}
	case:
		enterEnemyDummyState(enemy, EnemyStateIdle{})
	}
}

enterEnemyDummyState :: proc(enemy: ^Enemy, state: union {
		EnemyStateIdle,
		EnemyPushback,
		EnemyStateRunning,
	}) {
	enemy.animState.duration = 0
	enemy.animState.speed = 1

	dummy := &enemy.type.(dummyEnemy) or_else panic("Invalid enemy type")
	dummy.state = state

	switch &s in dummy.state {
	case EnemyStateRunning:
		enemy.animState.current = SKELE.run
	case EnemyStateIdle:
		enemy.animState.current = SKELE.idle
	case EnemyPushback:
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
	}
}
