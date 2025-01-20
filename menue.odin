package main

import clay "/clay-odin"
import "core:fmt"
import rl "vendor:raylib"


layoutRoot2 := clay.LayoutConfig {
	sizing          = expand,
	layoutDirection = .TOP_TO_BOTTOM,
	padding         = {childGap, childGap, childGap, childGap},
	childGap        = childGap,
	childAlignment  = {.CENTER, .CENTER},
}

drawMainMemu :: proc(app: ^App, game: ^Game) {
	// TODO: Pass in closures for button actions?

	clayFrameSetup()
	clay.BeginLayout()
	defer {
		layout := clay.EndLayout()
		clayRaylibRender(&layout)
	}

	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot2)) {
		uiText("HELLO", .large)

		if buttonText("START") {
			app^ = .PLAYING
			resetGame(game)
		}

	}
}

drawPostGameStats :: proc(app: ^App, game: ^Game) {
	// TODO: Pass in closures for button actions?

	clayFrameSetup()
	clay.BeginLayout()
	defer {
		layout := clay.EndLayout()
		clayRaylibRender(&layout)
	}

	if clay.UI(clay.ID("root"), clay.Layout(layoutRoot2)) {
		uiText("Game Over", .large)

		if buttonText("End") {
			app^ = .HOME
			resetGame(game)
		}

	}
}

buttonText :: proc(text: string) -> bool {
	hovered := false
	if clay.UI() {
		if clay.UI(
			clay.Layout(clay.LayoutConfig{sizing = expand, padding = {16, 16, 8, 8}}),
			clay.Rectangle(
				{color = clay.Hovered() ? light_15 : light_05, cornerRadius = {5, 5, 5, 5}},
			),
		) {
			hovered = clay.Hovered()
			uiText(text, .large)
		}
	}
	return hovered && rl.IsMouseButtonPressed(.LEFT)
}
