package main

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:prof/spall"
import "core:time"
import rl "vendor:raylib"
// Stores all animations for the asset pack
PLAYER :: enum {
	run,
	punch2,
	punch1,
	roll,
	longPunch,
	p1,
	p2,
	p3,
	p4,
	idle,
}

// enum is 1 shifted down from what they are in the file
SKELE :: enum {
	idle2,
	idle,
	hurt,
	hurt2,
	run,
	attack,
}

ANIMATION_NAMES :: union {
	PLAYER,
	SKELE,
}

// Export maximo at 30 fps -> blender at 60 -> render FPS at 30 here
FPS_30 :: 30

AnimationState :: struct {
	duration: f32,
	finished: bool, // Signal :: Animation just finished
	current:  ANIMATION_NAMES, //current anim
	speed:    f32,
}

// We can share this struct for models using the same animations {Adventueres | skeletons}
AnimationSet :: struct {
	total: i32, //total animations
	anims: [^]rl.ModelAnimation,
}

debug := false
// https://www.youtube.com/live/-LPHV452k1Y?si=JLSJ31LMlaPsKLO0&t=3794
// How to make own function for blending animations
updateAnimation :: proc(model: rl.Model, state: ^AnimationState, set: AnimationSet) {
	assert(set.total != 0, "empty set")
	assert(
		state.speed != 0,
		fmt.tprint("Animation speed is Zero, do we want that?", model, state^, set),
	)
	frame := i32(math.floor(state.duration * FPS_30))

	current: i32
	switch v in state.current {
	case PLAYER:
		current = i32(v)
	case SKELE:
		current = i32(v)
	}

	anim := set.anims[current]
	// when ODIN_DEBUG {
	// 	start := time.now()
	// 	defer fmt.println(time.since(start))
	// }
	start := time.now()
	if debug {
		// fmt.println("C")
		// rl.UpdateModelAnimation(model, anim, frame)
	} else {
		// fmt.println("Custom")
		updateModelAnimation(model, anim, frame)
		// updateModelAnimationCOPY(model, anim, frame)
	}
	// fmt.println(time.since(start))

	state.duration += getDelta() * state.speed

	// Will be set for a single frame until reset next turn.
	state.finished = false
	if frame >= anim.frameCount {
		state.finished = true
		state.duration = 0
	}
}

getAnimationProgress :: proc(state: AnimationState, set: AnimationSet) -> f32 {
	current: i32
	switch v in state.current {
	case PLAYER:
		current: i32 = i32(v)
	case SKELE:
		current = i32(v)
	}

	frame := i32(math.floor(state.duration * FPS_30))
	anim := set.anims[current]
	return f32(frame) / f32(anim.frameCount)
}

