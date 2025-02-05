package main

import clay "clay-odin"
import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"
// All placement is relative, no absolute X/Y placement
// 20px bold 100% | 16px bold 100% | 14px reg 100% | 14px reg 65%

// Fonts 18,16,14
FONT_ID_BODY_14 :: 0
FONT_ID_BODY_16 :: 1
FONT_ID_BODY_20 :: 2

// light ness only
// Use ligher collor to highlight ;; more important
// 5% back ground, 15% selected, 100% primary
// tmp := rl.ColorFromHSV(222, .76, 1) //360, [0,1] [0,1]
// tmp2 := rl.ColorBrightness(tmp, rl.Remap(.1, 0, 1, -1, 1)) // [-1,1]
// tmp3 := rl.ColorBrightness(tmp, rl.Remap(.7, 0, 1, -1, 1)) // [-1,1]
// tmp4 := rl.ColorBrightness(tmp, rl.Remap(.9, 0, 1, -1, 1)) // [-1,1]

RED := rl.ColorFromHSV(0, 0, 1) //360, [0,1] [0,1]
tmp := rl.ColorFromHSV(0, 0, 1) //360, [0,1] [0,1]
tmp2 := rl.ColorBrightness(tmp, rl.Remap(.05, 0, 1, -1, 1)) // [-1,1]
tmp3 := rl.ColorBrightness(tmp, rl.Remap(.15, 0, 1, -1, 1)) // [-1,1]
tmp4 := rl.ColorBrightness(tmp, rl.Remap(.25, 0, 1, -1, 1)) // [-1,1]
tmp5 := rl.ColorBrightness(tmp, rl.Remap(.65, 0, 1, -1, 1)) // [-1,1] // Text
tmp6 := rl.ColorBrightness(tmp, rl.Remap(1, 0, 1, -1, 1)) // [-1,1]

light_05 := RaylibColorToClayColor(tmp2)
light_15 := RaylibColorToClayColor(tmp3)
light_25 := RaylibColorToClayColor(tmp4)
light_65 := RaylibColorToClayColor(tmp5)
light_100 := RaylibColorToClayColor(tmp6)

COLOR_RED := RaylibColorToClayColor(rl.RED)

COLOR_LIGHT :: clay.Color{244, 235, 230, 255}
COLOR_SELECTED :: clay.Color{244, 35, 230, 255}
COLOR_LIGHT_HOVER :: clay.Color{224, 215, 210, 255}

expand: clay.Sizing = {clay.SizingGrow({}), clay.SizingGrow({})}

childGap :: 8
uiCorners :: 8
borderThick :: 2

layoutRoot := clay.LayoutConfig {
	sizing          = expand,
	layoutDirection = .TOP_TO_BOTTOM,
	padding         = {childGap, childGap, childGap, childGap},
	childGap        = childGap,
}
layoutDebug := clay.LayoutConfig {
	sizing          = {clay.SizingFixed(300), clay.SizingGrow({})},
	layoutDirection = .TOP_TO_BOTTOM,
	padding         = {childGap, childGap, childGap, childGap},
	childGap        = childGap,
}
debugPannel := clay.RectangleElementConfig {
	color = light_05,
}

testPannel := clay.RectangleElementConfig {
	// color = {90, 90, 90, 180},
}


debugModeEnabled: bool = false

loadFont :: proc(fontId: u16, fontSize: u16, path: cstring) {
	font := rl.LoadFontEx(path, cast(i32)fontSize * 2, nil, 0)
	assert(font.glyphCount != 0, "Font loaded doesn't work or exsist")
	assert(font.texture.format != .UNKNOWN, "Font loaded doesn't work or exsist")

	raylibFonts[fontId] = RaylibFont {
		font   = font,
		fontId = cast(u16)fontId,
	}
	rl.SetTextureFilter(font.texture, rl.TextureFilter.TRILINEAR)
}

initClay :: proc() {
	// Must run after rl.InitWindow() for font loading
	minMemorySize: u32 = clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(arena, {cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()}, {})
	// fonts :: TODO: load Bold
	loadFont(FONT_ID_BODY_14, 14, "resources/fonts/Calistoga-Regular.ttf")
	loadFont(FONT_ID_BODY_16, 16, "resources/fonts/Calistoga-Regular.ttf")
	loadFont(FONT_ID_BODY_20, 20, "resources/fonts/Calistoga-Regular.ttf")
	clay.SetMeasureTextFunction(measureText)
}

