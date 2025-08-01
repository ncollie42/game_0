package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

RangeEnemy :: struct {
	state: union {
		EnemyStateIdle,
		EnemyStateRunning,
		EnemyPushback,
		EnemyAttack,
	},
}

ATTACK_RANGE_RANGE :: 7
updateEnemyRange :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyPool,
	objs: ^[dynamic]EnvObj,
	gpoints: ^[dynamic]GravityPoint,
	pool: ^AbilityPool,
) {
	enemy.attackCD.left -= getDelta()
	range := &enemy.type.(RangeEnemy) or_else panic("Not the type we want here")

	switch &s in range.state {
	case EnemyStateRunning:
		speed := getRootMotionSpeed(&enemy.animState, enemies.animSetRange, enemy.size)
		updateEnemyMovement(.PLAYER, enemy, player, enemies, objs, speed, gpoints) // Boids
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
				// EnemyAttack{action_frame = 49, animation = ENEMY.attack, animSpeed = 1},
				EnemyAttack{action_frame = 12, animation = ENEMY.attack, animSpeed = 1},
			)
		}

	// TODO: Add extra states? Going to location ; fighting ; upclose to something ; ext
	// When next to player, it's weird 

	// updateDummyMovement(enemy, player, enemies, objs) // Boids
	// enemy.animation.current = .WALKING_B

	// if in range of player attack? Idle animation and running animation
	case EnemyAttack:
		// Face player :: 
		target := normalize(player.pos - enemy.pos)
		r := lookAtVec3(target, {})
		enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * ENEMY_TURN_SPEED)

		if enemy.animState.finished {
			enterEnemyRangeState(enemy, EnemyStateIdle{})
			return
		}

		frame := i32(math.floor(enemy.animState.duration * FPS_30))

		if s.hasTriggered do return

		if frame >= s.action_frame {
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
		EnemyAttack,
	}) {

	range := &enemy.type.(RangeEnemy) or_else panic("Invalid enemy type")

	switch &s in state {
	case EnemyStateRunning:
		transitionAnimBlend(&enemy.animState, ENEMY.run)
		enemy.animState.speed = 1
		range.state = state
	case EnemyStateIdle:
		enemy.animState.speed = 1
		enemy.animState.current = ENEMY.idle
		range.state = state
	case EnemyPushback:
		// Don't interrupt if attacking
		_, isAttacking := range.state.(EnemyAttack)
		if isAttacking do return

		range.state = state
		enemy.animState.duration = 0
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
	case EnemyAttack:
		enemy.animState.duration = 0
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
		range.state = state
		spawnWarning(enemy.pos + {0, 3, 0})
	}
}
