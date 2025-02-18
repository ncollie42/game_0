package main

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:prof/spall"
import "core:strings"
import "core:time"
//https://github.com/cr1sth0fer/odin-m3d
import m3d "odin-m3d"
import rl "vendor:raylib"
// Stores all animations for the asset pack
PLAYER :: enum {
	kick,
	punch,
	punch2,
	run,
	run_fast,
	idle,
	// roll,
}
// um {
// 	run,
// 	// punch2,
// 	// punch1,
// 	roll,
// 	longPunch,
// 	// p1,
// 	// p2,
// 	// p3,
// 	// p4,
// 	idle,
// }

// enum is 1 shifted down from what they are in the file
SKELE :: enum {
	idle2,
	idle,
	hurt,
	hurt2,
	run,
	attack,
}

RM :: enum {
	idle,
	forward,
}

ANIMATION_NAMES :: union {
	PLAYER,
	SKELE,
	RM,
}

// Export maximo at 30 fps -> blender at 60 -> render FPS at 30 here
FPS_30 :: 30

AnimationState :: struct {
	duration: f32,
	finished: bool, // Signal :: Animation just finished
	current:  ANIMATION_NAMES,
	// current:  i32, //current anim
	speed:    f32,
}

// We can share this struct for models using the same animations {Adventueres | skeletons}
AnimationSet :: struct {
	total: i32, //total animations
	anims: [^]rl.ModelAnimation,
	RMs:   [dynamic][dynamic]vec3, // RootMotion baked in [animation][frame]
}

// https://www.youtube.com/live/-LPHV452k1Y?si=JLSJ31LMlaPsKLO0&t=3794
// How to make own function for blending animations
updateAnimation :: proc(model: rl.Model, state: ^AnimationState, set: AnimationSet) {
	assert(set.total != 0, "empty set")
	assert(
		state.speed != 0,
		fmt.tprint("Animation speed is Zero, do we want that?", model, state^, set),
	)
	current: i32 = animEnumToInt(state.current)
	anim := set.anims[current]

	frame := i32(math.floor(state.duration * FPS_30))
	actualFrame := frame % anim.frameCount

	updateModelAnimation(model, anim, frame)

	state.duration += getDelta() * state.speed
	nextFrame := i32(math.floor(state.duration * FPS_30))
	state.finished = false
	if nextFrame >= anim.frameCount {
		state.finished = true
		state.duration = 0
	}
}

getAnimationProgress :: proc(state: AnimationState, set: AnimationSet) -> f32 {
	current: i32 = animEnumToInt(state.current)

	frame := i32(math.floor(state.duration * FPS_30))
	anim := set.anims[current]
	return f32(frame) / f32(anim.frameCount)
}