clayFrameSetup :: proc() {
	// NOTE: Call before clay.BeginLayout()

	clay.SetPointerState(
		transmute(clay.Vector2)rl.GetMousePosition(),
		rl.IsMouseButtonDown(rl.MouseButton.LEFT),
	)
	clay.UpdateScrollContainers(
		false,
		transmute(clay.Vector2)rl.GetMouseWheelMoveV(),
		rl.GetFrameTime(),
	)

	clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})

	if (rl.IsKeyPressed(.MINUS)) {
		debugModeEnabled = !debugModeEnabled
		clay.SetDebugModeEnabled(debugModeEnabled)
	}
}


// --------------------- Widgets ------------------------------------------------------------------

uiText :: proc(text: string, size: enum {
		small,
		mid,
		large,
	}) {
	switch size {
	case .small:
		config := clay.TextConfig({fontId = FONT_ID_BODY_14, fontSize = 14, textColor = light_100})
		clay.Text(text, config)
	case .mid:
		config := clay.TextConfig({fontId = FONT_ID_BODY_16, fontSize = 16, textColor = light_100})
		clay.Text(text, config)
	case .large:
		config := clay.TextConfig({fontId = FONT_ID_BODY_20, fontSize = 20, textColor = light_100})
		clay.Text(text, config)
	}
}

devider :: proc() {
	if clay.UI(
		clay.Layout({sizing = {clay.SizingGrow({}), clay.SizingFixed(2)}}),
		// clay.Rectangle({color = light_05}),
		clay.Rectangle({color = light_15}),
	) {}
}

// Progress bar
playerHPBar :: proc(hp: Health) {
	amount := hp.showing / hp.max
	// Do we make it percent based or fixed size? width = clay.SizingFixed(250)

	if clay.UI(
		clay.Layout({sizing = {width = clay.SizingPercent(.8), height = clay.SizingFixed(40)}}),
		clay.BorderAllRadius({width = borderThick, color = light_100}, uiCorners),
	) {

		// Text
		if clay.UI(clay.Floating({offset = {-20, -8}, attachment = {parent = .CENTER_CENTER}})) {
			uiText(fmt.tprintf("%.0f/%.0f", hp.current, hp.max), .mid)
		}

		// Fill
		if clay.UI(
			clay.Layout(
				{sizing = {width = clay.SizingPercent(amount), height = clay.SizingGrow({})}},
			),
			clay.Rectangle({color = COLOR_RED, cornerRadius = clay.CornerRadiusAll(uiCorners)}),
		) {}
	}
}

// Progress bar stamina
staminaBar :: proc(showing: f32, max: f32) {
	for charge in 0 ..< max {
		amount := math.max(0, math.min(1, showing - f32(charge)))

		if clay.UI(
			clay.Layout({sizing = {width = clay.SizingPercent(1), height = clay.SizingFixed(10)}}),
		) {

			// Fill
			if clay.UI(
				clay.Layout(
					{sizing = {width = clay.SizingPercent(amount), height = clay.SizingGrow({})}},
				),
				clay.Rectangle({color = light_100}),
			) {}
		}
	}
}

debugEnemyHPBar :: proc(hp: Health) {
	// Do we make it percent based or fixed size? width = clay.SizingFixed(250)
	if clay.UI(
		clay.Layout({sizing = {width = clay.SizingPercent(.8), height = clay.SizingFixed(15)}}),
		clay.BorderAllRadius({width = borderThick, color = light_100}, uiCorners),
	) {

		// Text
		if clay.UI(clay.Floating({offset = {-20, -8}, attachment = {parent = .CENTER_CENTER}})) {
			uiText(fmt.tprintf("%.1f / %.1f", hp.current, hp.max), .mid)
		}

		percent := hp.showing / hp.max
		// Fill
		if clay.UI(
			clay.Layout(
				{sizing = {width = clay.SizingPercent(percent), height = clay.SizingGrow({})}},
			),
			clay.Rectangle({color = COLOR_RED, cornerRadius = clay.CornerRadiusAll(uiCorners)}),
		) {}
	}
}
// you can find the center of the screen by taking the width and then dividing it by two.
// You can then find the starting point of where you want to draw by subtracting half the width of the thing you want to draw from the center point of the screen


