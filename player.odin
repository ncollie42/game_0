package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "vendor:raylib"

Player :: struct {
	lookAtMouse:   bool,
	model:         rl.Model,
	scale:         f32,
	animState:     AnimationState,
	animSet:       AnimationSet,
	using spacial: Spacial,
	using health:  Health,
	state:         State,
	trailLeft:     Flipbook,
	trailRight:    Flipbook,
	viewCircle:    rl.Model,
	attack:        Attack,
	//Test :: Collision
	point:         vec3,
	normal:        vec3,
	edge:          bool,
}

MOVE_SPEED :: 7
TURN_SPEED :: 10.0

newPlayer :: proc() -> ^Player {
	player := new(Player)

	modelPath: cstring = "resources/warrior/base.m3d"
	texturePath: cstring = "resources/warrior/base.png"

	player.model = loadModel(modelPath)
	player.animSet = loadM3DAnimationsWithRootMotion(modelPath)

	texture := loadTexture(texturePath)
	player.model.materials[player.model.materialCount - 1].maps[rl.MaterialMapIndex.ALBEDO].texture =
		texture

	player.model.materials[player.model.materialCount - 1].shader = Shaders[.Flash]

	path: cstring = "resources/trail_1.png"
	player.trailLeft = initFlipbookPool(path, 32, 32, 8)
	path = "resources/trail_2.png"
	player.trailRight = initFlipbookPool(path, 32, 32, 8)
	// path: cstring = "/home/nico/Downloads/smear.png"
	// player.trail = initFlipbookPool(path, 240 / 5, 48, 5)

	// Camera half circle :: TODO: maybe replace with a billboardPro on {0,0,1}
	mesh := rl.GenMeshPlane(1, 1, 1, 1)
	player.viewCircle = rl.LoadModelFromMesh(mesh)
	texturePath = "resources/half_circle.png"
	texture = rl.LoadTexture(texturePath)
	player.viewCircle.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
	player.viewCircle.materials[0].shader = Shaders[.Discard]

	initPlayer(player)
	return player
}

initPlayer :: proc(player: ^Player) {
	player.animState.speed = 1
	player.animState.current = PLAYER.idle

	player.health = Health {
		max     = 10,
		current = 10,
	}
	player.attack = Attack{5, 5}

	player.spacial = Spacial {
		rot   = 0,
		pos   = {},
		shape = .8, //radius
	}

	player.scale = 5
}

moveAndSlide :: proc(player: ^Player, velocity: vec3, objs: [dynamic]EnvObj, enemies: ^EnemyPool) {
	// Projected movement
	projected := player.spacial
	projected.pos += velocity * getDelta()
	for obj in objs {
		if checkCollision(obj, projected) {
			collision := getCollision(obj, projected)

			player.point = collision.point
			player.normal = collision.normal

			// if normal dot is > .7 // mostly facing the same way. sharp corners.
			if linalg.dot(collision.normal, velocity) > .7 {break}

			// Slide: Project velocity onto normal using dot product
			dot := linalg.dot(velocity, collision.normal)
			slide := velocity - (collision.normal * dot)

			player.spacial.pos += slide * getDelta()

			// If colliding after moving, set possition at the edge of object
			if checkCollision(obj, player.spacial) {
				player.spacial.pos =
					collision.point + collision.normal * (player.spacial.shape.(Sphere) * 1.05)
			}
			return
		}
	}

	mapCheck: {
		dist := linalg.distance(projected.pos, vec3{})
		diff := MapGround.shape.(Sphere) - player.spacial.shape.(Sphere)
		player.edge = dist > diff
		if dist > diff {
			// Trying to get out
			col := getCollision(MapGround, projected)
			col.normal *= -1 // point inward

			player.point = col.point
			player.normal = col.normal

			// TODO: maybe add in sliding?
			player.pos = col.point + col.normal * (player.spacial.shape.(Sphere) * 1.05)
			return
		}
	}


	// We COULD collect all collisions and do something off that. But this kinda feels good.
	for enemy in enemies.active {
		if checkCollision(enemy, projected) {
			collision := getCollision(enemy, projected)

			player.point = collision.point
			player.normal = collision.normal

			// if normal dot is > .7 // mostly facing the same way. sharp corners.
			if linalg.dot(collision.normal, velocity) > .7 {break}

			// Slide: Project velocity onto normal using dot product
			dot := linalg.dot(velocity, collision.normal)
			slide := velocity - (collision.normal * dot)

			player.spacial.pos += slide * getDelta()

			return
		}
	}

	player.spacial.pos += velocity * getDelta()
}

