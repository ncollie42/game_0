package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

// Make global?  or put into game obj. we're only going to have 1.
Waves := struct {
	duration:     f32,
	waveDuration: f32,
	tick:         Timer,
	waveTick:     Timer,
	state:        enum {
		ONE,
		TWO,
		THREE,
		LAST,
	},
} {
	tick = {max = 1},
	waveTick = {left = 5, max = 5},
}

wave :: struct {
	enemies:      []EnemyType,
	spawnRate:    f32,
	waveDuration: f32,
}

waves2 := []wave {
	{enemies = {.Monolith}, spawnRate = .001, waveDuration = .02},
	{enemies = {.Thorn}, spawnRate = .001, waveDuration = .02},
	{enemies = {.Mele}, spawnRate = 2, waveDuration = 6},
	{enemies = {.Thorn}, spawnRate = .1, waveDuration = 1},
	{enemies = {.Range}, spawnRate = 2, waveDuration = 6},
	{enemies = {}, spawnRate = 1, waveDuration = 30},
	{enemies = {.Thorn}, spawnRate = .5, waveDuration = 60},
	// {enemies = {.Monolith}, spawnRate = .1, waveDuration = 1},
	// {enemies = {}, spawnRate = 1, waveDuration = 5},
	// {enemies = {.Mele, .Range}, spawnRate = 1, waveDuration = 5},
	{enemies = {}, spawnRate = 1, waveDuration = 10000},
	{spawnRate = 1, waveDuration = 5}, // GAME OVER - We check on main if we're at the last wave.
}

spawnTick: Timer = {}
waveTick: Timer = {}
curWave := -1

initWaves :: proc() {
	spawnTick = {}
	waveTick = {}
	curWave = -1
	Waves.duration = 0
}

updateWaves :: proc(game: ^Game) {
	Waves.duration += rl.GetFrameTime()
	// Waves.waveDuration += rl.GetFrameTime()
	updateTimer(&Waves.tick)
	updateTimer(&Waves.waveTick)

	updateTimer(&spawnTick)
	updateTimer(&waveTick)
	if isTimerReady(waveTick) {
		curWave += 1
		waveTick.max = waves2[curWave].waveDuration
		startTimer(&waveTick)
	}
	w := waves2[curWave]
	if !isTimerReady(spawnTick) {
		return
	}
	spawnTick.max = waves2[curWave].spawnRate
	startTimer(&spawnTick)
	now := (curWave == 0 || curWave == 1) // For now, later spawn all map stuff first before wave starts
	spawnRandomEnemy(game, w.enemies, game.player, now)
}
// Scale based on how player is doing? hp + enemies out now
// Scale enemy stats based on wave
// Scale up stats based on current wave - Add {Stats on enemy spawn func}
// const difficultyMultiplier = 1 + (currentWave * 0.1); // 10% increase per wave
// enemy.health *= difficultyMultiplier;
// enemy.speed *= (1 + (currentWave c* 0.05)); // 5% speed increase per wave
EnemyType :: enum {
	Mele,
	Range,
	Dummy,
	Giant,
	Thorn,
	Monolith,
}

spawnRandomEnemy :: proc(game: ^Game, enemies: []EnemyType, player: ^Player, now: bool) {
	if len(enemies) <= 0 {
		return
	}
	index := rl.GetRandomValue(0, i32(len(enemies) - 1))

	// spawn := pointAtEdgeOfMap()
	spawn := getSafePointInGrid(&game.enemies, player)
	switch enemies[index] {
	case .Mele:
		spawnEnemy(&game.enemies, spawn, .Mele, now)
	case .Range:
		spawnEnemy(&game.enemies, spawn, .Range, now)
	case .Dummy:
	// spawnEnemyMele(&game.enemies, spawn, giantStats * waveMultiplier, now)
	case .Giant:
	case .Thorn:
		// TODO: get spawn pattern
		spawnEnemy(&game.enemies, spawn, .Thorn, now)
	case .Monolith:
		// TODO: get spawn pattern
		spawnEnemy(&game.enemies, spawn, .Monolith, now)
	}
}