// --------------------- Raylib + Clay Render -----------------------------------------------------
RaylibFont :: struct {
	fontId: u16,
	font:   rl.Font,
}

clayColorToRaylibColor :: proc(color: clay.Color) -> rl.Color {
	return rl.Color{cast(u8)color.r, cast(u8)color.g, cast(u8)color.b, cast(u8)color.a}
}

RaylibColorToClayColor :: proc(color: rl.Color) -> clay.Color {
	return clay.Color{cast(f32)color.r, cast(f32)color.g, cast(f32)color.b, cast(f32)color.a}
}

raylibFonts := [10]RaylibFont{}

measureText :: proc "c" (text: ^clay.String, config: ^clay.TextElementConfig) -> clay.Dimensions {
	// Measure string size for Font
	textSize: clay.Dimensions = {0, 0}

	maxTextWidth: f32 = 0
	lineTextWidth: f32 = 0

	textHeight := cast(f32)config.fontSize
	fontToUse := raylibFonts[config.fontId].font

	for i in 0 ..< int(text.length) {
		if (text.chars[i] == '\n') {
			maxTextWidth = max(maxTextWidth, lineTextWidth)
			lineTextWidth = 0
			continue
		}
		index := cast(i32)text.chars[i] - 32
		if (fontToUse.glyphs[index].advanceX != 0) {
			lineTextWidth += cast(f32)fontToUse.glyphs[index].advanceX
		} else {
			lineTextWidth +=
				(fontToUse.recs[index].width + cast(f32)fontToUse.glyphs[index].offsetX)
		}
	}

	maxTextWidth = max(maxTextWidth, lineTextWidth)

	textSize.width = maxTextWidth / 2
	textSize.height = textHeight

	return textSize
}

