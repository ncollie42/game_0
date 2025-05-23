package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "vendor:raylib"

// Part of blocking state, but needs to update outside of that state.
Block :: struct {
	current:               f32, // showing
	max:                   f32,
	timeSinceLastBlockHit: f32,
}


// Player isBlocking on ability hurt
doBlock :: proc(block: ^Block) {
	block.current -= 1
	block.timeSinceLastBlockHit = 0
}

updateBlock :: proc(block: ^Block) {
	block.timeSinceLastBlockHit += getDelta()
	if block.timeSinceLastBlockHit < 3 do return // Start recharge after X amount of time not being hit
	block.current += getDelta() * 1
	block.current = clamp(block.current, 0, block.max)
}

isBlocking :: proc(player: ^Player) -> bool {
	_, blocking := player.state.(playerStateBlocking)
	return blocking
}

// Break out of block if <= 0
// Check before going into block
canBlock :: proc(block: ^Block) -> bool {
	return block.current >= 1
}

// showing, max, pos, barwidth, height, 
drawBlockbar :: proc(block: Block, camera: ^rl.Camera, pos: vec3) {
	// TODO: - set width based on hp max
	width: f32 = healthBarWidth
	height: f32 = healthBareHeight
	pos2 := pos + {0, height / 2, 0} // buffer
	pos2 += {0, height, 0} // hight over health bar
	pos2 += {-width / 2, 0, 0} // Move All the way to the right
	pos2 += {height / 2, 0, 0} // center

	for charge in 0 ..< block.max {
		amount := math.max(0, math.min(1, block.current - f32(charge)))

		pos3 := pos2 + {height * 1.5 * charge, 0, 0}
		color := rl.BLACK
		if amount == 1 do color = rl.BLUE

		rl.DrawBillboardRec(camera^, whiteTexture, {}, pos3, {height, height}, color)
	}
}
