package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

meleEnemy :: struct {
	state: union {
		EnemyStateIdle,
		EnemyStateRunning,
		EnemyPushback,
		EnemyAttack1,
	},
}

updateEnemyMele :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyDummyPool,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	enemy.attackCD.left -= getDelta()
	mele := &enemy.type.(meleEnemy) // or else panic

	switch &s in mele.state {
	case EnemyStateRunning:
		updateEnemyMovement(.PLAYER, enemy, player, enemies, objs) // Boids
		if linalg.distance(enemy.pos, player.pos) > ATTACK_RANGE_MELE {return}

		enterEnemyMeleState(enemy, EnemyStateIdle{})
	case EnemyStateIdle:
		if linalg.distance(enemy.pos, player.pos) > ATTACK_RANGE_MELE {
			enterEnemyMeleState(enemy, EnemyStateRunning{})
			return
		}
		// Face player :: 
		target := normalize(player.pos - enemy.pos)
		r := lookAtVec3(target, {})
		enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * ENEMY_TURN_SPEED)

		inRange := linalg.distance(enemy.pos, player.pos) < ATTACK_RANGE_MELE
		canAttack := enemy.attackCD.left <= 0
		toPlayer := normalize(player.pos - enemy.pos)
		forward := getForwardPoint(enemy)
		facing := linalg.dot(forward, toPlayer) >= ATTACK_FOV

		if inRange && canAttack && facing {
			enemy.attackCD.left = enemy.attackCD.max // Start timer again
			enterEnemyMeleState(
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
			enterEnemyMeleState(enemy, EnemyStateIdle{})
			return
		}

		if s.hasTriggered do return

		if s.duration <= s.trigger {
			s.hasTriggered = true
			spawnInstanceFrontOfLocation(pool, enemy)
		}
	case EnemyPushback:
		dir := getBackwardPoint(enemy)
		enemy.spacial.pos += dir * getDelta() * PUSH_BACK_SPEED

		if enemy.animState.finished {
			enterEnemyMeleState(enemy, EnemyStateIdle{})
		}
	case:
		enterEnemyMeleState(enemy, EnemyStateIdle{})
	}
}

enterEnemyMeleState :: proc(enemy: ^Enemy, state: union {
		EnemyStateIdle,
		EnemyStateRunning,
		EnemyPushback,
		EnemyAttack1,
	}) {
	enemy.animState.duration = 0
	enemy.animState.speed = 1

	mele := &enemy.type.(meleEnemy) or_else panic("Invalid enemy type")
	mele.state = state

	switch &s in mele.state {
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