// -------------------------------------------
// Odin version of update model animation, using to later try and blend between 2 animations
// https://github.com/raysan5/raylib/blob/cceabf69619bcb84fb3dd3f0e6c191f5b8732d5a/src/rmodels.c#L2337-L2401
updateModelAnimation :: proc(model: rl.Model, anim: rl.ModelAnimation, frame: i32) {
	rl.UpdateModelAnimationBones(model, anim, frame)
	// #no_bounds_check {}

	// fmt.println(
	// 	"MESHCOUNT",
	// 	model.meshCount,
	// 	model.meshes[0].vertexCount,
	// 	anim.boneCount,
	// 	model.meshes[0].boneIds,
	// )
	invTransposedBoneMatrices := make([]rl.Matrix, anim.boneCount) // NOTE: can we save this some where in init?
	defer delete(invTransposedBoneMatrices)

	for m in 0 ..< model.meshCount {
		mesh := model.meshes[m]
		animVertex: vec3 = {}
		animNormal: vec3 = {}
		boneId: u8 = 0
		boneCounter := 0
		boneWeight: f32 = 0.0
		updated := false // Flag to check when anim vertex information is updated
		vValues := mesh.vertexCount * 3

		// for ii in 0 ..< 10000 {
		// 	fmt.println(ii, mesh.boneIds[ii])
		// }
		// Skip if missing bone data
		if mesh.boneWeights == nil || mesh.boneIds == nil do continue

		// Pre-calculate matrices for each bone to avoid recomputing -> this actually speeds a good amount
		for i in 0 ..< anim.boneCount {
			invTransposedBoneMatrices[i] = linalg.transpose(linalg.inverse(mesh.boneMatrices[i]))
		}

		for vCounter: i32 = 0; vCounter < vValues; vCounter += 3 {
			mesh.animVertices[vCounter] = 0
			mesh.animVertices[vCounter + 1] = 0
			mesh.animVertices[vCounter + 2] = 0

			if mesh.animNormals != nil {
				mesh.animNormals[vCounter] = 0
				mesh.animNormals[vCounter + 1] = 0
				mesh.animNormals[vCounter + 2] = 0
			}

			// Iterates over 4 bones per vertex
			for j in 0 ..< 4 {
				boneWeight = mesh.boneWeights[boneCounter]
				boneId = mesh.boneIds[boneCounter]
				// fmt.println("ID:", boneId, "counter", boneCounter)
				// fmt.println("ID:", boneId, "counter", boneCounter)
				boneCounter += 1

				if boneWeight == 0 do continue

				// Transform vertex
				animVertex =
					(mesh.boneMatrices[boneId] * vec4{mesh.vertices[vCounter], mesh.vertices[vCounter + 1], mesh.vertices[vCounter + 2], 1}).xyz

				mesh.animVertices[vCounter] += animVertex.x * boneWeight
				mesh.animVertices[vCounter + 1] += animVertex.y * boneWeight
				mesh.animVertices[vCounter + 2] += animVertex.z * boneWeight

				updated = true

				if mesh.normals != nil && mesh.animNormals != nil {

					animNormal =
						(invTransposedBoneMatrices[boneId] * vec4{mesh.normals[vCounter], mesh.normals[vCounter + 1], mesh.normals[vCounter + 2], 1}).xyz

					mesh.animNormals[vCounter] += animNormal.x * boneWeight
					mesh.animNormals[vCounter + 1] += animNormal.y * boneWeight
					mesh.animNormals[vCounter + 2] += animNormal.z * boneWeight
				}
			}
		}

		if updated {
			rl.UpdateMeshBuffer(mesh, 0, mesh.animVertices, mesh.vertexCount * 3 * size_of(f32), 0)

			if mesh.normals != nil {
				rl.UpdateMeshBuffer(
					mesh,
					2,
					mesh.animNormals,
					mesh.vertexCount * 3 * size_of(f32),
					0,
				)
			}
		}
	}
}

// -------------------------------------------
// Odin version of update model animation, using to later try and blend between 2 animations
// https://github.com/raysan5/raylib/blob/cceabf69619bcb84fb3dd3f0e6c191f5b8732d5a/src/rmodels.c#L2337-L2401
updateModelAnimationCOPY :: proc(model: rl.Model, anim: rl.ModelAnimation, frame: i32) {
	rl.UpdateModelAnimationBones(model, anim, frame)

	for m in 0 ..< model.meshCount {
		// For each mesh in a model
		mesh := model.meshes[m]
		animVertex: vec3 = {}
		animNormal: vec3 = {}
		boneId: u8 = 0
		boneCounter := 0
		boneWeight: f32 = 0.0
		updated := false // Flag to check when anim vertex information is updated
		vValues := mesh.vertexCount * 3

		// Skip if missing bone data
		if mesh.boneWeights == nil || mesh.boneIds == nil do continue


		for vCounter: i32 = 0; vCounter < vValues; vCounter += 3 {
			mesh.animVertices[vCounter] = 0
			mesh.animVertices[vCounter + 1] = 0
			mesh.animVertices[vCounter + 2] = 0

			if mesh.animNormals != nil {
				mesh.animNormals[vCounter] = 0
				mesh.animNormals[vCounter + 1] = 0
				mesh.animNormals[vCounter + 2] = 0
			}

			// Iterates over 4 bones per vertex
			for j in 0 ..< 4 {
				boneWeight = mesh.boneWeights[boneCounter]
				boneId = mesh.boneIds[boneCounter]
				boneCounter += 1

				// Early stop when no transformation will be applied
				if boneWeight == 0 do continue

				animVertex: vec3
				// Load vertex directly into array
				animVertex.x = mesh.vertices[vCounter]
				animVertex.y = mesh.vertices[vCounter + 1]
				animVertex.z = mesh.vertices[vCounter + 2]

				animVertex = rl.Vector3Transform(animVertex, mesh.boneMatrices[boneId])

				mesh.animVertices[vCounter] += animVertex.x * boneWeight
				mesh.animVertices[vCounter + 1] += animVertex.y * boneWeight
				mesh.animVertices[vCounter + 2] += animVertex.z * boneWeight

				updated = true

				if mesh.normals != nil && mesh.animNormals != nil {
					normal: vec3
					normal.x = mesh.normals[vCounter]
					normal.y = mesh.normals[vCounter + 1]
					normal.x = mesh.normals[vCounter + 2]

					animNormal = rl.Vector3Transform(
						normal,
						rl.MatrixTranspose(rl.MatrixInvert(mesh.boneMatrices[boneId])),
					)

					mesh.animNormals[vCounter] += animNormal.x * boneWeight
					mesh.animNormals[vCounter + 1] += animNormal.y * boneWeight
					mesh.animNormals[vCounter + 2] += animNormal.z * boneWeight
				}
			}
		}

		if updated {
			rl.UpdateMeshBuffer(mesh, 0, mesh.animVertices, mesh.vertexCount * 3 * size_of(f32), 0)

			if mesh.normals != nil {
				rl.UpdateMeshBuffer(
					mesh,
					2,
					mesh.animNormals,
					mesh.vertexCount * 3 * size_of(f32),
					0,
				)
			}
		}
	}
}


