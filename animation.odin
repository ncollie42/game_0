package main

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:prof/spall"
import "core:strings"
import "core:time"
//https://github.com/cr1sth0fer/odin-m3d
import m3d "m3d-odin"
import rl "vendor:raylib"

PLAYER :: enum {
	idle,
	kick,
	punch,
	punch2,
	run,
	run_fast,
}

// enum is 1 shifted down from what they are in the file
// TODO: range this from skele to something more appropriate
// TODO: change to golem, mele + range
SKELE :: enum {
	hurt,
	idle,
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
	duration:       f32,
	finished:       bool, // Signal :: Animation just finished
	current:        ANIMATION_NAMES,
	// Blending between 2 anims
	next:           ANIMATION_NAMES,
	transitionTime: f32, // [0,1] for when doing animation blending between two animations
	nextDuration:   f32,
	// current:  i32, //current anim
	speed:          f32,
}

// We can share this struct for models using the same animations {Adventueres | skeletons}
AnimationSet :: struct {
	total: i32, //total animations
	anims: [^]rl.ModelAnimation,
	RMs:   [dynamic][dynamic]vec3, // RootMotion baked in [animation][frame]
}

TRANSITION_TIME :: .15
transitionAnimBlend :: proc(state: ^AnimationState, anim: ANIMATION_NAMES) {
	if state.next == anim do return
	if state.current == anim do return
	state.next = anim
	state.transitionTime = TRANSITION_TIME
	state.nextDuration = 0
}