moveAndStop :: proc(player: ^Player, velocity: vec3, objs: [dynamic]EnvObj, enemies: ^EnemyPool) {

	// Projected movement
	projected := player.spacial
	projected.pos += velocity * getDelta()
	for obj in objs {
		if checkCollision(obj, projected) {
			return
		}
	}

	mapCheck: {
		dist := linalg.distance(projected.pos, vec3{})
		diff := MapGround.shape.(Sphere) - player.spacial.shape.(Sphere)
		player.edge = dist > diff
		if dist > diff {
			// Trying to get out
			col := getCollision(MapGround, projected)
			col.normal *= -1 // point inward

			player.point = col.point
			player.normal = col.normal

			// TODO: maybe add in sliding?
			player.pos = col.point + col.normal * (player.spacial.shape.(Sphere) * 1.05)
			return
		}
	}


	// We COULD collect all collisions and do something off that. But this kinda feels good.
	for enemy in enemies.active {
		if checkCollision(enemy, projected) {
			return
		}
	}

	player.spacial.pos += velocity * getDelta()
}

updatePlayerStateBase :: proc(player: ^Player, objs: [dynamic]EnvObj, enemies: ^EnemyPool) {
	player.point.y = 0 // Set to 0, some cases player gets pushed up -> check later why.

	// Add a sub state - Idle and moving
	dir := getVector()
	// Update rotation while moving
	if dir != {} {
		target := player.spacial.pos + dir
		r := lookAtVec3(target, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, getDelta() * TURN_SPEED)
	}

	// speed := getRootMotionSpeed(&player.animState, player.animSet, player.scale)
	moveAndSlide(player, dir * MOVE_SPEED, objs, enemies)

	if dir == {} {
		transitionAnimBlend(&player.animState, PLAYER.idle)
	} else {
		transitionAnimBlend(&player.animState, PLAYER.run)
	}
	// player.animState.current = (dir != {}) ? PLAYER.run : PLAYER.idle
}

updatePlayerStateDashing :: proc(
	dashing: ^playerStateDashing,
	player: ^Player,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyPool,
	camera: ^rl.Camera3D,
) {
	dir := getForwardPoint(player)

	speed := getRootMotionSpeed(&player.animState, player.animSet, player.scale)
	moveAndSlide(player, dir * speed, objs, enemies)

	if player.animState.finished {
		enterPlayerState(player, playerStateBase{}, camera, enemies)
	}
}

updatePlayerStateAttack :: proc(
	attack: ^playerStateAttack,
	player: ^Player,
	camera: ^rl.Camera3D,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyPool,
) {
	// Go back to idle if finished full animation
	if player.animState.finished {
		enterPlayerState(player, playerStateBase{}, camera, enemies)
		return
	}

	// Use root motion
	speed := getRootMotionSpeed(&player.animState, player.animSet, player.scale)
	dir := getForwardPoint(player)
	moveAndSlide(player, dir * speed, objs, enemies)

	frame := i32(math.floor(player.animState.duration * FPS_30))

	// Action
	if frame >= attack.action_frame && !attack.hasTriggered {
		attack.hasTriggered = true
		doAction(attack.action)
		pos := getForwardPoint(player)
		spawnFlipbook(&player.trailRight, player.pos + pos, player.rot)
	}

	if frame >= attack.cancel_frame && attack.comboInput {
		left := playerStateAttackLeft {
			action = attack.action, // Pass forward the action, might want to make this global??
		}
		enterPlayerState(player, left, camera, enemies)
		return
	}

	// Go back to idle if WASD past the given frame
	if frame >= attack.cancel_frame && getVector() != {} {
		enterPlayerState(player, playerStateBase{}, camera, enemies)
		return
	}
}

updatePlayerStateAttackLeft :: proc(
	attack: ^playerStateAttackLeft,
	player: ^Player,
	camera: ^rl.Camera3D,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyPool,
) {
	// Go back to idle if finished full animation
	if player.animState.finished {
		enterPlayerState(player, playerStateBase{}, camera, enemies)
		return
	}

	// Use root motion
	speed := getRootMotionSpeed(&player.animState, player.animSet, player.scale)
	dir := getForwardPoint(player)
	moveAndSlide(player, dir * speed, objs, enemies)

	frame := i32(math.floor(player.animState.duration * FPS_30))

	// Action
	if frame >= attack.action_frame && !attack.hasTriggered {
		attack.hasTriggered = true
		doAction(attack.action)
		pos := getForwardPoint(player)
		spawnFlipbook(&player.trailLeft, player.pos + pos, player.rot) // left only
	}

	if frame >= attack.cancel_frame && attack.comboInput {
		right := playerStateAttack {
			action = attack.action, // Pass forward the action, might want to make this global??
		}
		enterPlayerState(player, right, camera, enemies)
		return
	}

	// Go back to idle if WASD past the given frame
	if frame >= attack.cancel_frame && getVector() != {} {
		enterPlayerState(player, playerStateBase{}, camera, enemies)
		return
	}
}

