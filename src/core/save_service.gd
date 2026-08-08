class_name SaveService
extends RefCounted

const SAVE_VERSION := 1
const SLOT_COUNT := 3


static func save_slot(slot: int, state: GameStateModel) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {"ok": false, "message": "セーブスロットが不正です。"}
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"state": state.to_save_dict(),
	}
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "セーブファイルを開けませんでした。"}
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	return {"ok": true, "message": "スロット%dに保存しました。" % slot}


static func load_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {"ok": false, "message": "セーブスロットが不正です。"}
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "スロット%dは空です。" % slot}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "セーブファイルを開けませんでした。"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"ok": false, "message": "セーブデータが壊れています。"}
	var payload := parsed as Dictionary
	if int(payload.get("version", 0)) != SAVE_VERSION or not payload.get("state", {}) is Dictionary:
		return {"ok": false, "message": "未対応のセーブデータです。"}
	return {"ok": true, "message": "ロードしました。", "data": (payload["state"] as Dictionary)}


static func get_slot_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		var result := load_slot(slot)
		if not bool(result.get("ok", false)):
			summaries.append({"slot": slot, "empty": true})
			continue
		var state: Dictionary = result.get("data", {})
		var hero: Dictionary = state.get("hero", {})
		summaries.append({
			"slot": slot,
			"empty": false,
			"level": int(hero.get("level", 1)),
			"map_name": GameDatabase.get_map_name(str(state.get("map_id", "town"))),
			"play_time": int(float(state.get("play_time_seconds", 0.0))),
		})
	return summaries


static func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot
