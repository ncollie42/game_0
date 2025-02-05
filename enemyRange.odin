package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

rangeEnemy :: struct {
	state: union {
		EnemyStateIdle,
		EnemyStateRunning,
		EnemyPushback,
		EnemyAttack1,
	},
}

ATTACK_RANGE_RANGE :: 7
updateEnemyRange :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyDummyPool,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	enemy.attackCD.left -= getDelta()
	range := &enemy.type.(rangeEnemy) or_else panic("Not the type we want here")

	switch &s in range.state {
	case EnemyStateRunning:
		updateEnemyMovement(.PLAYER, enemy, player, enemies, objs) // Boids
		if linalg.distance(enemy.pos, player.pos) > ATTACK_RANGE_RANGE {return}

		enterEnemyRangeState(enemy, EnemyStateIdle{})
	case EnemyStateIdle:
		if linalg.distance(enemy.pos, player.pos) > ATTACK_RANGE_RANGE {
			enterEnemyRangeState(enemy, EnemyStateRunning{})
			return
		}
		// Face player :: 
		target := normalize(player.pos - enemy.pos)
		r := lookAtVec3(target, {})
		enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * ENEMY_TURN_SPEED)

		inRange := linalg.distance(enemy.pos, player.pos) < ATTACK_RANGE_RANGE
		canAttack := enemy.attackCD.left <= 0
		toPlayer := normalize(player.pos - enemy.pos)
		forward := getForwardPoint(enemy)
		facing := linalg.dot(forward, toPlayer) >= ATTACK_FOV

		if inRange && canAttack && facing {
			enemy.attackCD.left = enemy.attackCD.max // Start timer again
			enterEnemyRangeState(
				enemy,
				EnemyAttack1{duration = 1, trigger = .3, animation = SKELE.attack, animSpeed = 1},
			)
		}

	// TODO: Add extra states? Going to location ; fighting ; upclose to something ; ext
	// When next to player, it's weird 

	// updateDummyMovement(enemy, player, enemies, objs) // Boids
	// enemy.animation.current = .WALKING_B

	// if in range of player attack? Idle animation and running animation
	case EnemyAttack1:
		s.duration -= getDelta()
		if s.duration <= 0 {
			enterEnemyRangeState(enemy, EnemyStateIdle{})
			return
		}

		if s.hasTriggered do return

		if s.duration <= s.trigger {
			s.hasTriggered = true
			spawnRangeInstanceFrontOfLocation(pool, enemy)
		}
	case EnemyPushback:
		dir := getBackwardPoint(enemy)
		enemy.spacial.pos += dir * getDelta() * PUSH_BACK_SPEED

		if enemy.animState.finished {
			enterEnemyRangeState(enemy, EnemyStateIdle{})
		}
	case:
		enterEnemyRangeState(enemy, EnemyStateIdle{})
	}
}

enterEnemyRangeState :: proc(enemy: ^Enemy, state: union {
		EnemyStateIdle,
		EnemyStateRunning,
		EnemyPushback,
		EnemyAttack1,
	}) {
	enemy.animState.duration = 0
	enemy.animState.speed = 1

	range := &enemy.type.(rangeEnemy) or_else panic("Invalid enemy type")
	range.state = state

	switch &s in range.state {
	case EnemyStateRunning:
		enemy.animState.current = SKELE.run
	case EnemyStateIdle:
		enemy.animState.current = SKELE.idle
	case EnemyPushback:
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
	case EnemyAttack1:
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
	}
}