updatePlayerStateBlocking :: proc(
	blocking: ^playerStateBlocking,
	player: ^Player,
	camera: ^rl.Camera3D,
	enemies: ^EnemyPool,
	enemyAbilities: ^AbilityPool,
	playerAbilities: ^AbilityPool,
) {
	blocking.durration += getDelta()

	parry: {
		if blocking.durration > PARRY_WINDOW do break parry

		#reverse for &ability, index in enemyAbilities.active {
			if !ability.canParry do continue
			dist := rl.Vector3DistanceSqrt(ability.spacial.pos, player.pos)
			if dist > PARRY_DIST do continue
			player.attack.current += 2
			parryAbility(index, enemyAbilities, playerAbilities)
			addTrauma(.large)
		}
	}

	// target := mouseInWorld(camera)
	// r := lookAtVec3(target, player.spacial.pos)
	// player.spacial.rot = lerpRAD(player.spacial.rot, r, getDelta() * TURN_SPEED)
}

updatePlayerStateBlockBashing :: proc(
	bash: ^playerStateBlockBash,
	player: ^Player,
	camera: ^rl.Camera3D,
	objs: [dynamic]EnvObj,
	enemies: ^EnemyPool,
) {
	dir := getForwardPoint(player)

	// moveAndSlide(player, dir * 30, objs, enemies)
	player.pos += dir * .1

	if linalg.length2(player.pos - bash.target) > 5 do return
	doAction(bash.action)
	enterPlayerState(player, playerStateBase{}, camera, enemies) //Into an attack?
}

playerInputDash :: proc(player: ^Player, state: State, camera: ^rl.Camera3D, enemies: ^EnemyPool) {
	// Make 'ability' for dash

	// if ability is interruptable
	if !hasEnoughStamina() {return}
	if !isKeyPressed(DASH) {return}
	if !canDash(player) {return}

	consumeStamina()
	enterPlayerState(player, state, camera, enemies)
}