clayRaylibRender :: proc(
	renderCommands: ^clay.ClayArray(clay.RenderCommand),
	allocator := context.temp_allocator,
) {
	for i in 0 ..< int(renderCommands.length) {
		renderCommand := clay.RenderCommandArray_Get(renderCommands, cast(i32)i)
		boundingBox := renderCommand.boundingBox
		switch (renderCommand.commandType) {
		case clay.RenderCommandType.None:
			{}
		case clay.RenderCommandType.Text:
			// Raylib uses standard C strings so isn't compatible with cheap slices, we need to clone the string to append null terminator
			text := string(renderCommand.text.chars[:renderCommand.text.length])
			cloned := strings.clone_to_cstring(text, allocator)
			fontToUse: rl.Font = raylibFonts[renderCommand.config.textElementConfig.fontId].font
			rl.DrawTextEx(
				fontToUse,
				cloned,
				rl.Vector2{boundingBox.x, boundingBox.y},
				cast(f32)renderCommand.config.textElementConfig.fontSize,
				cast(f32)renderCommand.config.textElementConfig.letterSpacing,
				clayColorToRaylibColor(renderCommand.config.textElementConfig.textColor),
			)
		case clay.RenderCommandType.Image:
			// TODO image handling
			imageTexture := cast(^rl.Texture2D)renderCommand.config.imageElementConfig.imageData
			rl.DrawTextureEx(
				imageTexture^,
				rl.Vector2{boundingBox.x, boundingBox.y},
				0,
				boundingBox.width / cast(f32)imageTexture.width,
				rl.WHITE,
			)
		case clay.RenderCommandType.ScissorStart:
			rl.BeginScissorMode(
				cast(i32)math.round(boundingBox.x),
				cast(i32)math.round(boundingBox.y),
				cast(i32)math.round(boundingBox.width),
				cast(i32)math.round(boundingBox.height),
			)
		case clay.RenderCommandType.ScissorEnd:
			rl.EndScissorMode()
		case clay.RenderCommandType.Rectangle:
			config: ^clay.RectangleElementConfig = renderCommand.config.rectangleElementConfig
			if (config.cornerRadius.topLeft > 0) {
				radius: f32 =
					(config.cornerRadius.topLeft * 2) / min(boundingBox.width, boundingBox.height)
				rl.DrawRectangleRounded(
					rl.Rectangle {
						boundingBox.x,
						boundingBox.y,
						boundingBox.width,
						boundingBox.height,
					},
					radius,
					8,
					clayColorToRaylibColor(config.color),
				)
			} else {
				rl.DrawRectangle(
					cast(i32)boundingBox.x,
					cast(i32)boundingBox.y,
					cast(i32)boundingBox.width,
					cast(i32)boundingBox.height,
					clayColorToRaylibColor(config.color),
				)
			}
		case clay.RenderCommandType.Border:
			config := renderCommand.config.borderElementConfig
			// Left border
			if (config.left.width > 0) {
				rl.DrawRectangle(
					cast(i32)math.round(boundingBox.x),
					cast(i32)math.round(boundingBox.y + config.cornerRadius.topLeft),
					cast(i32)config.left.width,
					cast(i32)math.round(
						boundingBox.height -
						config.cornerRadius.topLeft -
						config.cornerRadius.bottomLeft,
					),
					clayColorToRaylibColor(config.left.color),
				)
			}
			// Right border
			if (config.right.width > 0) {
				rl.DrawRectangle(
					cast(i32)math.round(
						boundingBox.x + boundingBox.width - cast(f32)config.right.width,
					),
					cast(i32)math.round(boundingBox.y + config.cornerRadius.topRight),
					cast(i32)config.right.width,
					cast(i32)math.round(
						boundingBox.height -
						config.cornerRadius.topRight -
						config.cornerRadius.bottomRight,
					),
					clayColorToRaylibColor(config.right.color),
				)
			}
			// Top border
			if (config.top.width > 0) {
				rl.DrawRectangle(
					cast(i32)math.round(boundingBox.x + config.cornerRadius.topLeft),
					cast(i32)math.round(boundingBox.y),
					cast(i32)math.round(
						boundingBox.width -
						config.cornerRadius.topLeft -
						config.cornerRadius.topRight,
					),
					cast(i32)config.top.width,
					clayColorToRaylibColor(config.top.color),
				)
			}
			// Bottom border
			if (config.bottom.width > 0) {
				rl.DrawRectangle(
					cast(i32)math.round(boundingBox.x + config.cornerRadius.bottomLeft),
					cast(i32)math.round(
						boundingBox.y + boundingBox.height - cast(f32)config.bottom.width,
					),
					cast(i32)math.round(
						boundingBox.width -
						config.cornerRadius.bottomLeft -
						config.cornerRadius.bottomRight,
					),
					cast(i32)config.bottom.width,
					clayColorToRaylibColor(config.bottom.color),
				)
			}
			if (config.cornerRadius.topLeft > 0) {
				rl.DrawRing(
					rl.Vector2 {
						math.round(boundingBox.x + config.cornerRadius.topLeft),
						math.round(boundingBox.y + config.cornerRadius.topLeft),
					},
					math.round(config.cornerRadius.topLeft - cast(f32)config.top.width),
					config.cornerRadius.topLeft,
					180,
					270,
					10,
					clayColorToRaylibColor(config.top.color),
				)
			}
			if (config.cornerRadius.topRight > 0) {
				rl.DrawRing(
					rl.Vector2 {
						math.round(
							boundingBox.x + boundingBox.width - config.cornerRadius.topRight,
						),
						math.round(boundingBox.y + config.cornerRadius.topRight),
					},
					math.round(config.cornerRadius.topRight - cast(f32)config.top.width),
					config.cornerRadius.topRight,
					270,
					360,
					10,
					clayColorToRaylibColor(config.top.color),
				)
			}
			if (config.cornerRadius.bottomLeft > 0) {
				rl.DrawRing(
					rl.Vector2 {
						math.round(boundingBox.x + config.cornerRadius.bottomLeft),
						math.round(
							boundingBox.y + boundingBox.height - config.cornerRadius.bottomLeft,
						),
					},
					math.round(config.cornerRadius.bottomLeft - cast(f32)config.top.width),
					config.cornerRadius.bottomLeft,
					90,
					180,
					10,
					clayColorToRaylibColor(config.bottom.color),
				)
			}
			if (config.cornerRadius.bottomRight > 0) {
				rl.DrawRing(
					rl.Vector2 {
						math.round(
							boundingBox.x + boundingBox.width - config.cornerRadius.bottomRight,
						),
						math.round(
							boundingBox.y + boundingBox.height - config.cornerRadius.bottomRight,
						),
					},
					math.round(config.cornerRadius.bottomRight - cast(f32)config.bottom.width),
					config.cornerRadius.bottomRight,
					0.1,
					90,
					10,
					clayColorToRaylibColor(config.bottom.color),
				)
			}
		case clay.RenderCommandType.Custom:
		// Implement custom element rendering here
		}
	}
}

