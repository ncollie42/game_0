package main

import clay "/clay-odin"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "vendor:raylib"

EnvObj :: struct {
	model:         rl.Model,
	using spacial: Spacial,
}


initEnv :: proc() -> [dynamic]EnvObj {
	pool := [dynamic]EnvObj{}

	checked := rl.GenImageChecked(4, 4, 1, 1, color0, color4)
	texture := rl.LoadTextureFromImage(checked)

	// Stuff
	// { 	// Box
	// 	mesh := rl.GenMeshCube(4, 2, 4)
	// 	model := rl.LoadModelFromMesh(mesh)
	// 	boundingBox := rl.GetMeshBoundingBox(mesh)

	// 	model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
	// 	env := EnvObj {
	// 		model = model,
	// 		spacial = Spacial{pos = {6, 0, -6}, rot = 0, shape = boundingBox},
	// 		// spacial = Spacial{pos = {0, 1, 0}, rot = rl.PI / 4, shape = boundingBox},
	// 	}
	// 	append(&pool, env)
	// }

	// { 	// sphere
	// 	rad: f32 = 3.0
	// 	mesh := rl.GenMeshSphere(rad, 10, 10)
	// 	model := rl.LoadModelFromMesh(mesh)
	// 	model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
	// 	env := EnvObj {
	// 		model = model,
	// 		spacial = Spacial{pos = {-6, 0, -6}, shape = rad},
	// 	}
	// 	append(&pool, env)
	// }

	// Walls

	{ 	// Box
		mesh := rl.GenMeshCube(.25, .1, 25)
		model := rl.LoadModelFromMesh(mesh)
		boundingBox := rl.GetMeshBoundingBox(mesh)

		model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		env := EnvObj {
			model = model,
			spacial = Spacial{pos = {12.5, 0, 0}, shape = boundingBox},
		}
		append(&pool, env)
	}

	{ 	// Box
		mesh := rl.GenMeshCube(.25, .1, 25)
		model := rl.LoadModelFromMesh(mesh)
		boundingBox := rl.GetMeshBoundingBox(mesh)

		model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		env := EnvObj {
			model = model,
			spacial = Spacial{pos = {-12.5, 0, 0}, shape = boundingBox},
		}
		append(&pool, env)
	}

	{ 	// Box
		mesh := rl.GenMeshCube(25, .1, .25)
		model := rl.LoadModelFromMesh(mesh)
		boundingBox := rl.GetMeshBoundingBox(mesh)

		model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		env := EnvObj {
			model = model,
			spacial = Spacial{pos = {0, 0, 12.5}, shape = boundingBox},
		}
		append(&pool, env)
	}

	{ 	// Box
		mesh := rl.GenMeshCube(25, .1, .25)
		model := rl.LoadModelFromMesh(mesh)
		boundingBox := rl.GetMeshBoundingBox(mesh)

		model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture
		env := EnvObj {
			model = model,
			spacial = Spacial{pos = {0, 0, -12.5}, shape = boundingBox},
		}
		append(&pool, env)
	}

	return pool
}

drawEnv :: proc(objs: ^[dynamic]EnvObj) {
	for obj in objs {
		rl.DrawModelEx(obj.model, obj.spacial.pos, UP, rl.RAD2DEG * obj.spacial.rot, 1, rl.WHITE)
		switch s in obj.spacial.shape {
		case Box:
			box := getBoundingBox(obj)
			rl.DrawBoundingBox(box, rl.BLACK)
		case Sphere:
			rl.DrawCircle3D(obj.spacial.pos, s, {1, 0, 0}, 90, rl.BLACK)
		}
	}
}

getBoundingBoxRot :: proc(obj: Spacial) -> Box {
	// Don't use for now untill we figure out how to do OBB collision, this will generate and draw.
	box := obj.shape.(Box) // Get original box shape, not getBoundingBox
	origin := obj.pos
	rotation := rl.MatrixRotateY(obj.rot)

	// Start with first corner
	first := rl.Vector3Transform(vec3{box.min.x, box.min.y, box.min.z} - origin, rotation) + origin
	min_corner := first
	max_corner := first

	// Check all corners to find true min and max
	corners: [8]vec3
	for ii in 0 ..< 8 {
		x := (ii & 1) == 0 ? box.min.x : box.max.x
		y := (ii & 2) == 0 ? box.min.y : box.max.y
		z := (ii & 4) == 0 ? box.min.z : box.max.z

		corner := rl.Vector3Transform(vec3{x, y, z} - origin, rotation) + origin
		corners[ii] = corner

		min_corner = {
			min(min_corner.x, corner.x),
			min(min_corner.y, corner.y),
			min(min_corner.z, corner.z),
		}
		max_corner = {
			max(max_corner.x, corner.x),
			max(max_corner.y, corner.y),
			max(max_corner.z, corner.z),
		}
	}
	// Draw edges
	// Bottom face
	rl.DrawLine3D(corners[0], corners[1], rl.BLACK)
	rl.DrawLine3D(corners[1], corners[3], rl.BLACK)
	rl.DrawLine3D(corners[3], corners[2], rl.BLACK)
	rl.DrawLine3D(corners[2], corners[0], rl.BLACK)

	// Top face
	rl.DrawLine3D(corners[4], corners[5], rl.BLACK)
	rl.DrawLine3D(corners[5], corners[7], rl.BLACK)
	rl.DrawLine3D(corners[7], corners[6], rl.BLACK)
	rl.DrawLine3D(corners[6], corners[4], rl.BLACK)

	// Vertical edges
	rl.DrawLine3D(corners[0], corners[4], rl.BLACK)
	rl.DrawLine3D(corners[1], corners[5], rl.BLACK)
	rl.DrawLine3D(corners[2], corners[6], rl.BLACK)
	rl.DrawLine3D(corners[3], corners[7], rl.BLACK)

	rl.DrawCube(corners[0], 0.25, 0.25, 0.25, rl.PURPLE) // Optional: visualize all corners
	rl.DrawCube(corners[7], 0.25, 0.25, 0.25, rl.PURPLE) // Optional: visualize all corners
	return Box{min = min_corner, max = max_corner}
}