// New AbilityState into State -> Passed in 
// OR Animation + ability info
enterPlayerState :: proc(
	player: ^Player,
	state: State,
	camera: ^rl.Camera3D,
	enemies: ^EnemyPool,
) {
	// TODO: swap this function with 1 for each state? -> EnterPlayerStateBase...

	// assert? maybe this should not be a thing when we enter with checks
	player.animState.duration = 0
	player.animState.speed = 1
	// player.animState.frame = 0
	player.state = state
	player.model.materials[player.model.materialCount - 1].shader = Shaders[.Flash]

	switch &s in player.state {
	case playerStateBase:
		transitionAnim(&player.animState, PLAYER.idle)
	case playerStateDashing:
		playSoundGrunt()
		// Snap to player movement or forward dir if not moving
		dir := getVector()
		s.timer.left = s.timer.max
		if dir == {} do dir = getForwardPoint(player)

		r := lookAtVec3(player.spacial.pos + dir, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

		player.animState.speed = s.speed
		player.model.materials[player.model.materialCount - 1].shader = Shaders[.GrayScale]
		transitionAnim(&player.animState, s.animation)
	case playerStateAttack:
		doAttack(&player.attack)
		s.action_frame = 10
		s.cancel_frame = 16
		s.cancellable = true

		// s.action = SET FROM GOBA?
		playSoundWhoosh()

		result := getEnemyHitResult(enemies, camera)
		target := mouseInWorld(camera)
		if result.hit do target = result.pos
		// Snap to mouse direction before attack
		r := lookAtVec3(target, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

		transitionAnim(&player.animState, PLAYER.punch)
	case playerStateAttackLeft:
		doAttack(&player.attack)
		s.action_frame = 10
		s.cancel_frame = 16
		s.cancellable = true
		playSoundWhoosh()

		// Snap to mouse direction before attack or Enemy
		result := getEnemyHitResult(enemies, camera)
		target := mouseInWorld(camera)
		if result.hit do target = result.pos
		r := lookAtVec3(target, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

		transitionAnim(&player.animState, PLAYER.punch2)
	case playerStateBlocking:
		// Snap to mouse direction before attack or Enemy
		target := mouseInWorld(camera)
		r := lookAtVec3(target, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)
		// TODO: Add blocking anim
		transitionAnim(&player.animState, PLAYER.block)
		player.model.materials[player.model.materialCount - 1].shader = Shaders[.GrayScale]
	case playerStateBlockBash:
		// Snap to mouse direction before attack or Enemy
		result := getEnemyHitResult(enemies, camera)
		target := mouseInWorld(camera)
		if result.hit do target = result.pos
		r := lookAtVec3(target, player.spacial.pos)
		player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)

		player.model.materials[player.model.materialCount - 1].shader = Shaders[.GrayScale]
		transitionAnim(&player.animState, PLAYER.dash)
	}
}

State :: union {
	playerStateBase,
	playerStateDashing,
	playerStateAttack, // DO we have one state of all abilities or each one has it's own?
	playerStateAttackLeft,
	playerStateBlocking,
	playerStateBlockBash,
	//	AbiltiyPreviewState
}

playerStateBase :: struct {}

playerStateBlocking :: struct {
	// TODO: maybe add Actions or other fields
	durration: f32,
	animation: ANIMATION_NAMES, // TODO group these 2
}

playerStateBlockBash :: struct {
	target: vec3,
	action: Action,
}

playerStateDashing :: struct {
	// TODO: maybe add Actions or other fields
	timer:     Timer,
	animation: ANIMATION_NAMES, // TODO group these 2
	speed:     f32,
}

// Can only be set from player_input checks with other abilitys and not in update
playerStateAttack :: struct {
	// Can cancel
	cancellable:  bool,
	// Animation Data
	animation:    ANIMATION_NAMES,
	speed:        f32,
	// Action Data TODO: Move into its own struct, take in array
	hasTriggered: bool,
	// trigger:       f32, // between 0 and 1 -- Sub for frame in future
	action_frame: i32,
	action:       Action,
	cancel_frame: i32,
	// combo
	comboInput:   bool,
}

playerStateAttackLeft :: struct {
	// Can cancel
	cancellable:  bool,
	// Need timer to know how deep into the state we are
	// Animation Data
	animation:    ANIMATION_NAMES,
	speed:        f32,
	// Action Data TODO: Move into its own struct, take in array
	hasTriggered: bool,
	// trigger:       f32, // between 0 and 1 -- Sub for frame in future
	action_frame: i32,
	action:       Action,
	cancel_frame: i32,
	// combo
	comboInput:   bool,
}

// 	r := lookAtVec3(mouseInWorld(camera), player.spacial.pos)
// 	player.spacial.rot = lerpRAD(player.spacial.rot, r, 1)
// 	if progress > .5 { 	// Move .5 to struct?
// 		dir := getForwardPoint(player)
// 		moveAndStop(player, dir * MOVE_SPEED * 3, objs, enemies) // IF stoped -> trigger action? TODO: make func return collision
// 	}
// 	if attack.timer.left <= 0 {
// 		enterPlayerState(player, playerStateBase{}, camera, enemies)
// 	}
// }

// Draw
drawPlayer :: proc(player: Player, camera: ^rl.Camera3D) {
	drawHitFlash(player.model, player.health)

	hudPos := player.pos + {0, 3.4, 0}
	drawHealthbar(player.health, camera, hudPos) // ADD top of player spot
	// drawBlockbar(player.block, camera, hudPos)
	drawAttackbar(player.attack, camera, hudPos)
	drawStamina(camera, hudPos)

	// Draw player
	assert(player.scale != 0, "Scale is 0")

	// TODO: precompute Model + View + Projection matrix and feed into these 2 functions?
	drawShadow(player.model, player.spacial, player.scale, camera)
	black := vec4{0, 0, 0, 1}
	drawOutline(player.model, player.spacial, player.scale, camera, black)
	rl.DrawModelEx(
		player.model,
		player.spacial.pos,
		UP,
		rl.RAD2DEG * player.spacial.rot,
		player.scale,
		rl.WHITE,
	)

	r := lookAtVec3(mouseInWorld(camera), player.spacial.pos) + rl.PI
	rl.DrawModelEx(player.viewCircle, player.pos + {0, .1, 0}, UP, rl.RAD2DEG * r, 2, rl.WHITE)
	if isBlocking(player) {
		// box := rl.GetModelBoundingBox(player.model)
		// modelMatrix := getSpacialMatrixNoRot(player.spacial, player.scale * 1.1)
		// box.min = rl.Vector3Transform(box.min, modelMatrix)
		// box.max = rl.Vector3Transform(box.max, modelMatrix)
		mesh := rl.GenMeshCube(1.5, 3, .1) // TODO: swap with a model on gen based on block angle?
		shield := rl.LoadModelFromMesh(mesh)
		rl.DrawModelEx(
			shield,
			player.spacial.pos + getForwardPoint(player) + {0, 1.5, 0},
			UP,
			rl.RAD2DEG * player.spacial.rot,
			1,
			rl.WHITE,
		)
		// rl.DrawBoundingBox(box, rl.WHITE)
		// rl.DrawSphere(player.pos, 2, rl.WHITE)
		// rl.DrawSphereWires(player.pos, 2.5, 8, 8, rl.WHITE)
	}
}
