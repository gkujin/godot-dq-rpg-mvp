class_name RogueDatabase
extends RefCounted

const MAX_FLOOR := 5
const INVENTORY_LIMIT := 8

const FLOOR_NAMES := [
	"忘れられた入口",
	"苔むす回廊",
	"沈黙の坑道",
	"灰の祭殿",
	"深淵の王座",
]

const POTION_IDS := ["healing", "strength", "mist", "venom"]
const POTION_APPEARANCES := ["紅い薬瓶", "蒼い薬瓶", "琥珀の薬瓶", "翠の薬瓶"]

const ENEMIES := {
	"cave_rat": {
		"name": "洞窟ネズミ",
		"hp": 8,
		"attack": 4,
		"defense": 0,
		"xp": 5,
		"ai": "swift",
		"color": Color("c78d58"),
	},
	"mire_ooze": {
		"name": "泥のスライム",
		"hp": 14,
		"attack": 4,
		"defense": 2,
		"xp": 7,
		"ai": "slow",
		"color": Color("6fbd72"),
	},
	"venom_spider": {
		"name": "毒牙グモ",
		"hp": 11,
		"attack": 6,
		"defense": 1,
		"xp": 9,
		"ai": "venom",
		"color": Color("aa72d8"),
	},
	"bone_warden": {
		"name": "骨の衛兵",
		"hp": 19,
		"attack": 7,
		"defense": 3,
		"xp": 12,
		"ai": "guard",
		"color": Color("d9d2ba"),
	},
	"ember_eye": {
		"name": "熾火の眼",
		"hp": 16,
		"attack": 8,
		"defense": 1,
		"xp": 14,
		"ai": "ranged",
		"color": Color("ef7b55"),
	},
	"abyss_keeper": {
		"name": "深淵の番人ヴォルグ",
		"hp": 72,
		"attack": 11,
		"defense": 4,
		"xp": 60,
		"ai": "boss",
		"color": Color("e05a68"),
		"boss": true,
	},
}


static func floor_name(floor_number: int) -> String:
	var index := clampi(floor_number - 1, 0, FLOOR_NAMES.size() - 1)
	return str(FLOOR_NAMES[index])


static func make_enemy(enemy_id: String, position: Vector2i, floor_number: int, rng: RandomNumberGenerator) -> Dictionary:
	var definition: Dictionary = ENEMIES.get(enemy_id, ENEMIES["cave_rat"])
	var depth_bonus: int = maxi(0, floor_number - 1)
	var hp: int = int(definition.get("hp", 8)) + depth_bonus * 3
	if bool(definition.get("boss", false)):
		hp += depth_bonus * 4
	return {
		"id": enemy_id,
		"name": str(definition.get("name", enemy_id)),
		"pos": position,
		"hp": hp,
		"max_hp": hp,
		"attack": int(definition.get("attack", 3)) + depth_bonus,
		"defense": int(definition.get("defense", 0)) + floori(depth_bonus / 2.0),
		"xp": int(definition.get("xp", 4)) + depth_bonus * 2,
		"ai": str(definition.get("ai", "chase")),
		"color": definition.get("color", Color.WHITE),
		"boss": bool(definition.get("boss", false)),
		"alerted": false,
		"phase": rng.randi_range(0, 2),
	}


static func random_enemy_id(floor_number: int, rng: RandomNumberGenerator) -> String:
	var pool: Array[String] = []
	match floor_number:
		1:
			pool = ["cave_rat", "cave_rat", "mire_ooze"]
		2:
			pool = ["cave_rat", "mire_ooze", "venom_spider"]
		3:
			pool = ["mire_ooze", "venom_spider", "bone_warden"]
		4:
			pool = ["venom_spider", "bone_warden", "ember_eye"]
		_:
			pool = ["bone_warden", "ember_eye"]
	return pool[rng.randi_range(0, pool.size() - 1)]


static func starter_weapon() -> Dictionary:
	return {
		"kind": "weapon",
		"id": "worn_blade",
		"name": "欠けた短剣",
		"power": 1,
		"upgrade": 0,
		"color": Color("b8c0cc"),
	}


static func starter_armor() -> Dictionary:
	return {
		"kind": "armor",
		"id": "patched_coat",
		"name": "継ぎはぎの外套",
		"power": 1,
		"upgrade": 0,
		"color": Color("9b7a62"),
	}


