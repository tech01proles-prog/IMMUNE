# Immune Empire: Internal Front — главный экран MVP
# Сцена строится кодом: панель ресурсов, вкладки (Органы / Клетки / Технологии / Угрозы / Хозяин),
# журнал и тосты. UI только читает GameState и вызывает команды Simulation
# (принцип №2 "UI is a reader, not the brain" из 07_GODOT_PROJECT_ARCHITECTURE.txt).
extends Control

const THEME_BG := Color("#2a0711")   # deep burgundy — мастер-палитра 08_QWEN_ART_PROMPTS.txt
const PANEL := Color("#3b0d2a")
const PANEL2 := Color("#4a1020")
const ACCENT := Color("#5ce1e6")
const SUBTEXT := Color("#8fdcff")

var _res_labels: Dictionary = {}
var _res_rates: Dictionary = {}
var _organ_rows: Dictionary = {}   # id -> {card, title, cost, btn}
var _cell_rows: Dictionary = {}    # id -> {card, title, cost, btn}
var _tech_rows: Dictionary = {}    # id -> {card, cost, btn}
var _threat_box: VBoxContainer
var _journal: RichTextLabel
var _infl_bar: ProgressBar
var _prestige_label: Label
var _tabs: TabContainer
var _toast_layer: Control

var _prev_res: Dictionary = {}
var _threat_sig := ""
var _threat_bars: Dictionary = {}
var _journal_lines := 0
var _autosave_timer := 0.0

func _ready() -> void:
	_build_ui()
	if not SaveManager.load_game():
		GameState.log_line("Новая игра. Наладьте питание и продержитесь первую вспышку.")
	Simulation.toast.connect(_on_toast)
	_refresh(true)

func _process(delta: float) -> void:
	_refresh(false)
	_autosave_timer += delta
	if _autosave_timer > 15.0:
		_autosave_timer = 0.0
		SaveManager.save_game()

# ================= Построение UI =================
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = THEME_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	root.add_child(_make_title())
	root.add_child(_build_resource_bar())

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_tabs.add_child(_build_list_tab("organs", Definitions.organs, _organ_rows, "organ_", _make_organ_card))
	_tabs.add_child(_build_list_tab("cells", Definitions.cells, _cell_rows, "cell_", _make_cell_card))
	_tabs.add_child(_build_list_tab("tech", Definitions.technologies, _tech_rows, "tech", _make_tech_card))
	_tabs.add_child(_build_threat_tab())
	_tabs.add_child(_build_prestige_tab())
	var names := ["Органы", "Клетки", "Технологии", "Угрозы", "Хозяин"]
	for i in names.size():
		_tabs.set_tab_title(i, names[i])

	root.add_child(_build_bottom())

func _make_title() -> Control:
	var h := HBoxContainer.new()
	var t := Label.new()
	t.text = "IMMUNE EMPIRE: INTERNAL FRONT"
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", ACCENT)
	h.add_child(t)
	var sub := Label.new()
	sub.text = "  — инкрементальная симуляция иммунитета (MVP)"
	sub.add_theme_color_override("font_color", SUBTEXT)
	h.add_child(sub)
	return h

func _build_resource_bar() -> Control:
	var panel := PanelContainer.new()
	panel.modulate = Color(PANEL)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	panel.add_child(hb)
	for id in Definitions.resources:
		hb.add_child(_resource_chip(id))
	return panel

func _resource_chip(id: String) -> Control:
	var mb := MarginContainer.new()
	mb.add_theme_constant_override("margin_left", 6)
	mb.add_theme_constant_override("margin_right", 6)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	mb.add_child(vb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ArtFactory.icon(id)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var val := Label.new()
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color(Definitions.resources[id].color))
	row.add_child(val)
	_res_labels[id] = val
	var rate := Label.new()
	rate.add_theme_font_size_override("font_size", 10)
	rate.add_theme_color_override("font_color", SUBTEXT)
	vb.add_child(rate)
	_res_rates[id] = rate
	return mb

# Универсальная вкладка-список карточек
func _build_list_tab(tab_name: String, defs: Dictionary, rows: Dictionary, icon_prefix: String, maker: Callable) -> Control:
	var box := VBoxContainer.new()
	box.name = tab_name
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for id in defs:
		var card = maker.call(id, icon_prefix)
		rows[id] = card["refs"]
		list.add_child(card["node"])
	return box

