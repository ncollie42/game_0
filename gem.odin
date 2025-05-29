package main

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
		spawn := getRandomPoint()
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
			player.attack.current += 2
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