static func make_loot(floor_number: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randi_range(0, 99)
	if roll < 29:
		var potion_id: String = POTION_IDS[rng.randi_range(0, POTION_IDS.size() - 1)]
		return {
			"kind": "potion",
			"id": potion_id,
			"name": potion_true_name(potion_id),
			"color": potion_color(potion_id),
		}
	if roll < 47:
		return {
			"kind": "food",
			"id": "ration",
			"name": "保存食",
			"power": 38,
			"color": Color("d9b56d"),
		}
	if roll < 59:
		return {
			"kind": "scroll",
			"id": "enchant",
			"name": "強化の巻物",
			"color": Color("f0dd9d"),
		}
	if roll < 68:
		return {
			"kind": "scroll",
			"id": "mapping",
			"name": "地図の巻物",
			"color": Color("a9d8e8"),
		}
	if roll < 84:
		return make_weapon(floor_number, rng)
	return make_armor(floor_number, rng)


static func make_weapon(floor_number: int, rng: RandomNumberGenerator) -> Dictionary:
	var tier := clampi(floor_number + rng.randi_range(-1, 1), 1, 5)
	var names := ["灰木の棍棒", "鉄の長剣", "月銀の槍", "黒曜の刃", "星喰らいの剣"]
	var colors := [Color("a77a52"), Color("c0c8d2"), Color("b6d7df"), Color("665d83"), Color("f2c968")]
	return {
		"kind": "weapon",
		"id": "weapon_%d" % tier,
		"name": names[tier - 1],
		"power": 1 + tier * 2,
		"upgrade": 0,
		"color": colors[tier - 1],
	}


static func make_armor(floor_number: int, rng: RandomNumberGenerator) -> Dictionary:
	var tier := clampi(floor_number + rng.randi_range(-1, 1), 1, 5)
	var names := ["革の上着", "鎖の胴衣", "鱗の鎧", "影縫いの鎧", "暁の重鎧"]
	var colors := [Color("a98260"), Color("aeb6bd"), Color("6d9b98"), Color("635c78"), Color("d9b85f")]
	return {
		"kind": "armor",
		"id": "armor_%d" % tier,
		"name": names[tier - 1],
		"power": tier + floori(tier / 2.0),
		"upgrade": 0,
		"color": colors[tier - 1],
	}


static func potion_true_name(potion_id: String) -> String:
	match potion_id:
		"healing":
			return "治癒の薬"
		"strength":
			return "剛力の薬"
		"mist":
			return "霧渡りの薬"
		"venom":
			return "毒の薬"
		_:
			return "奇妙な薬"


static func potion_color(potion_id: String) -> Color:
	match potion_id:
		"healing":
			return Color("e85b6a")
		"strength":
			return Color("f0b44d")
		"mist":
			return Color("64b9dc")
		"venom":
			return Color("74c768")
		_:
			return Color.WHITE


static func display_item_name(item: Dictionary, identified_potions: Array, potion_aliases: Dictionary) -> String:
	if str(item.get("kind", "")) == "potion":
		var potion_id := str(item.get("id", ""))
		if potion_id not in identified_potions:
			return str(potion_aliases.get(potion_id, "謎の薬瓶")) + "（未鑑定）"
	var upgrade := int(item.get("upgrade", 0))
	var suffix := " +%d" % upgrade if upgrade > 0 else ""
	return str(item.get("name", "不明な品")) + suffix


static func item_description(item: Dictionary, identified_potions: Array, potion_aliases: Dictionary) -> String:
	var kind := str(item.get("kind", ""))
	if kind == "potion" and str(item.get("id", "")) not in identified_potions:
		return "飲むまで効果はわからない。"
	match kind:
		"potion":
			match str(item.get("id", "")):
				"healing": return "HPを大きく回復する。"
				"strength": return "この冒険中、攻撃力を1上げる。"
				"mist": return "同じ階の別の部屋へ転移する。"
				"venom": return "飲むと毒を受ける危険な薬。"
		"food":
			return "空腹を38回復する。"
		"scroll":
			return "装備を強化する。" if str(item.get("id")) == "enchant" else "階全体の地形を明らかにする。"
		"weapon":
			return "攻撃 +%d" % (int(item.get("power", 0)) + int(item.get("upgrade", 0)))
		"armor":
			return "防御 +%d" % (int(item.get("power", 0)) + int(item.get("upgrade", 0)))
	return "用途はまだわからない。"