func _card_frame(icon_id: String, title: String, subtitle: String) -> Dictionary:
	var card := PanelContainer.new()
	card.modulate = Color(PANEL2)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)
	var icon := TextureRect.new()
	icon.texture = ArtFactory.icon(icon_id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(texts)
	var l1 := Label.new()
	l1.text = title
	l1.add_theme_font_size_override("font_size", 15)
	texts.add_child(l1)
	var l2 := Label.new()
	l2.text = subtitle
	l2.add_theme_font_size_override("font_size", 11)
	l2.add_theme_color_override("font_color", SUBTEXT)
	texts.add_child(l2)
	return {"node": card, "hb": hb, "texts": texts, "title": l1, "sub": l2}

func _make_organ_card(id: String, prefix: String) -> Dictionary:
	var f := _card_frame(prefix + id, Definitions.organs[id].name_ru, "")
	var btn := Button.new()
	btn.text = "Построить"
	btn.pressed.connect(_on_buy_organ.bind(id))
	f.hb.add_child(btn)
	return {"node": f.node, "refs": {"card": f.node, "title": f.title, "cost": f.sub, "btn": btn}}

func _make_cell_card(id: String, prefix: String) -> Dictionary:
	var d: Dictionary = Definitions.cells[id]
	var def_text := ""
	for k in d.defense:
		def_text += "%s:%.1f " % [_kind_name(k), d.defense[k]]
	var f := _card_frame(prefix + id, d.name_ru, def_text)
	var info := Label.new()
	info.text = "АТФ: %.3f/с · Воспаление: +%.3f/с" % [d.upkeep_atp, d.inflammation]
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", Color("#a8e6cf"))
	f.texts.add_child(info)
	var btn := Button.new()
	btn.text = "Обучить"
	btn.pressed.connect(_on_train_cell.bind(id))
	f.hb.add_child(btn)
	return {"node": f.node, "refs": {"card": f.node, "title": f.title, "cost": f.sub, "btn": btn}}

func _make_tech_card(id: String, _prefix: String) -> Dictionary:
	var t: Dictionary = Definitions.technologies[id]
	var f := _card_frame("tech", t.name_ru, "")
	var btn := Button.new()
	btn.text = "Изучить"
	btn.pressed.connect(_on_research.bind(id))
	f.hb.add_child(btn)
	return {"node": f.node, "refs": {"card": f.node, "title": f.title, "cost": f.sub, "btn": btn}}

func _build_threat_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "threats"
	box.add_theme_constant_override("separation", 8)
	var infl_hb := HBoxContainer.new()
	infl_hb.add_theme_constant_override("separation", 8)
	var ii := TextureRect.new()
	ii.texture = ArtFactory.icon("inflammation")
	ii.custom_minimum_size = Vector2(36, 36)
	ii.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ii.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	infl_hb.add_child(ii)
	var il := Label.new()
	il.text = "Воспаление:"
	infl_hb.add_child(il)
	_infl_bar = ProgressBar.new()
	_infl_bar.min_value = 0
	_infl_bar.max_value = 100
	_infl_bar.custom_minimum_size = Vector2(420, 24)
	_infl_bar.show_percentage = true
	infl_hb.add_child(_infl_bar)
	box.add_child(infl_hb)
	_threat_box = VBoxContainer.new()
	_threat_box.add_theme_constant_override("separation", 8)
	box.add_child(_threat_box)
	return box

func _build_prestige_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "prestige"
	box.add_theme_constant_override("separation", 10)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = ArtFactory.icon("prestige")
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)
	var txt := VBoxContainer.new()
	var t1 := Label.new()
	t1.text = "НОВЫЙ ХОЗИН (ПРЕСТИЖ)"
	t1.add_theme_font_size_override("font_size", 20)
	t1.add_theme_color_override("font_color", Color("#ffd166"))
	txt.add_child(t1)
	_prestige_label = Label.new()
	txt.add_child(_prestige_label)
	var note := Label.new()
	note.text = "Сброс организма ради постоянных очков иммунитета.\n+5% ко всему производству за очко. Нужно минимум 5 побед над вспышками."
	note.add_theme_color_override("font_color", SUBTEXT)
	txt.add_child(note)
	hb.add_child(txt)
	box.add_child(hb)
	var btn := Button.new()
	btn.text = "Сменить хозяина"
	btn.custom_minimum_size = Vector2(240, 44)
	btn.pressed.connect(_on_prestige)
	box.add_child(btn)
	return box

func _build_bottom() -> Control:
	var panel := PanelContainer.new()
	panel.modulate = Color(PANEL)
	panel.custom_minimum_size = Vector2(0, 110)
	_journal = RichTextLabel.new()
	_journal.bbcode_enabled = true
	_journal.scroll_following = true
	_journal.add_theme_font_size_override("normal_font_size", 12)
	panel.add_child(_journal)
	_toast_layer = Control.new()
	_toast_layer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_layer)
	return panel

# ================= Команды =================
func _on_buy_organ(id: String) -> void:
	Simulation.buy_organ(id)
	_refresh(true)

func _on_train_cell(id: String) -> void:
	Simulation.train_cell(id)
	_refresh(true)

func _on_research(id: String) -> void:
	Simulation.research_tech(id)
	_refresh(true)

func _on_prestige() -> void:
	if Simulation.do_prestige():
		_threat_sig = "~force~"
		_refresh(true)

