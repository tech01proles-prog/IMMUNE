# Save/Load с версионированием и оффлайн-прогрессом (принципы №5, offline system)
extends Node

const SAVE_PATH := "user://immune_empire_save.json"

func save_game() -> void:
	GameState.last_saved_real_ms = Time.get_unix_time_from_system() * 1000
	var data := {
		version = Definitions.SAVE_VERSION,
		res = GameState.res,
		organs = GameState.organs,
		cells = GameState.cells,
		techs = GameState.techs,
		inflammation = GameState.inflammation,
		infections = GameState.infections,
		infection_uid = GameState.infection_uid,
		stats = GameState.stats,
		prestige_points = GameState.prestige_points,
		prestige_count = GameState.prestige_count,
		last_saved_real_ms = GameState.last_saved_real_ms,
		journal = Array(GameState.journal),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	# Миграция сохранений (версия)
	if int(parsed.get("version", 0)) < Definitions.SAVE_VERSION:
		parsed = _migrate(parsed)
	GameState.res = parsed.get("res", GameState.res)
	GameState.organs = parsed.get("organs", {"gut_villi": 1})
	GameState.cells = parsed.get("cells", {})
	GameState.techs = parsed.get("techs", {})
	GameState.inflammation = parsed.get("inflammation", 0.0)
	GameState.infections = parsed.get("infections", {})
	GameState.infection_uid = parsed.get("infection_uid", 0)
	GameState.stats = parsed.get("stats", GameState.stats)
	GameState.prestige_points = parsed.get("prestige_points", 0)
	GameState.prestige_count = parsed.get("prestige_count", 0)
	GameState.last_saved_real_ms = parsed.get("last_saved_real_ms", 0)
	var j: Array = parsed.get("journal", [])
	GameState.journal = PackedStringArray(j)
	# Оффлайн-прогресс
	var now_ms := Time.get_unix_time_from_system() * 1000
	var elapsed := (now_ms - float(GameState.last_saved_real_ms)) / 1000.0
	if elapsed > 60.0:
		var summary := Simulation.apply_offline(elapsed)
		if summary != "":
			GameState.log_line(summary.replace("\n", " | "))
			Simulation.toast.emit(summary.split("\n")[0])
	return true

func _migrate(data: Dictionary) -> Dictionary:
	# Заготовки под будущие версии: сюда добавляем шаги 1->2, 2->3 ...
	data.version = Definitions.SAVE_VERSION
	return data

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