getBoundingBox :: proc(obj: Spacial) -> Box {
	box := obj.shape.(Box)
	origin := obj.pos

	return Box{min = box.min + origin, max = box.max + origin}
}

// Apply forces when too close to walls.
applyBoundaryForces :: proc(enemies: ^EnemyDummyPool, objs: ^[dynamic]EnvObj) {
	PUSH_RANGE :: .25
	MAX_FORCE :: 5.0
	INSIDE_FORCE :: 30.0

	// Maybe change to 2D?
	// Create a Env obj that in circular ; make in 2D, Draw it, Do envForce, do apply forces
	// Maybe we keep the collision to 3D? later when we have projectiles the physical wont macht the collions; or maybe env is the test for 2D - where moving stuff stay 3D?
	for &enemy in enemies.active {
		for obj in objs {
			force: vec3 = {}
			switch s in obj.spacial.shape {
			case Box:
				box := getBoundingBox(obj)
				closest := vec3 {
					clamp(enemy.pos.x, box.min.x, box.max.x),
					clamp(enemy.pos.y, box.min.y, box.max.y),
					clamp(enemy.pos.z, box.min.z, box.max.z),
				}
				enemy.wallPoint = closest

				to_boid := enemy.pos - closest
				dist := linalg.length(to_boid)

				// Kick out boid if insude the space already
				if dist == 0 {
					// Find nearest face and push away from it
					to_center := obj.spacial.pos - enemy.pos
					escape_dir := -normalize(to_center)
					force += escape_dir * INSIDE_FORCE
					continue
				}

				// Early return if too far
				if dist >= PUSH_RANGE {continue}

				// Could extract force calculation if it gets more complex
				force_scale := (1.0 - dist / PUSH_RANGE) * MAX_FORCE
				force += normalize(to_boid) * force_scale
			case Sphere:
				radius := s

				// force AWAY from center
				to_boid := enemy.pos - obj.spacial.pos
				dist := linalg.length(to_boid)

				// Kick out boid if in side the space already
				if dist <= radius {
					// TODO: fix this issue, upping force is not kicking boid out enough.
					fmt.println("INSIDE CIRCLE")
					// Find nearest face and push away from it
					escape_dir := normalize(to_boid)
					force += escape_dir * INSIDE_FORCE
					continue
				}

				// How far from surface
				dist = dist - radius
				// Early return if too far
				if dist >= PUSH_RANGE {
					continue
				}

				force_scale := (1.0 - dist / PUSH_RANGE) * MAX_FORCE
				force += normalize(to_boid) * force_scale

			}
			enemy.spacial.pos += force * getDelta() * ENEMY_SPEED
		}
	}
}

// Collision avoidance
findClearPath :: proc(boid: ^Enemy, objs: ^[dynamic]EnvObj) -> vec3 {
	// NOTE: we can also just use 2D checking
	VIEW_ANGLE :: rl.PI * 120 / 180
	RAY_COUNT :: 12
	ANGLE_PER_RAY :: VIEW_ANGLE / RAY_COUNT
	FORWARD_CONE_SIZE :: 3 // Check this many rays on each side for "forward"


	hitEnv :: proc(dist: f32, ray: rl.Ray, objs: ^[dynamic]EnvObj) -> bool {
		for obj in objs {
			collision := rl.RayCollision{}
			switch s in obj.spacial.shape {
			case Box:
				box := getBoundingBox(obj)
				collision = rl.GetRayCollisionBox(ray, box)
			case Sphere:
				collision = rl.GetRayCollisionSphere(ray, obj.spacial.pos, s)
				// not sure why circles do this
				if collision.distance < 0 {
					continue
				}
			}
			if collision.hit && collision.distance < dist {
				return true
			}
		}
		return false
	}

	makeRay :: proc(boid: ^Enemy, angle_offset: f32) -> rl.Ray {
		return rl.Ray {
			position = boid.pos,
			direction = directionFromRotation(boid.rot + angle_offset),
		}
	}

	dist := boid.range
	// Check forward cone first
	forward_is_clear := true
	for i in 0 ..< FORWARD_CONE_SIZE {
		angle := ANGLE_PER_RAY * f32(i)

		// Center ray
		if i == 0 {
			ray := makeRay(boid, angle)
			if hitEnv(dist, ray, objs) {
				forward_is_clear = false
				break
			}
			continue
		}

		// Check symmetric pair of rays
		right_ray := makeRay(boid, angle)
		left_ray := makeRay(boid, -angle)

		// TODO: use noice to pick LEFT or RIGHT
		if hitEnv(dist, right_ray, objs) || hitEnv(dist, left_ray, objs) {
			forward_is_clear = false
			break
		}
	}

	if forward_is_clear do return {}

	// If forward blocked, find first clear path
	for i in FORWARD_CONE_SIZE ..< RAY_COUNT {
		angle := ANGLE_PER_RAY * f32(i)

		right_ray := makeRay(boid, angle)
		if !hitEnv(dist, right_ray, objs) do return right_ray.direction

		left_ray := makeRay(boid, -angle)
		if !hitEnv(dist, left_ray, objs) do return left_ray.direction
	}

	return {}
}