// This function is broken --- Fix later
updateModelAnimationBones :: proc(model: rl.Model, anim: rl.ModelAnimation, frame: i32) {
	if !(anim.frameCount > 0 && anim.bones != nil && anim.framePoses != nil) {
		return
	}
	aframe := frame
	if frame >= anim.frameCount {aframe = frame % anim.frameCount}

	// Get first mesh which has bones
	firstMeshWithBones: i32 = -1
	for ii in 0 ..< model.meshCount {
		if model.meshes[ii].boneMatrices != nil {
			if firstMeshWithBones == -1 {
				firstMeshWithBones = ii
				break
			}
		}
	}

	// Update all bones and boneMatrices of first mesh with bones
	for boneId in 0 ..< anim.boneCount {
		// The important part is maintaining the exact same transformation order as the C code
		inTranslation := model.bindPose[boneId].translation
		inRotation := model.bindPose[boneId].rotation
		inScale := model.bindPose[boneId].scale

		outTranslation := anim.framePoses[aframe][boneId].translation
		outRotation := anim.framePoses[aframe][boneId].rotation
		outScale := anim.framePoses[aframe][boneId].scale

		invRotation := 1 / inRotation
		invTranslation := rl.Vector3RotateByQuaternion(-inTranslation, invRotation)
		invScale := vec3{1, 1, 1} / inScale

		// Keep the exact same calculation order as the C code
		boneTranslation :=
			rl.Vector3RotateByQuaternion(outScale * invTranslation, outRotation) + outTranslation
		boneRotation := outRotation * invRotation
		boneScale := outScale * invScale

		// The matrix multiplication order is critical - matching C exactly
		boneMatrix :=
			(rl.QuaternionToMatrix(boneRotation) *
				rl.MatrixTranslate(boneTranslation.x, boneTranslation.y, boneTranslation.z)) *
			rl.MatrixScale(boneScale.x, boneScale.y, boneScale.z)

		model.meshes[firstMeshWithBones].boneMatrices[boneId] = boneMatrix
	}

	if firstMeshWithBones != -1 {
		// Update remaining meshes with bones
		for i := firstMeshWithBones + 1; i < model.meshCount; i += 1 {
			if model.meshes[i].boneMatrices != nil {
				size := model.meshes[i].boneCount * size_of(model.meshes[i].boneMatrices[0])
				intrinsics.mem_copy(
					model.meshes[i].boneMatrices,
					model.meshes[firstMeshWithBones].boneMatrices,
					size,
				)
			}
		}
	}
}