# ================= Обновление =================
func _refresh(force: bool) -> void:
	for id in _res_labels:
		_res_labels[id].text = Definitions.format_amount(GameState.res[id])
		_res_rates[id].text = _rate_text(id, force)
	_infl_bar.value = GameState.inflammation

	for oid in _organ_rows:
		var r: Dictionary = _organ_rows[oid]
		var unlocked: bool = Simulation.is_organ_unlocked(oid)
		r.card.visible = unlocked
		if unlocked:
			var lvl: int = GameState.organs.get(oid, 0)
			r.title.text = "%s  [ур. %d]" % [Definitions.organs[oid].name_ru, lvl]
			var cost := Definitions.organ_cost(oid, lvl)
			r.cost.text = _cost_text(cost)
			r.btn.disabled = not Simulation.can_afford(cost)

	for cid in _cell_rows:
		var r: Dictionary = _cell_rows[cid]
		var unlocked: bool = Simulation.is_cell_unlocked(cid)
		r.card.visible = unlocked
		if unlocked:
			var cnt: int = GameState.cells.get(cid, 0)
			r.title.text = "%s  ×%d" % [Definitions.cells[cid].name_ru, cnt]
			var cost := _final_cell_cost(cid, cnt)
			r.cost.text = _cost_text(cost)
			r.btn.disabled = not Simulation.can_afford(cost)

	for tid in _tech_rows:
		var r: Dictionary = _tech_rows[tid]
		var learned: bool = GameState.has_tech(tid)
		var unlocked: bool = Simulation.is_tech_unlocked(tid) or learned
		r.card.visible = unlocked
		if unlocked:
			r.btn.disabled = learned or not Simulation.can_afford(Definitions.technologies[tid].cost)
			r.btn.text = "Изучено ✓" if learned else "Изучить"
			if not learned:
				r.cost.text = _cost_text(Definitions.technologies[tid].cost)

	_rebuild_threats()

	var gain: int = maxi(1, Simulation.prestige_gain()) if GameState.stats.outbreaks_cleared >= 5 else 0
	_prestige_label.text = "Очки иммунитета: %d (+%d%% производства)\nПобед над вспышками: %d · Престижей: %d\nПри смене получите: +%d очков" % [
		GameState.prestige_points, GameState.prestige_points * 5,
		GameState.stats.outbreaks_cleared, GameState.prestige_count, gain]

	if _journal_lines != GameState.journal.size():
		_journal_lines = GameState.journal.size()
		var bb := ""
		for line in GameState.journal:
			bb += "[color=#8fdcff]•[/color] " + line + "\n"
		_journal.text = bb

func _final_cell_cost(id: String, count: int) -> Dictionary:
	var cost := Definitions.cell_cost(id, count)
	if id == "neutrophil" and GameState.has_tech("granulopoiesis_1"):
		for k in cost:
			cost[k] = ceil(cost[k] * 0.9)
	if (id == "b_cell" or id == "cytotoxic_t") and GameState.has_tech("clonal_expansion_1"):
		for k in cost:
			cost[k] = ceil(cost[k] * 0.9)
	return cost

func _rebuild_threats() -> void:
	var sig := str(GameState.infections.keys())
	if sig == _threat_sig:
		for uid in _threat_bars:
			if GameState.infections.has(uid):
				_threat_bars[uid].value = GameState.infections[uid].amount
		return
	_threat_sig = sig
	for c in _threat_box.get_children():
		c.queue_free()
	_threat_bars.clear()
	if GameState.infections.size() == 0:
		var ok := Label.new()
		ok.text = "Чисто. Патрули наблюдают за тканью."
		ok.add_theme_color_override("font_color", Color("#36cfc0"))
		_threat_box.add_child(ok)
		return
	for uid in GameState.infections:
		var inf: Dictionary = GameState.infections[uid]
		var p: Dictionary = Definitions.pathogens[inf.id]
		var f := _card_frame("path_" + inf.id, p.name_ru, "Тип: %s · Порог: %.0f · Слабы против: %s" % [
			_kind_name(p.kind), p.threshold, ", ".join(p.weak_to)])
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = p.threshold * 2.5
		bar.value = inf.amount
		bar.custom_minimum_size = Vector2(260, 22)
		bar.show_percentage = false
		f.hb.add_child(bar)
		_threat_bars[uid] = bar
		_threat_box.add_child(f.node)

func _rate_text(id: String, force: bool) -> String:
	if force or not _prev_res.has(id):
		_prev_res[id] = GameState.res[id]
		return ""
	var delta: float = GameState.res[id] - _prev_res[id]
	_prev_res[id] = GameState.res[id]
	var dt := get_process_delta_time()
	if dt <= 0.0001:
		return ""
	var per_sec := delta / dt
	if absf(per_sec) < 0.01:
		return ""
	return "%+.1f/с" % per_sec

func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in cost:
		parts.append("%s %s" % [Definitions.format_amount(cost[k]), Definitions.resources[k].name_ru])
	return "Цена: " + ", ".join(parts)

func _kind_name(kind: String) -> String:
	match kind:
		"bacteria":
			return "Бактерия"
		"virus":
			return "Вирус"
		"fungus":
			return "Грибок"
	return kind

func _on_toast(text: String) -> void:
	# EventToast: всплывающие уведомления поверх интерфейса
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color("#ffd166"))
	lbl.modulate.a = 0.0
	lbl.position = Vector2(20, 8 + _toast_layer.get_child_count() * 26.0)
	_toast_layer.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)
