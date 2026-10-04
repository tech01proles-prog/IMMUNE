# Immune Empire: Internal Front — ядро симуляции (autoload)
# Fixed-step simulation + accumulator (принцип №3 архитектуры).
# Симуляция не зависит от видимых узлов; UI лишь читает GameState и вызывает команды.
extends Node

const STEP := 0.25            # 4 Гц логики — стабильно и легко для оффлайн-прогресса
var _acc: float = 0.0
var _spawn_timer: float = 8.0 # первая инфекция через ~15-25 сек (рандом)
var time_played: float = 0.0

signal toast(text: String)

func _process(delta: float) -> void:
	_acc += delta
	# Ограничение на догоняющие шаги, чтобы фоновые вкладки не зависали
	var guard := 0
	while _acc >= STEP and guard < 40:
		_step(STEP)
		_acc -= STEP
		guard += 1
	if guard >= 40:
		_acc = 0.0

# ---------- Основной шаг ----------
func _step(dt: float) -> void:
	time_played += dt
	_run_production(dt)
	_run_upkeep(dt)
	_run_inflammation(dt)
	_run_infections(dt)
	_try_spawn_infection(dt)
	_check_unlocks()

# ---------- Производство ----------
func _run_production(dt: float) -> void:
	var pm: float = GameState.prestige_mult()
	for id in GameState.organs:
		var lvl: int = GameState.organs[id]
		var d: Dictionary = Definitions.organs[id]
		# потребление
		var can_run := true
		for k in d.consumption:
			if GameState.res[k] < d.consumption[k] * lvl * dt:
				can_run = false
		if not can_run:
			continue
		for k in d.consumption:
			GameState.res[k] -= d.consumption[k] * lvl * dt
		# выпуск
		for k in d.output:
			GameState.res[k] += d.output[k] * lvl * dt * pm
	# Технологии на энергию
	var atp_bonus: float = 1.0
	if GameState.has_tech("glycolytic_flux"): atp_bonus += 0.10
	if GameState.has_tech("mitochondrial_biogenesis"): atp_bonus += 0.15
	if absf(atp_bonus - 1.0) > 0.001 and GameState.organs.get("mitochondrial_network", 0) > 0:
		var extra := 0.4 * GameState.organs["mitochondrial_network"] * dt * pm * (atp_bonus - 1.0)
		GameState.res.atp += extra
	if GameState.res.atp > 0.5:
		GameState.stats.first_atp = true

# ---------- Содержание клеток ----------
func _run_upkeep(dt: float) -> void:
	var need: float = 0.0
	for id in GameState.cells:
		need += Definitions.cells[id].upkeep_atp * GameState.cells[id] * dt
	if GameState.res.atp >= need:
		GameState.res.atp -= need
	else:
		# Голод армии: клетки гибнут постепенно (soft failure, без game over)
		GameState.res.atp = 0.0
		var starving: Array = GameState.cells.keys()
		if starving.size() > 0:
			var pick: String = starving[randi() % starving.size()]
			GameState.cells[pick] -= 1
			if GameState.cells[pick] <= 0:
				GameState.cells.erase(pick)
			toast.emit("Армия голодает! Потерян " + Definitions.cells[pick].name_ru)

# ---------- Воспаление ----------
func _run_inflammation(dt: float) -> void:
	var inflow: float = 0.0
	for id in GameState.cells:
		inflow += Definitions.cells[id].inflammation * GameState.cells[id]
	for uid in GameState.infections:
		inflow += clampf(GameState.infections[uid].amount / 40.0, 0.0, 0.5)
	GameState.inflammation += inflow * dt
	# Спад
	var decay: float = 0.02
	if GameState.has_tech("resolution_mediators"): decay *= 1.5
	GameState.inflammation -= decay * dt * maxf(1.0, GameState.organs.get("liver", 0))
	GameState.inflammation = clampf(GameState.inflammation, 0.0, 100.0)
	# Штраф за воспаление: -урон производства при >60 (мягкая деградация)
	if GameState.inflammation > 60.0:
		var dmg_scale := (GameState.inflammation - 60.0) / 40.0 * 0.3
		var keys := ["amino_acids", "glucose", "lipids", "micronutrients"]
		var k: String = keys[randi() % keys.size()]
		GameState.res[k] = maxf(0.0, GameState.res[k] - GameState.res[k] * dmg_scale * dt * 0.1)

# ---------- Инфекции ----------
func _try_spawn_infection(dt: float) -> void:
	_spawn_timer -= dt
	if _spawn_timer > 0.0:
		return
	# Частота растёт с прогрессом
	_spawn_timer = randf_range(35.0, 70.0) / (1.0 + 0.15 * GameState.stats.outbreaks_cleared)
	if GameState.infections.size() >= 3:
		return
	var pool: Array = []
	for pid in Definitions.pathogens:
		var p: Dictionary = Definitions.pathogens[pid]
		if p.tier == 0 or GameState.stats.total_cells_trained >= 5:
			pool.append(pid)
	var pick: String = pool[randi() % pool.size()]
	GameState.infection_uid += 1
	GameState.infections[GameState.infection_uid] = {
		id = pick, amount = 5.0, organ = Definitions.pathogens[pick].kind
	}
	toast.emit("Вспышка: " + Definitions.pathogens[pick].name_ru + "!")
	GameState.log_line("Обнаружена инфекция: " + Definitions.pathogens[pick].name_ru)

