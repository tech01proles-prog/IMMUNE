# Immune Empire: Internal Front — игровое состояние (autoload)
# UI только читает состояние и шлёт команды; вся логика в Simulation (принцип №2 архитектуры)
extends Node

signal state_changed

# Ресурсы MVP (7 шт., см. 10_MVP_DEVELOPMENT_PLAN.txt §1.2)
var res: Dictionary = {}
# Постройки: id -> уровень
var organs: Dictionary = {}
# Обученные клетки: id -> количество
var cells: Dictionary = {}
# Изученные технологии: id -> true
var techs: Dictionary = {}
# Метр воспаления 0..100 (единственный метр MVP, §1.7)
var inflammation: float = 0.0
# Активные инфекции: uid -> {id, amount, organ}
var infections: Dictionary = {}
var infection_uid: int = 0
# Журнал событий
var journal: PackedStringArray = PackedStringArray()
# Статистика / флаги разблокировок
var stats: Dictionary = {
	"outbreaks_cleared": 0,
	"total_cells_trained": 0,
	"cleared_kinds": {},       # kind -> кол-во побед (trained_immunity)
	"known_pathogens": {},     # id -> true (b_cell известность)
	"first_cell_trained": false,
	"first_atp": false,
	"first_macrophage": false,
	"first_dendritic": false,
	"first_outbreak_cleared": false,
}
# Престиж «Новый хозяин»
var prestige_points: int = 0
var prestige_count: int = 0
# Время игры для оффлайн-прогресса
var last_saved_real_ms: int = 0

func _ready() -> void:
	reset_run()

func reset_run(keep_prestige: bool = true) -> void:
	res = {
		"amino_acids": 30.0, "glucose": 20.0, "lipids": 5.0,
		"micronutrients": 5.0, "atp": 0.0, "stem_cells": 0.0, "antigens": 0.0,
	}
	organs = {"gut_villi": 1}
	cells = {}
	techs = {}
	inflammation = 0.0
	infections.clear()
	infection_uid = 0
	journal = PackedStringArray(["Империя пробуждается. Ворсинки кишечника уже работают."])
	var pp := prestige_points
	var pc := prestige_count
	stats = {
		"outbreaks_cleared": 0, "total_cells_trained": 0,
		"cleared_kinds": {}, "known_pathogens": {},
		"first_cell_trained": false, "first_atp": false,
		"first_macrophage": false, "first_dendritic": false,
		"first_outbreak_cleared": false,
	}
	if keep_prestige:
		prestige_points = pp
		prestige_count = pc
	state_changed.emit()

func log_line(text: String) -> void:
	journal.append(text)
	if journal.size() > 60:
		journal.remove_at(0)
	print("[Journal] ", text)

func has_tech(id: String) -> bool:
	return techs.has(id)

# Бонус престижа: +5% ко всему производству за очко
func prestige_mult() -> float:
	return 1.0 + 0.05 * float(prestige_points)
