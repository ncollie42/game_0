package main

import "core:fmt"
import "core:math/ease"
import rl "vendor:raylib"


Gems :: struct {
	// Actions -> 1. Get charges for attack, 2. Get health 3. XP 4. Gem for abilities?
	// state : idle | picking up | spawing
	range: f32,
	model: rl.Model,
	gems:  [dynamic]Spacial,
}

initGems :: proc() -> Gems {
	modelPath: cstring = "resources/gems/base.m3d"
	texturePath: cstring = "resources/gems/base.png"
	model := loadModelWithTexture(modelPath, texturePath)

	return Gems{range = 10, model = model, gems = make([dynamic]Spacial, 0, 0)}
}

spawnGem :: proc(gems: ^Gems, pos: vec3) {
	gem := Spacial {
		pos = pos,
	}
	append(&gems.gems, gem)
}

updateGems :: proc(gems: ^Gems, player: ^Player) {
	if len(gems.gems) < 3 { 	// maybe move to waves later for better spawning mec
		spawn := getPointAtEdgeOfMap()
		// spawn := getRandomPoint()
		spawnGem(gems, spawn)
	}
	// Loop in reverse and swap with last element on remove
	#reverse for &gem, index in gems.gems {
		dist := gem.pos - player.pos
		if rl.Vector3LengthSqr(dist) >= gems.range do continue // TODO: make it ossolate up and down
		gem.pos += normalize((player.pos - gem.pos)) * 10 * getDelta()
		dist = gem.pos - player.pos
		if rl.Vector3LengthSqr(dist) <= 1 {
			unordered_remove(&gems.gems, index)
			// Do something
			// player.attack.current += player.attack.max
			player.mana.current += 2
		}
	}
}

drawGems :: proc(gems: ^Gems, camera: ^rl.Camera) {
	for gem in gems.gems {
		drawShadow(gems.model, gem, 1, camera)
		black := vec4{0, 0, 0, 1}
		ss := gem
		ss.pos += {0, 1, 0}
		drawOutline(gems.model, ss, 1, camera, black)
		rl.DrawModel(gems.model, ss.pos, 1, rl.WHITE)
	}
}

// --------------------
Item :: struct {
	spacial: Spacial,
	expire:  f32,
	state:   enum {
		SPAWNING,
		IDlE,
		PICKUP,
	},
	dir:     vec3, // fall dir
	// Item type?
	// Action
}

Pickup :: struct {
	range: f32,
	model: rl.Model,
	items: [dynamic]Item, // change to items
}

initPickup :: proc() -> Pickup {
	modelPath: cstring = "resources/gems/base.m3d"
	texturePath: cstring = "resources/gems/base.png"
	model := loadModelWithTexture(modelPath, texturePath)

	return Pickup{range = 10, model = model, items = make([dynamic]Item, 0, 0)}
}

spawnPickup :: proc(pickup: ^Pickup, pos: vec3, dir: vec3) { 	// Dir
	item := Item{Spacial{pos = pos}, pickupSpawn, .SPAWNING, dir}
	append(&pickup.items, item)
}

pickupSpawn: f32 = .75 // spawn durration
updatePickup :: proc(pickup: ^Pickup, player: ^Player) {
	#reverse for &item, index in pickup.items {
		item.expire -= getDelta()
		switch item.state {
		case .SPAWNING:
			remap := rl.Remap(item.expire, pickupSpawn, 0, 1, 0)
			amount := ease.ease(.Elastic_In, remap) * 50 // [0,1]
			item.spacial.pos += item.dir * getDelta() * amount

			if item.expire >= 0 do continue
			item.expire = 5
			item.state = .IDlE
		case .IDlE:
			// TODO: make it ossolate up and down
			if item.expire <= 0 {
				unordered_remove(&pickup.items, index)
			}
			dist := item.spacial.pos - player.pos
			if rl.Vector3LengthSqr(dist) >= pickup.range do continue
			item.state = .PICKUP
			item.expire = 1
		case .PICKUP:
			amount := ease.ease(.Back_In_Out, item.expire) * 10 // [0,1]
			item.spacial.pos += normalize((player.pos - item.spacial.pos)) * getDelta() * amount

			dist := item.spacial.pos - player.pos
			if rl.Vector3LengthSqr(dist) <= 1 {
				unordered_remove(&pickup.items, index)
				// Do something
				// player.attack.current += player.attack.max
				player.mana.current += 1
			}
		}
	}

}

drawPickup :: proc(pickup: ^Pickup, camera: ^rl.Camera) {
	for item in pickup.items {
		// ss := item.spacial
		// ss.pos += {0, 1, 0}
		// rl.DrawSphere(ss.pos, .25, rl.WHITE)

		drawShadow(pickup.model, item.spacial, 1, camera)
		black := vec4{0, 0, 0, 1}
		ss := item.spacial
		ss.pos += {0, 1, 0}
		drawOutline(pickup.model, ss, 1, camera, black)
		rl.DrawModel(pickup.model, ss.pos, 1, rl.BLUE)
	}
}