transitionAnim :: proc(state: ^AnimationState, anim: ANIMATION_NAMES) {
	state.next = nil
	state.current = anim
	state.duration = 0

	state.transitionTime = 0
	state.nextDuration = 0
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

	assert(
		anim.boneCount == model.boneCount,
		fmt.tprint("bone count", anim.boneCount, model.boneCount),
	)

	frame := i32(math.floor(state.duration * FPS_30))
	actualFrame := frame % anim.frameCount

	if state.next != nil {
		state.transitionTime -= getDelta()
		frame2 := i32(math.floor(state.nextDuration * FPS_30))

		next: i32 = animEnumToInt(state.next)
		anim2 := set.anims[next]

		amount := rl.Remap(state.transitionTime, TRANSITION_TIME, 0, 0, 1) // [0,1]
		amount = clamp(amount, 0.0, 1.0)

		updateModelAnimationTransition(model, anim, frame, anim2, frame2, amount)
		if state.transitionTime <= 0 {
			state.current = state.next
			state.duration = state.nextDuration

			state.next = nil
			state.transitionTime = 0
		}

		state.nextDuration += getDelta() * state.speed
	} else {
		rl.UpdateModelAnimation(model, anim, frame)
	}

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

updateModelAnimationTransition :: proc(
	model: rl.Model,
	anim: rl.ModelAnimation,
	frame: i32,
	anim2: rl.ModelAnimation,
	frame2: i32,
	amount: f32,
) {
	updateModelAnimationBonesBlendTransition(model, anim, frame, anim2, frame2, amount)

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

// https://github.com/raysan5/raylib/blob/master/src/rmodels.c#L2268-L2332l
updateModelAnimationBones :: proc(model: rl.Model, anim: rl.ModelAnimation, frame: i32) {
	if !(anim.frameCount > 0 && anim.bones != nil && anim.framePoses != nil) {
		return
	}
	aframe := frame
	if aframe >= anim.frameCount do aframe = aframe % anim.frameCount

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
		inTranslation := model.bindPose[boneId].translation
		inRotation := model.bindPose[boneId].rotation
		inScale := model.bindPose[boneId].scale

		outTranslation := anim.framePoses[aframe][boneId].translation
		outRotation := anim.framePoses[aframe][boneId].rotation
		outScale := anim.framePoses[aframe][boneId].scale

		invRotation := 1 / inRotation
		invTranslation := rl.Vector3RotateByQuaternion(-inTranslation, invRotation)
		invScale := vec3{1.0, 1.0, 1.0} / inScale

		boneTranslation :=
			rl.Vector3RotateByQuaternion(outScale * invTranslation, outRotation) + outTranslation

		boneRotation := outRotation * invRotation
		boneScale := outScale * invScale

		// C and Odin Matrix multipy are reversed! at least the rl.Matrimultiply - it's flipped from the origianl
		boneMatrix :=
			rl.MatrixScale(boneScale.x, boneScale.y, boneScale.z) *
			(rl.MatrixTranslate(boneTranslation.x, boneTranslation.y, boneTranslation.z) *
					rl.QuaternionToMatrix(boneRotation)) // new
		model.meshes[firstMeshWithBones].boneMatrices[boneId] = boneMatrix
	}

	if firstMeshWithBones != -1 {
		// Update remaining meshes with bones
		for ii := firstMeshWithBones + 1; ii < model.meshCount; ii += 1 {
			if model.meshes[ii].boneMatrices != nil {
				size := model.meshes[ii].boneCount * size_of(model.meshes[ii].boneMatrices[0])
				intrinsics.mem_copy(
					model.meshes[ii].boneMatrices,
					model.meshes[firstMeshWithBones].boneMatrices,
					size,
				)
			}
		}
	}
}

updateModelAnimationBonesBlendTransition :: proc(
	model: rl.Model,
	anim1: rl.ModelAnimation,
	frame1: i32,
	anim2: rl.ModelAnimation,
	frame2: i32,
	amount: f32,
) {
	// only intended to be use with looping anims,
	// not sure about oneShots and transition towards the end. don't want to loop.
	if !(anim1.frameCount > 0 && anim1.bones != nil && anim1.framePoses != nil) {
		return
	}
	if !(anim2.frameCount > 0 && anim2.bones != nil && anim2.framePoses != nil) {
		return
	}
	aframe := frame1
	if aframe >= anim1.frameCount do aframe = aframe % anim1.frameCount
	aframe2 := frame2
	if aframe2 >= anim2.frameCount do aframe2 = aframe2 % anim2.frameCount

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
	for boneId in 0 ..< anim1.boneCount {
		inTranslation := model.bindPose[boneId].translation
		inRotation := model.bindPose[boneId].rotation
		inScale := model.bindPose[boneId].scale

		outTranslation := anim1.framePoses[aframe][boneId].translation
		outRotation := anim1.framePoses[aframe][boneId].rotation
		outScale := anim1.framePoses[aframe][boneId].scale

		outTranslation2 := anim2.framePoses[aframe2][boneId].translation
		outRotation2 := anim2.framePoses[aframe2][boneId].rotation
		outScale2 := anim2.framePoses[aframe2][boneId].scale

		outTranslation = linalg.lerp(outTranslation, outTranslation2, amount)
		outRotation = rl.QuaternionSlerp(outRotation, outRotation2, amount) // This needs to be Slerp and not lerp
		outScale = linalg.lerp(outScale, outScale2, amount)

		invRotation := 1 / inRotation
		invTranslation := rl.Vector3RotateByQuaternion(-inTranslation, invRotation)
		invScale := vec3{1.0, 1.0, 1.0} / inScale

		boneTranslation :=
			rl.Vector3RotateByQuaternion(outScale * invTranslation, outRotation) + outTranslation

		boneRotation := outRotation * invRotation
		boneScale := outScale * invScale

		// C and Odin Matrix multipy are reversed! at least the rl.Matrimultiply - it's flipped from the origianl
		boneMatrix :=
			rl.MatrixScale(boneScale.x, boneScale.y, boneScale.z) *
			(rl.MatrixTranslate(boneTranslation.x, boneTranslation.y, boneTranslation.z) *
					rl.QuaternionToMatrix(boneRotation)) // new
		model.meshes[firstMeshWithBones].boneMatrices[boneId] = boneMatrix
	}

	if firstMeshWithBones != -1 {
		// Update remaining meshes with bones
		for ii := firstMeshWithBones + 1; ii < model.meshCount; ii += 1 {
			if model.meshes[ii].boneMatrices != nil {
				size := model.meshes[ii].boneCount * size_of(model.meshes[ii].boneMatrices[0])
				intrinsics.mem_copy(
					model.meshes[ii].boneMatrices,
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
	fmt.println("Animation: ", path)

	anim := AnimationSet{}
	animations: [^]rl.ModelAnimation = nil
	m3d_t: ^m3d.m3d_t = nil

	data_size: i32
	file_data := rl.LoadFileData(path, &data_size)
	msg := fmt.tprint("File data is nil, could not load m3d animations", path)
	assert(file_data != nil, msg)
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
		fmt.println(m3d_t.action[a].name)
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
