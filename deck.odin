package main

import clay "clay-odin"
import "core:fmt"
import rl "vendor:raylib"

// Should we move hand into here too?
Deck :: struct {
	discard: [dynamic]AbilityConfig,
	free:    [dynamic]AbilityConfig,
	tick:    Timer,
}

updateDeck :: proc(deck: ^Deck, hand: ^[HandAction]AbilityConfig) {
	if !tickTimer(&deck.tick) do return

	if len(deck.free) == 0 do return
	config := pop(&deck.free)

	fmt.println("Deck Tick", len(deck.free), len(deck.discard))
	// On Tick
	//  -> new ability to the hand if available
	// If len(Free) == 0
	//  -> Move all Discard to free
	// How do we want to Show and make it satisfying? We can't deplay game play
	// 
	if !hasFreeSlot(hand^) do return
	slot := getFreeSlot(hand^)
	fmt.println("Adding, ", slot)
	if slot == .Nil {
		// Do we want to panic? should not give this option of we can't select? or we allow to overwride?
		panic("Don't know how to handle not option yet")
	}
	hand[slot] = config
}

drawDeckUI :: proc(deck: ^Deck) {
	// Rec With a card number And a Number and a CD for card draw
	layoutOuter := clay.LayoutConfig {
		sizing          = expand,
		padding         = {0, 0, 0, 0},
		childGap        = childGap,
		childAlignment  = {.CENTER, .BOTTOM},
		layoutDirection = .LEFT_TO_RIGHT,
	}

	// TODO: move to constants -> used in hand too 
	size: f32 = 64 * .75
	layout := clay.LayoutConfig {
		sizing = {width = clay.SizingFixed(size), height = clay.SizingFixed(size)},
		padding = {0, 0, 0, 0},
		childGap = 0,
		childAlignment = {.CENTER, .CENTER},
		layoutDirection = .TOP_TO_BOTTOM,
	}
	// Deck Free
	if clay.UI(
		clay.ID("deck_free"),
		clay.Layout(layout),
		clay.BorderAll({width = borderThick, color = light_100}),
		clay.Rectangle(testPannel),
	) {
		percent := timerPercent(deck.tick)
		coverLayout := clay.LayoutConfig {
			sizing = {width = clay.SizingFixed(size), height = clay.SizingPercent(percent)},
			padding = {8, 8, 8, 8},
			childGap = 8,
		}
		cover := clay.RectangleElementConfig {
			color = {0, 0, 0, 255 * .8},
		}
		if percent > 0 {
			if clay.UI(
				clay.Layout(coverLayout),
				clay.Rectangle(cover),
				clay.BorderBottomOnly({width = borderThick, color = light_100}),
			) {
			}
			floating := clay.FloatingElementConfig {
				attachment = clay.FloatingAttachPoints {
					element = .CENTER_CENTER,
					parent = .CENTER_CENTER,
				},
				pointerCaptureMode = .PASSTHROUGH,
			}
			if clay.UI(clay.Floating(floating)) {
				uiText("TEST", .large)
			}
		}
	}
}
