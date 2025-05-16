package main

import rl "vendor:raylib"

Gem :: struct {
	spacial: Spacial,
}

Gems :: struct {
	model: rl.Model,
	gems:  [dynamic]Gem,
}

initGems :: proc() -> Gems {
	modelPath: cstring = "resources/gems/base.m3d"
	texturePath: cstring = "resources/gems/base.png"
	model := loadModelWithTexture(modelPath, texturePath)

	return Gems{model = model, gems = make([dynamic]Gem, 0, 0)}
}

spawnGem :: proc(gems: ^Gems, pos: vec3) {
	gem := Gem{Spacial{pos = pos}}
	append(&gems.gems, gem)
}

updateGems :: proc() {

}

drawGems :: proc(gems: ^Gems, camera: ^rl.Camera) {
	for gem in gems.gems {
		drawShadow(gems.model, gem.spacial, 1, camera)
		rl.DrawModel(gems.model, gem.spacial.pos + {0, 1, 0}, 1, rl.WHITE)
		// rl.DrawCube(gem.spacial.pos, 1, 1, 1, rl.WHITE)
	}
}