func _run_infections(dt: float) -> void:
	var to_clear: Array = []
	for uid in GameState.infections:
		var inf: Dictionary = GameState.infections[uid]
		var pdata: Dictionary = Definitions.pathogens[inf.id]
		# Рост инфекции (замедляется барьерными техами)
		var growth := pdata.growth_rate
		if GameState.has_tech("mucus_production"): growth *= 0.9
		inf.amount += growth * inf.amount * dt * 0.1
		inf.amount = minf(inf.amount, pdata.threshold * 2.5)
		# Защита: суммарный эффективный урон по типу
		var dps: float = _defense_vs(pdata.kind)
		inf.amount -= dps * dt
		if inf.amount <= 0.1:
			to_clear.append(uid)
	for uid in to_clear:
		_clear_infection(uid)

func _defense_vs(kind: String) -> float:
	var total: float = 0.0
	for id in GameState.cells:
		var cd: Dictionary = Definitions.cells[id]
		var base: float = cd.defense.get(kind, 0.0) * GameState.cells[id]
		# Техи
		if id == "neutrophil" and GameState.has_tech("chemotaxis_1"): base *= 1.15
		if id == "macrophage" and kind == "bacteria" and GameState.has_tech("oxidative_burst_1"): base *= 1.2
		if kind == "virus" and GameState.has_tech("interferon_pathway"): base *= 1.25
		if kind == "bacteria" and GameState.has_tech("complement_cascade"): base *= 1.2
		if GameState.has_tech("trained_immunity") and GameState.stats.cleared_kinds.get(kind, 0) > 0:
			base *= 1.1
		# B-клетки сильнее против изученных патогенов
		total += base
	if GameState.has_tech("vaccine_slot_1"):
		total += 0.5
	return total

func _clear_infection(uid: int) -> void:
	var inf: Dictionary = GameState.infections[uid]
	GameState.infections.erase(uid)
	var pdata: Dictionary = Definitions.pathogens[inf.id]
	var pm: float = GameState.prestige_mult()
	var antigen_mult: float = 1.0
	if GameState.organs.get("lymph_node", 0) > 0: antigen_mult += 0.20
	if GameState.cells.get("dendritic_cell", 0) > 0: antigen_mult += 0.25
	if GameState.has_tech("antigen_presentation_1"): antigen_mult += 0.25
	if GameState.has_tech("antigen_archive"): antigen_mult += 0.05
	for k in pdata.reward:
		var v: float = pdata.reward[k]
		if k == "antigens": v *= antigen_mult
		GameState.res[k] += v * pm
	GameState.stats.outbreaks_cleared += 1
	GameState.stats.known_pathogens[inf.id] = true
	var kind: String = pdata.kind
	GameState.stats.cleared_kinds[kind] = GameState.stats.cleared_kinds.get(kind, 0) + 1
	GameState.stats.first_outbreak_cleared = true
	GameState.log_line("Инфекция «" + pdata.name_ru + "» побеждена. Трофеи собраны.")
	toast.emit("Инфекция побеждена: " + pdata.name_ru)

# ---------- Команды из UI ----------
func buy_organ(id: String) -> bool:
	var cost := Definitions.organ_cost(id, GameState.organs.get(id, 0))
	if not _can_afford(cost): return false
	_spend(cost)
	GameState.organs[id] = GameState.organs.get(id, 0) + 1
	GameState.log_line("Построен уровень " + str(GameState.organs[id]) + ": " + Definitions.organs[id].name_ru)
	return true

func train_cell(id: String) -> bool:
	var cost := Definitions.cell_cost(id, GameState.cells.get(id, 0))
	if id == "neutrophil" and GameState.has_tech("granulopoiesis_1"):
		for k in cost: cost[k] = ceil(cost[k] * 0.9)
	if (id == "b_cell" or id == "cytotoxic_t") and GameState.has_tech("clonal_expansion_1"):
		for k in cost: cost[k] = ceil(cost[k] * 0.9)
	if not _can_afford(cost): return false
	_spend(cost)
	GameState.cells[id] = GameState.cells.get(id, 0) + 1
	GameState.stats.total_cells_trained += 1
	GameState.stats.first_cell_trained = true
	if id == "macrophage": GameState.stats.first_macrophage = true
	if id == "dendritic_cell": GameState.stats.first_dendritic = true
	return true

