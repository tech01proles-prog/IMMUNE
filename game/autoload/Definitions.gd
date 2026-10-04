# Immune Empire: Internal Front — определения контента (autoload)
# Файл данных загружается из res://data/*.json (принцип data-driven из 07_GODOT_PROJECT_ARCHITECTURE.txt)
extends Node

var resources: Dictionary = {}
var organs: Dictionary = {}
var cells: Dictionary = {}
var pathogens: Dictionary = {}
var technologies: Dictionary = {}

const SAVE_VERSION := 1

func _ready() -> void:
	resources = _load_json("res://data/resources.json")
	organs = _load_json("res://data/organs.json")
	cells = _load_json("res://data/cells.json")
	pathogens = _load_json("res://data/pathogens.json")
	technologies = _load_json("res://data/technologies.json")

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Bad JSON: " + path)
		return {}
	return parsed

# Стоимость уровня постройки с экспоненциальным ростом
func organ_cost(id: String, level: int) -> Dictionary:
	var d: Dictionary = organs[id]
	var out := {}
	for k in d.base_cost:
		out[k] = ceil(d.base_cost[k] * pow(d.growth, level))
	return out

func cell_cost(id: String, count: int) -> Dictionary:
	var d: Dictionary = cells[id]
	var out := {}
	for k in d.base_cost:
		out[k] = ceil(d.base_cost[k] * pow(d.cost_growth, count))
	return out

func format_amount(v: float) -> String:
	if v >= 1000000.0: return "%.2fM" % (v / 1000000.0)
	if v >= 1000.0: return "%.1fk" % (v / 1000.0)
	if v >= 100.0: return "%.0f" % v
	if v >= 10.0: return "%.1f" % v
	return "%.2f" % v