// -------------------------------------------
// Odin version of update model animation, using to later try and blend between 2 animations
// https://github.com/raysan5/raylib/blob/cceabf69619bcb84fb3dd3f0e6c191f5b8732d5a/src/rmodels.c#L2337-L2401
updateModelAnimation :: proc(model: rl.Model, anim: rl.ModelAnimation, frame: i32) {
	rl.UpdateModelAnimationBones(model, anim, frame)

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

animEnumToInt :: proc(current: ANIMATION_NAMES) -> i32 {
	switch v in current {
	case PLAYER:
		return i32(v)
	case SKELE:
		return i32(v)
	case RM:
		return i32(v)
	case:
		panic("Anim isn't set.")
	}
	return 0
}

getRootMotion :: proc(state: ^AnimationState, set: AnimationSet) -> vec3 {
	assert(set.total != 0, "empty set")
	assert(state.speed != 0, fmt.tprint("Animation speed is Zero, do we want that?"))

	frame := i32(math.floor(state.duration * FPS_30))
	current: i32 = animEnumToInt(state.current)

	anim := set.anims[current]

	if anim.frameCount <= 0 || anim.bones == nil || anim.framePoses == nil {
		return {}
	}

	actualFrame := frame % anim.frameCount

	assert(
		frame == actualFrame,
		"frame and actualFrame can't be the same, update messed up somewhere.",
	)
	assert(actualFrame != anim.frameCount)

	return set.RMs[current][frame]
}

getRootMotionSpeed :: proc(state: ^AnimationState, set: AnimationSet, scale: f32) -> f32 {
	// Only using the forward axis
	assert(set.total != 0, "empty set")
	assert(state.speed != 0, fmt.tprint("Animation speed is Zero, do we want that?"))

	frame := i32(math.floor(state.duration * FPS_30))
	current: i32 = animEnumToInt(state.current)

	anim := set.anims[current]

	if anim.frameCount <= 0 || anim.bones == nil || anim.framePoses == nil {
		return {}
	}

	actualFrame := frame % anim.frameCount

	assert(
		frame == actualFrame,
		"frame and actualFrame can't be the same, update messed up somewhere.",
	)
	assert(actualFrame != anim.frameCount)

	return (set.RMs[current][frame] * FPS_30 * scale).z
}

// ------------------------- M3D importer ------------------------- 

// M3D_ANIMDELAY_60 :: 17 // Animation frames delay (~1000 ms/60 FPS = 16.666666* ms)
M3D_ANIMDELAY :: 33 // Animation frames delay (~1000 ms/30 FPS = 33.333333* ms)

m3d_loaderhook :: proc(filename: cstring, size: ^u32) -> [^]u8 {
	// return rl.LoadFileData(filename, size)
	return {}
}
m3d_freehook :: proc(buffer: rawptr) {
	// rl.UnloadFileData(buffer)
}

// https://github.com/raysan5/raylib/blob/master/src/rmodels.c#L6747
loadM3DAnimations :: proc(path: cstring) -> AnimationSet {
	assert(
		strings.has_suffix(string(path), ".m3d"),
		fmt.tprint("[loadM3DAnimation] Not an .m3d file :", path),
	)

	anim := AnimationSet{}
	animations: [^]rl.ModelAnimation = nil
	m3d_t: ^m3d.m3d_t = nil

	data_size: i32
	file_data := rl.LoadFileData(path, &data_size)
	assert(file_data != nil, "File data is nil, could not laod m3d animations")
	defer rl.UnloadFileData(file_data)

	m3d_t = m3d.load(file_data, nil, nil, nil) // TODO: Add in loader/free callbacks 
	assert(m3d_t != nil, "m3d_t failed to load")
	assert(!(m3d_t.errcode > -65 && m3d_t.errcode < 0), "m3d_t failed to load, fatal error.")
	defer m3d.free(m3d_t)

	// No animation or bone+skin?
	assert(m3d_t.numaction > 0, "No animations in this m3d")
	assert(m3d_t.numbone > 0, "No bones in this m3d")
	assert(m3d_t.numskin > 0, "No skin in this m3d")

	// Allocate animations array
	anim.total = i32(m3d_t.numaction)
	animations = raw_data(make([]rl.ModelAnimation, m3d_t.numaction))

	for a in 0 ..< int(m3d_t.numaction) {
		animations[a].frameCount = i32(m3d_t.action[a].durationmsec / M3D_ANIMDELAY)
		animations[a].boneCount = i32(m3d_t.numbone + 1)

		// Allocate bones and framePoses
		animations[a].bones = raw_data(make([]rl.BoneInfo, m3d_t.numbone + 1))
		animations[a].framePoses = raw_data(make([][^]rl.Transform, animations[a].frameCount))

		copy_string(animations[a].name[:], m3d_t.action[a].name)

		// Copy bone information
		for i in 0 ..< int(m3d_t.numbone) {
			animations[a].bones[i].parent = i32(m3d_t.bone[i].parent)
			copy_string(animations[a].bones[i].name[:], m3d_t.bone[i].name)
		}
		// Set up "no bone" bone
		animations[a].bones[m3d_t.numbone].parent = -1
		copy_string(animations[a].bones[m3d_t.numbone].name[:], "NO BONE")

		// Process animation frames
		for i in 0 ..< int(animations[a].frameCount) {
			animations[a].framePoses[i] = raw_data(make([]rl.Transform, m3d_t.numbone + 1))
			pose := transmute([^]m3d.b_t)m3d.pose(m3d_t, u32(a), u32(i) * M3D_ANIMDELAY)
			assert(pose != nil, "Pose is nill??")
			// defer free(transmute(^m3d.b_t)pose) // TODO free this pose some how -> THIS WILL SEGFUALT

			for j in 0 ..< int(m3d_t.numbone) {
				// Set translation
				animations[a].framePoses[i][j].translation = {
					m3d_t.vertex[pose[j].pos].x * m3d_t.scale,
					m3d_t.vertex[pose[j].pos].y * m3d_t.scale,
					m3d_t.vertex[pose[j].pos].z * m3d_t.scale,
				}


				// Set rotation
				animations[a].framePoses[i][j].rotation.x = m3d_t.vertex[pose[j].ori].x
				animations[a].framePoses[i][j].rotation.y = m3d_t.vertex[pose[j].ori].y
				animations[a].framePoses[i][j].rotation.z = m3d_t.vertex[pose[j].ori].z
				animations[a].framePoses[i][j].rotation.w = m3d_t.vertex[pose[j].ori].w
				animations[a].framePoses[i][j].rotation = rl.QuaternionNormalize(
					animations[a].framePoses[i][j].rotation,
				)

				// Set scale
				animations[a].framePoses[i][j].scale = {1, 1, 1}

				if animations[a].bones[j].parent < 0 {
					continue
				}
				// Convert child bones to model space
				parent_id := animations[a].bones[j].parent
				parent := &animations[a].framePoses[i][parent_id]

				animations[a].framePoses[i][j].rotation =
					parent.rotation * animations[a].framePoses[i][j].rotation

				animations[a].framePoses[i][j].translation = rl.Vector3RotateByQuaternion(
					animations[a].framePoses[i][j].translation,
					parent.rotation,
				)

				animations[a].framePoses[i][j].translation =
					animations[a].framePoses[i][j].translation + parent.translation

				animations[a].framePoses[i][j].scale =
					animations[a].framePoses[i][j].scale * parent.scale

			}
			// Set;"no bone";bone;default;transform
			animations[a].framePoses[i][m3d_t.numbone].translation = {0, 0, 0}
			animations[a].framePoses[i][m3d_t.numbone].rotation.w = 1 // {0, 0 ,0, 1}
			animations[a].framePoses[i][m3d_t.numbone].scale = {1, 1, 1}
		}
	}

	anim.anims = animations
	return anim
}

// https://github.com/raysan5/raylib/blob/master/src/rmodels.c#L6747
loadM3DAnimationsWithRootMotion :: proc(path: cstring) -> AnimationSet {
	assert(
		strings.has_suffix(string(path), ".m3d"),
		fmt.tprint("[loadM3DAnimation] Not an .m3d file :", path),
	)

	anim := AnimationSet{}
	animations: [^]rl.ModelAnimation = nil
	m3d_t: ^m3d.m3d_t = nil

	data_size: i32
	file_data := rl.LoadFileData(path, &data_size)
	assert(file_data != nil, "File data is nil, could not laod m3d animations")
	defer rl.UnloadFileData(file_data)

	m3d_t = m3d.load(file_data, nil, nil, nil) // TODO: Add in loader/free callbacks 
	assert(m3d_t != nil, "m3d_t failed to load")
	assert(!(m3d_t.errcode > -65 && m3d_t.errcode < 0), "m3d_t failed to load, fatal error.")
	defer m3d.free(m3d_t)

	// No animation or bone+skin?
	assert(m3d_t.numaction > 0, "No animations in this m3d")
	assert(m3d_t.numbone > 0, "No bones in this m3d")
	assert(m3d_t.numskin > 0, "No skin in this m3d")

	// Allocate animations array
	anim.total = i32(m3d_t.numaction)
	animations = raw_data(make([]rl.ModelAnimation, m3d_t.numaction))

	for a in 0 ..< int(m3d_t.numaction) {
		animations[a].frameCount = i32(m3d_t.action[a].durationmsec / M3D_ANIMDELAY)
		animations[a].boneCount = i32(m3d_t.numbone + 1)

		// Allocate bones and framePoses
		animations[a].bones = raw_data(make([]rl.BoneInfo, m3d_t.numbone + 1))
		animations[a].framePoses = raw_data(make([][^]rl.Transform, animations[a].frameCount))

		copy_string(animations[a].name[:], m3d_t.action[a].name)

		// Copy bone information
		for i in 0 ..< int(m3d_t.numbone) {
			animations[a].bones[i].parent = i32(m3d_t.bone[i].parent)
			copy_string(animations[a].bones[i].name[:], m3d_t.bone[i].name)
		}
		// Set up "no bone" bone
		animations[a].bones[m3d_t.numbone].parent = -1
		copy_string(animations[a].bones[m3d_t.numbone].name[:], "NO BONE")

		// Process animation frames
		for i in 0 ..< int(animations[a].frameCount) {
			animations[a].framePoses[i] = raw_data(make([]rl.Transform, m3d_t.numbone + 1))
			pose := transmute([^]m3d.b_t)m3d.pose(m3d_t, u32(a), u32(i) * M3D_ANIMDELAY)
			assert(pose != nil, "Pose is nill??")
			// defer free(transmute(^m3d.b_t)pose) // TODO free this pose some how -> THIS WILL SEGFUALT

			for j in 0 ..< int(m3d_t.numbone) {
				// Set translation
				animations[a].framePoses[i][j].translation = {
					m3d_t.vertex[pose[j].pos].x * m3d_t.scale,
					m3d_t.vertex[pose[j].pos].y * m3d_t.scale,
					m3d_t.vertex[pose[j].pos].z * m3d_t.scale,
				}


				// Set rotation
				animations[a].framePoses[i][j].rotation.x = m3d_t.vertex[pose[j].ori].x
				animations[a].framePoses[i][j].rotation.y = m3d_t.vertex[pose[j].ori].y
				animations[a].framePoses[i][j].rotation.z = m3d_t.vertex[pose[j].ori].z
				animations[a].framePoses[i][j].rotation.w = m3d_t.vertex[pose[j].ori].w
				animations[a].framePoses[i][j].rotation = rl.QuaternionNormalize(
					animations[a].framePoses[i][j].rotation,
				)

				// Set scale
				animations[a].framePoses[i][j].scale = {1, 1, 1}

				// If has root motion, hip bone starts at 1
				if animations[a].bones[j].parent < 1 {
					continue
				}
				// Convert child bones to model space
				parent_id := animations[a].bones[j].parent
				parent := &animations[a].framePoses[i][parent_id]

				animations[a].framePoses[i][j].rotation =
					parent.rotation * animations[a].framePoses[i][j].rotation

				animations[a].framePoses[i][j].translation = rl.Vector3RotateByQuaternion(
					animations[a].framePoses[i][j].translation,
					parent.rotation,
				)

				animations[a].framePoses[i][j].translation =
					animations[a].framePoses[i][j].translation + parent.translation

				animations[a].framePoses[i][j].scale =
					animations[a].framePoses[i][j].scale * parent.scale

			}
			// Set;"no bone";bone;default;transform
			animations[a].framePoses[i][m3d_t.numbone].translation = {0, 0, 0}
			animations[a].framePoses[i][m3d_t.numbone].rotation.w = 1 // {0, 0 ,0, 1}
			animations[a].framePoses[i][m3d_t.numbone].scale = {1, 1, 1}
		}

		bakeRootMotion: {
			delta: [dynamic]vec3
			// For [0, len-1]
			for i in 0 ..< int(animations[a].frameCount - 1) {
				append(
					&delta,
					animations[a].framePoses[i + 1][0].translation -
					animations[a].framePoses[i][0].translation,
				)
			}
			// Copy the prev to the last frame
			if len(delta) > 0 {
				prevDelta := delta[len(delta) - 1]
				append(&delta, prevDelta)
			}
			append(&anim.RMs, delta)
		}
	}

	anim.anims = animations
	return anim
}

// Helper proc to safely copy strings
copy_string :: proc(dest: []u8, src: cstring) {
	src_len := len(string(src))
	copy_len := min(len(dest) - 1, src_len)
	copy(dest[:copy_len], (transmute([]u8)string(src))[:copy_len])
	dest[copy_len] = 0
}