func research_tech(id: String) -> bool:
	var t: Dictionary = Definitions.technologies[id]
	if GameState.has_tech(id): return false
	if not _can_afford(t.cost): return false
	_spend(t.cost)
	GameState.techs[id] = true
	GameState.log_line("Изучена технология: " + t.name_ru)
	toast.emit("Технология: " + t.name_ru)
	return true

func _can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if GameState.res[k] < cost[k]: return false
	return true

func _spend(cost: Dictionary) -> void:
	for k in cost:
		GameState.res[k] -= cost[k]

# ---------- Разблокировки (по условиям unlock из JSON) ----------
func is_organ_unlocked(id: String) -> bool:
	return _unlock_ok(Definitions.organs[id].unlock)

func is_cell_unlocked(id: String) -> bool:
	return _unlock_ok(Definitions.cells[id].unlock)

func is_tech_unlocked(id: String) -> bool:
	return _unlock_ok(Definitions.technologies[id].unlock)

func _unlock_ok(cond: String) -> bool:
	match cond:
		"start":
			return true
		"first_cell_trained":
			return GameState.stats.first_cell_trained
		"first_atp":
			return GameState.stats.first_atp
		"first_macrophage":
			return GameState.stats.first_macrophage
		"first_dendritic":
			return GameState.stats.first_dendritic
		"first_outbreak_cleared":
			return GameState.stats.first_outbreak_cleared
		"bone_marrow":
			return GameState.organs.get("bone_marrow", 0) > 0
		"macrophage":
			return GameState.cells.get("macrophage", 0) > 0
		"nk_cell":
			return GameState.cells.get("nk_cell", 0) > 0
		"dendritic_cell":
			return GameState.cells.get("dendritic_cell", 0) > 0
		"lymph_node":
			return GameState.organs.get("lymph_node", 0) > 0
		"liver":
			return GameState.organs.get("liver", 0) > 0
		"gut_villi":
			return GameState.organs.get("gut_villi", 0) > 0
		"mitochondrial_network":
			return GameState.organs.get("mitochondrial_network", 0) > 0
		"dendritic_cell_and_lymph_node":
			return GameState.cells.get("dendritic_cell", 0) > 0 and GameState.organs.get("lymph_node", 0) > 0
		"antigen_presentation_1":
			return GameState.has_tech("antigen_presentation_1")
		"glycolytic_flux":
			return GameState.has_tech("glycolytic_flux")
		"anti_inflammatory_signals":
			return GameState.has_tech("anti_inflammatory_signals")
		"antigen_archive":
			return GameState.has_tech("antigen_archive")
		_:
			return false

func _check_unlocks() -> void:
	pass # условия вычисляются лениво в UI

# ---------- Престиж «Новый хозяин» ----------
func prestige_gain() -> int:
	return floori(sqrt(float(GameState.stats.outbreaks_cleared) * 4.0))

func do_prestige() -> bool:
	if GameState.stats.outbreaks_cleared < 5:
		toast.emit("Рано: нужно победить минимум 5 вспышек.")
		return false
	var gain := maxi(1, prestige_gain())
	GameState.prestige_points += gain
	GameState.prestige_count += 1
	GameState.reset_run(true)
	GameState.log_line("Новый хозяин получен! +{0} очков иммунитета.".format([gain]))
	toast.emit("Новый хозяин! +{0} к постоянным бонусам".format([gain]))
	SaveManager.save_game()
	return true

# ---------- Оффлайн-прогресс (упрощённый, до 8 часов) ----------
func apply_offline(seconds: float) -> String:
	seconds = clampf(seconds, 0.0, 8.0 * 3600.0)
	if seconds < 60.0:
		return ""
	# Считаем чистый часовой доход/расход по текущему состоянию
	var per_sec := {}
	for k in Definitions.resources: per_sec[k] = 0.0
	var pm: float = GameState.prestige_mult()
	for id in GameState.organs:
		var lvl: int = GameState.organs[id]
		var d: Dictionary = Definitions.organs[id]
		for k in d.output: per_sec[k] += d.output[k] * lvl * pm
		for k in d.consumption: per_sec[k] -= d.consumption[k] * lvl
	var lines := PackedStringArray()
	for k in per_sec:
		var gained: float = per_sec[k] * seconds
		if absf(gained) < 0.5: continue
		GameState.res[k] = maxf(0.0, GameState.res[k] + gained)
		lines.append("%+s %s" % [Definitions.format_amount(gained), Definitions.resources[k].name_ru])
	# За оффлайн инфекции не спавнятся, но существующие медленно растут
	for uid in GameState.infections:
		var inf: Dictionary = GameState.infections[uid]
		inf.amount = minf(inf.amount * (1.0 + 0.02 * seconds / 60.0), Definitions.pathogens[inf.id].threshold * 2.0)
	if lines.size() == 0:
		return "Пока вас не было, организм отдыхал."
	return "Оффлайн-прогресс (" + str(int(seconds / 60.0)) + " мин):\n" + "\n".join(lines)
