package main

stat :: struct {
	// hp
	Maxhealth:  f32,
	Regen:      f32,
	Armor:      f32, // Flat amount block? -> % of damage block.
	MagicArmor: f32,
	// Dmg
	Physical:   f32, // 10
	P_Crit:     f32, //[0,1] - 5%
	Magic:      f32, // 10
	M_Crit:     f32, //[0,1] - 5%
	CritDamage: f32, //[0,1] - 50%
	// MOVE_SPEED
	ManaRegen:  f32,
}

Stats :: struct {
	Physical:   f32, // 10
	P_Crit:     f32, //[0,1] - 5%
	Magic:      f32, // 10
	M_Crit:     f32, //[0,1] - 5%
	CritDamage: f32, //[0,1] - 50%
}

newPlayerStats :: proc() -> Stats {
	return Stats{Physical = 2, P_Crit = .05, Magic = 2, M_Crit = .05, CritDamage = .5}
}
