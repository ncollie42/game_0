package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

GiantEnemy :: struct {
	state: union {
		EnemyStateIdle,
		EnemyStateRunning,
		EnemyPushback,
		EnemyAttack,
	},
}

updateEnemyGiant :: proc(
	enemy: ^Enemy,
	player: Player,
	enemies: ^EnemyPool,
	objs: ^[dynamic]EnvObj,
	pool: ^AbilityPool,
) {
	enemy.attackCD.left -= getDelta()
	canAttack := enemy.attackCD.left <= 0
	giant := &enemy.type.(GiantEnemy) // or else panic

	switch &s in giant.state {
	case EnemyStateRunning:
		speed := getRootMotionSpeed(&enemy.animState, enemies.animSetGiant, enemy.size)
		updateEnemyMovement(.PLAYER, enemy, player, enemies, objs, speed) // Boids
		if linalg.distance(enemy.pos, player.pos) > ATTACK_RANGE_MELE do return // TODO: replace with giant attack range

		enterEnemyGiantState(enemy, EnemyStateIdle{})
	case EnemyStateIdle:
		if linalg.distance(enemy.pos, player.pos) > ATTACK_RANGE_MELE {
			enterEnemyGiantState(enemy, EnemyStateRunning{})
			return
		}
		// Face player :: 
		target := normalize(player.pos - enemy.pos)
		r := lookAtVec3(target, {})
		enemy.spacial.rot = lerpRAD(enemy.spacial.rot, r, getDelta() * ENEMY_TURN_SPEED)

		inRange := linalg.distance(enemy.pos, player.pos) < ATTACK_RANGE_MELE
		toPlayer := normalize(player.pos - enemy.pos)
		forward := getForwardPoint(enemy)
		facing := linalg.dot(forward, toPlayer) >= ATTACK_FOV

		if inRange && canAttack && facing {
			CD_variant := rand.float32_range(0, ENEMY_CD_ATTACK_VARIANT)
			enemy.attackCD.left = enemy.attackCD.max + CD_variant // Start timer again
			enterEnemyGiantState(
				enemy,
				EnemyAttack{action_frame = 34, animation = ENEMY.attack, animSpeed = 1},
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
		// Move
		speed := getRootMotionSpeed(&enemy.animState, enemies.animSetGiant, 3)
		enemy.spacial.pos += directionFromRotation(enemy.rot) * getDelta() * speed

		frame := i32(math.floor(enemy.animState.duration * FPS_30))
		if enemy.animState.finished {
			enterEnemyGiantState(enemy, EnemyStateIdle{})
			return
		}


		if s.hasTriggered do return

		if frame >= s.action_frame {
			s.hasTriggered = true
			spawnInstanceFrontOfLocation(pool, enemy)
		}
	case EnemyPushback:
		dir := getBackwardPoint(enemy)
		// speed := getRootMotionSpeed(&enemy.animState, enemies.animSet, 3)
		enemy.spacial.pos += dir * getDelta() * PUSH_BACK_SPEED

		if enemy.animState.finished {
			enterEnemyGiantState(enemy, EnemyStateIdle{})
		}
	case:
		enterEnemyGiantState(enemy, EnemyStateIdle{})
	}
}

enterEnemyGiantState :: proc(enemy: ^Enemy, state: union {
		EnemyStateIdle,
		EnemyStateRunning,
		EnemyPushback,
		EnemyAttack,
	}) {

	giant := &enemy.type.(GiantEnemy) or_else panic("Invalid enemy type")

	switch &s in state {
	case EnemyStateRunning:
		transitionAnimBlend(&enemy.animState, ENEMY.run)
		enemy.animState.speed = 1
		giant.state = state
	case EnemyStateIdle:
		enemy.animState.current = ENEMY.idle
		enemy.animState.speed = 1
		giant.state = state
	case EnemyPushback:
		// Don't interrupt if attacking
		_, isAttacking := giant.state.(EnemyAttack)
		if isAttacking do return

		giant.state = state
		enemy.animState.duration = 0
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
	case EnemyAttack:
		enemy.animState.duration = 0
		enemy.animState.speed = s.animSpeed
		enemy.animState.current = s.animation
		giant.state = state
		spawnWarning(enemy.pos + {0, 3, 0})
	}
}
