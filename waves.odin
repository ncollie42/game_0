package main

import "core:fmt"
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
waves2 := []wave {
	{enemies = {.Monolith}, spawnRate = .1, waveDuration = 1},
	{enemies = {.Thorn}, spawnRate = .1, waveDuration = 1},
	{enemies = {.Mele}, spawnRate = 2, waveDuration = 6},
	{enemies = {.Thorn}, spawnRate = .1, waveDuration = 1},
	{enemies = {.Range}, spawnRate = 2, waveDuration = 6},
	{enemies = {.Monolith}, spawnRate = .1, waveDuration = 1},
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
	spawnRandomEnemy(game, w.enemies)
}

wave :: struct {
	enemies:      []EnemyType,
	spawnRate:    f32,
	waveDuration: f32,
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

spawnRandomEnemy :: proc(game: ^Game, enemies: []EnemyType) {
	if len(enemies) <= 0 {
		return
	}
	index := rl.GetRandomValue(0, i32(len(enemies) - 1))
	// spawn := pointAtEdgeOfMap()
	spawn := getSafePointInGrid(&game.enemies)
	switch enemies[index] {
	case .Mele:
		spawnEnemy(&game.enemies, spawn, .Mele)
		spawnEnemy(&game.enemies, spawn, .Mele)
	// spawnEnemyMele(&game.enemies, spawn)
	// spawnEnemyMele(&game.enemies, spawn)
	case .Range:
		spawnEnemy(&game.enemies, spawn, .Range)
	// spawnEnemyRange(&game.enemies, spawn)
	case .Dummy:
	// spawnEnemyMele(&game.enemies, spawn, giantStats * waveMultiplier)
	case .Giant:
	case .Thorn:
		// TODO: get spawn pattern
		spawnEnemy(&game.enemies, spawn, .Thorn)
	case .Monolith:
		// TODO: get spawn pattern
		spawnEnemy(&game.enemies, spawn, .Monolith)
	}
}