// --------------------- Examples -----------------------------------------------------------------

buttonExample :: proc() -> bool {
	hovered := false
	if clay.UI(
		clay.Layout(clay.LayoutConfig{sizing = {clay.SizingFixed(50), clay.SizingGrow({})}}),
	) {
		if clay.UI(
			clay.Rectangle(
				{color = clay.Hovered() ? light_05 : light_15, cornerRadius = {10, 10, 10, 10}},
			),
			clay.Layout(clay.LayoutConfig{sizing = expand}),
		) {
			hovered = clay.Hovered()
		}
	}
	return hovered && rl.IsMouseButtonPressed(.LEFT)
}

// https://github.com/nicbarker/clay/blob/main/README.md
// 80% UI Design
// https://www.youtube.com/watch?v=9-oefwZ6Z74

button :: proc(text: string) -> bool {
	hovered := false
	if clay.UI() {
		if clay.UI(
			clay.Layout(clay.LayoutConfig{sizing = expand, padding = {16, 16, 8, 8}}),
			clay.Rectangle(
				{color = clay.Hovered() ? light_15 : light_05, cornerRadius = {5, 5, 5, 5}},
			),
		) {
			hovered = clay.Hovered()
			// clay.Text(text, textConfig())
		}
	}
	return hovered && rl.IsMouseButtonPressed(.LEFT)
}

button2 :: proc(text: string, selected: bool) -> bool {
	hovered := false
	if clay.UI(clay.Layout(clay.LayoutConfig{sizing = {width = clay.SizingGrow({})}})) {
		hovered = clay.Hovered()
		color := hovered ? light_25 : light_05
		if selected {
			color = light_15
		}
		if selected && hovered {
			color = light_100
		}
		if clay.UI(
			clay.Layout(clay.LayoutConfig{sizing = expand, padding = {16, 16, 8, 8}}),
			clay.Rectangle({color = color, cornerRadius = {5, 5, 5, 5}}),
		) {
			// clay.Text(text, textConfig())
		}
	}
	return hovered && rl.IsMouseButtonPressed(.LEFT)
}

dropDown :: proc(text: string) -> bool {
	hovered := false
	if clay.UI() {
		hovered = clay.Hovered()
		if clay.UI(
			clay.Layout(clay.LayoutConfig{sizing = expand, padding = {16, 16, 8, 8}}),
			clay.Rectangle(
				{color = clay.Hovered() ? light_05 : light_100, cornerRadius = {5, 5, 5, 5}},
			),
		) {
			// clay.Text(text, textConfig())

			dropdown := clay.GetElementId(clay.MakeString("dropDown")) // TODO: make new func
			dropdownHovered := clay.PointerOver(dropdown)
			if !hovered || dropdownHovered {
				return false
			}
			if clay.UI(
				clay.ID("dropDown"),
				clay.Floating(clay.FloatingElementConfig{attachment = {parent = .LEFT_BOTTOM}}),
			) {
				if clay.UI(
					clay.Layout(
						clay.LayoutConfig {
							sizing = {width = clay.SizingFixed(200)},
							layoutDirection = .TOP_TO_BOTTOM,
							padding = {16, 16, 16, 16},
						},
					),
					clay.Rectangle({color = light_05, cornerRadius = {5, 5, 5, 5}}),
				) {
					if clay.Hovered() {
					}
					// clay.Text("ONE", textConfig())
					// clay.Text("TWO", textConfig())
					// clay.Text("THREE", textConfig())
				}
			}
		}
	}
	return hovered && rl.IsMouseButtonPressed(.LEFT)
}
