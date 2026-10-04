# Immune Empire: Internal Front — процедурная графика в стиле 08_QWEN_ART_PROMPTS.txt
# Биомедицинский сай-фай: скруглённые органические формы, мембраны, ядра, шипы, свечение.
# Пока AI-иконки (Qwen Image 3.0) не сгенерированы, все визуальные элементы рисуются кодом
# из мастер-палитры документа 08. При появлении PNG достаточно заменить get_icon() на load().
class_name ArtFactory
extends RefCounted

# --- Мастер-палитра (08_QWEN_ART_PROMPTS.txt §2) ---
const C_BG       := Color("#2a0711")   # deep burgundy (ткань/фон)
const C_BG2      := Color("#3b0d2a")   # dark violet-red
const C_CYAN     := Color("#5ce1e6")   # иммунные клетки
const C_ICE      := Color("#8fdcff")
const C_WHITEBLU := Color("#e8fbff")
const C_TEAL     := Color("#36cfc0")
const C_DANGER   := Color("#ff6b6b")
const C_GOLD     := Color("#ffd166")

static var _cache: Dictionary = {}

# Универсальный getter иконки: id -> 96x96 изображение, кэшируется
static func icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	match id:
		"amino_acids":        _draw_aa(img)
		"glucose":            _draw_glucose(img)
		"lipids":             _draw_lipids(img)
		"micronutrients":     _draw_micronutrients(img)
		"atp":                _draw_atp(img)
		"stem_cells":         _draw_stem(img)
		"antigens":           _draw_antigen(img)
		"organ_gut_villi":    _draw_gut(img)
		"organ_mitochondrial_network": _draw_mito(img)
		"organ_bone_marrow":  _draw_marrow(img)
		"organ_liver":        _draw_liver(img)
		"organ_lymph_node":   _draw_lymph(img)
		"cell_neutrophil":    _draw_cell(img, C_CYAN, 3)
		"cell_macrophage":    _draw_cell(img, C_TEAL, 5)
		"cell_dendritic_cell":_draw_dendritic(img)
		"cell_nk_cell":       _draw_cell(img, C_ICE, 4)
		"cell_b_cell":        _draw_cell(img, C_WHITEBLU, 6)
		"cell_cytotoxic_t":   _draw_cell(img, C_GOLD, 4)
		"path_swarm_coccus":  _draw_coccus(img)
		"path_shell_variant": _draw_virus(img)
		"path_thread_bloom":  _draw_fungus(img)
		"tech":               _draw_tech(img)
		"prestige":           _draw_prestige(img)
		"inflammation":       _draw_inflammation(img)
		_: _draw_placeholder(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex

# ---------- Ресурсы ----------
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _circle(img: Image, cx: float, cy: float, rad: float, c: Color, filled := true) -> void:
	for y in range(int(cy - rad) - 1, int(cy + rad) + 2):
		for x in range(int(cx - rad) - 1, int(cx + rad) + 2):
			var d := sqrt(pow(x - cx, 2) + pow(y - cy, 2))
			if filled:
				if d <= rad:
					var edge := clampf(rad - d, 0.0, 1.0)
					_px(img, x, y, Color(c.r, c.g, c.b, minf(c.a, 0.35 + 0.65 * edge)))
			else:
				if absf(d - rad) < 2.0:
					_px(img, x, y, c)

static func _membrane_blob(img: Image, cx: float, cy: float, rad: float, base: Color, rim: Color) -> void:
	# Скруглённая органическая форма с мягким ободком (shape language §1)
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x - cx) / rad
			var dy := (y - cy) / rad
			var wob := 0.12 * sin(atan2(dy, dx) * 5.0)
			var d := sqrt(dx * dx + dy * dy) + wob
			if d < 1.0:
				var shade: float = lerpf(0.55, 1.0, 1.0 - d)
				var col := base.darkened(1.0 - shade)
				if d > 0.82:
					col = rim.lerp(col, (1.0 - d) / 0.18)
				col.a = 1.0
				img.set_pixel(x, y, col)

static func _clear(img: Image) -> void:
	img.fill(Color(0, 0, 0, 0))

static func _draw_aa(img: Image) -> void:
	_clear(img)
	# Цепочка аминокислот: три светящихся шара-резиду
	_membrane_blob(img, 30, 58, 16, C_WHITEBLU, C_ICE)
	_membrane_blob(img, 58, 40, 14, C_ICE, C_CYAN)
	_membrane_blob(img, 74, 66, 10, C_WHITEBLU, C_ICE)
	_circle(img, 30, 58, 5, C_CYAN)
	_circle(img, 58, 40, 4, C_TEAL)

static func _draw_glucose(img: Image) -> void:
	_clear(img)
	# Гексагональное кольцо молекулы сахара
	var pts: Array[Vector2] = []
	for i in 6:
		var a := PI / 3.0 * i - PI / 6.0
		pts.append(Vector2(48, 48) + Vector2(cos(a), sin(a)) * 26.0)
	for i in 6:
		var p0 := pts[i]; var p1 := pts[(i + 1) % 6]
		_line(img, p0.x, p0.y, p1.x, p1.y, C_GOLD)
	for p in pts:
		_circle(img, p.x, p.y, 6, C_GOLD.lightened(0.3))
	_circle(img, 48, 48, 8, C_GOLD.darkened(0.2))

static func _line(img: Image, x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var n := int(maxf(absf(x1 - x0), absf(y1 - y0)))
	for i in range(n + 1):
		var t := float(i) / maxf(1.0, float(n))
		_px(img, int(lerpf(x0, x1, t)), int(lerpf(y0, y1, t)), c)
		_px(img, int(lerpf(x0, x1, t)), int(lerpf(y0, y1, t)) + 1, c)

static func _draw_lipids(img: Image) -> void:
	_clear(img)
	# Бислой фосфолипидов: два ряда «голов» с хвостами
	for row in 2:
		for i in 7:
			var x := 14 + i * 11.0
			var y := 30.0 + row * 36.0
			_circle(img, x, y, 5, Color("#f4a261"))
			var dir := -1.0 if row == 1 else 1.0
			_line(img, x, y + 5 * dir, x - 2, y + 16 * dir, Color("#f4a261").darkened(0.3))
			_line(img, x, y + 5 * dir, x + 2, y + 16 * dir, Color("#f4a261").darkened(0.3))

static func _draw_micronutrients(img: Image) -> void:
	_clear(img)
	# Рассеянные кристаллы-микронутриенты
	var spots := [[28, 30], [60, 24], [70, 58], [36, 66], [50, 46]]
	for s in spots:
		_diamond(img, s[0], s[1], 9, Color("#a8e6cf"))

static func _diamond(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r), int(cy + r) + 1):
		var w := int(r - absf(y - cy))
		for x in range(int(cx - w), int(cx + w) + 1):
			_px(img, x, y, c.lightened(0.2 * (1.0 - absf(y - cy) / r)))

static func _draw_atp(img: Image) -> void:
	_clear(img)
	# Митохондриальная энергия: овал с внутренними кристами и молнией
	_membrane_blob(img, 48, 48, 34, Color("#112244"), C_CYAN)
	for i in 4:
		var yy := 26.0 + i * 14.0
		_line(img, 24, yy, 40, yy + 6, C_TEAL)
		_line(img, 72, yy, 56, yy + 6, C_TEAL)
	# Молния
	_line(img, 52, 24, 42, 48, C_GOLD)
	_line(img, 42, 48, 54, 48, C_GOLD)
	_line(img, 54, 48, 44, 72, C_GOLD)

static func _draw_stem(img: Image) -> void:
	_clear(img)
	# Стволовая клетка: большой круглый nucleus, мягкое свечение
	_membrane_blob(img, 48, 48, 36, Color("#2a2a4a"), Color("#c8b6ff"))
	_circle(img, 48, 48, 16, Color("#c8b6ff"))
	_circle(img, 44, 44, 6, Color("#e8fbff").lightened(0.2))

static func _draw_antigen(img: Image) -> void:
	_clear(img)
	# Антиген: Y-образный антительный маркер
	_line(img, 48, 76, 48, 50, C_DANGER)
	_line(img, 48, 50, 26, 28, C_DANGER)
	_line(img, 48, 50, 70, 28, C_DANGER)
	_circle(img, 26, 28, 8, C_DANGER.lightened(0.25))
	_circle(img, 70, 28, 8, C_DANGER.lightened(0.25))

# ---------- Клетки ----------
static func _draw_cell(img: Image, col: Color, lobes: int) -> void:
	_clear(img)
	_membrane_blob(img, 48, 48, 36, col.darkened(0.55), col)
	# Сегментированное ядро (как у гранулоцитов)
	for i in lobes:
		var a := TAU / lobes * i
		_circle(img, 48 + cos(a) * 13.0, 48 + sin(a) * 13.0, 8.0, col.darkened(0.25))

static func _draw_dendritic(img: Image) -> void:
	_clear(img)
	# Дендритная клетка: тело с древовидными отростками (dendrites)
	_circle(img, 48, 50, 16, Color("#7bdff2").darkened(0.35))
	for k in 10:
		var a := TAU / 10.0 * k + 0.3
		var x1 := 48 + cos(a) * 34.0
		var y1 := 50 + sin(a) * 34.0
		_line(img, 48 + cos(a) * 14, 50 + sin(a) * 14, x1, y1, Color("#8fdcff"))
		# Ветвление
		_line(img, x1, y1, x1 + cos(a + 0.5) * 9, y1 + sin(a + 0.5) * 9, Color("#8fdcff"))
		_line(img, x1, y1, x1 + cos(a - 0.5) * 9, y1 + sin(a - 0.5) * 9, Color("#8fdcff"))
	_circle(img, 48, 50, 7, Color("#e8fbff"))

# ---------- Патогены ----------
static func _draw_coccus(img: Image) -> void:
	_clear(img)
	# Колония кокков: кластер шаров со спайками
	var spots := [[38, 40], [58, 52], [46, 62], [60, 32]]
	for s in spots:
		_circle(img, s[0], s[1], 13, Color("#9ef01a").darkened(0.3))
		_circle(img, s[0], s[1], 9, Color("#9ef01a"))
		for k in 6:
			var a := TAU / 6.0 * k
			_px(img, int(s[0] + cos(a) * 14), int(s[1] + sin(a) * 14), Color("#d8f5a2"))

static func _draw_virus(img: Image) -> void:
	_clear(img)
	# Вирус: капсид + белковые шипы (spike proteins из shape language)
	_circle(img, 48, 48, 22, Color("#6a4c93"))
	_circle(img, 48, 48, 17, Color("#c8b6ff"))
	for k in 12:
		var a := TAU / 12.0 * k
		var x0 := 48 + cos(a) * 22.0; var y0 := 48 + sin(a) * 22.0
		var x1 := 48 + cos(a) * 34.0; var y1 := 48 + sin(a) * 34.0
		_line(img, x0, y0, x1, y1, Color("#c8b6ff"))
		_circle(img, x1, y1, 3.5, Color("#e8fbff"))

static func _draw_fungus(img: Image) -> void:
	_clear(img)
	# Грибница: filament strands
	var c := Color("#f4a261")
	for i in 5:
		var x0 := 12.0 + i * 18.0
		var y := 20.0
		var px := x0
		while y < 80.0:
			var nx := px + sin(y * 0.2 + i) * 3.0
			_line(img, px, y, nx, y + 8, c)
			px = nx; y += 8.0
	_circle(img, 30, 22, 7, c.lightened(0.2))
	_circle(img, 62, 20, 6, c.lightened(0.2))

# ---------- Прочее ----------
static func _draw_gut(img: Image) -> void:
	_clear(img)
	# Ворсинки: пальцеобразные выросты на базальной мембране
	_line(img, 8, 74, 88, 74, Color("#7a2c4e"))
	for i in 6:
		var x := 14.0 + i * 13.0
		var hgt := 34.0 + fmod(i * 13.0, 14.0)
		for y in range(int(74 - hgt), 74):
			var w := 5.0 * sin(PI * (y - (74 - hgt)) / hgt) + 2.0
			for xx in range(int(x - w), int(x + w)):
				_px(img, xx, y, Color("#b5486b").lightened(0.15 * (w / 7.0)))

static func _draw_mito(img: Image) -> void:
	_clear(img)
	_membrane_blob(img, 48, 48, 36, Color("#0f2b3d"), C_CYAN)
	for i in 5:
		var yy := 20.0 + i * 13.0
		_line(img, 20, yy, 44, yy + 7, C_TEAL)
		_line(img, 76, yy, 52, yy + 7, C_TEAL)

static func _draw_marrow(img: Image) -> void:
	_clear(img)
	# Кость с пористым каналом и клетками внутри
	_round_rect(img, 14, 20, 68, 56, Color("#e8fbff").darkened(0.25))
	_round_rect(img, 26, 32, 44, 32, Color("#4a1020"))
	for s in [[36, 44], [52, 52], [60, 40]]:
		_circle(img, s[0], s[1], 6, Color("#c8b6ff"))

static func _round_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := minf(x - x0, x1 - x); var dy := minf(y - y0, y1 - y)
			if dx > 6 or dy > 6 or (pow(dx - 6, 2) + pow(dy - 6, 2) <= 36):
				img.set_pixel(x, y, c)

static func _draw_liver(img: Image) -> void:
	_clear(img)
	# Печень: большая дольчатая форма
	_membrane_blob(img, 44, 52, 34, Color("#5c1e1e"), Color("#a0522d"))
	_membrane_blob(img, 66, 40, 16, Color("#6b2424"), Color("#a0522d"))
	_circle(img, 40, 50, 6, Color("#ffd166").darkened(0.2))

static func _draw_lymph(img: Image) -> void:
	_clear(img)
	# Лимфоузел: фасоль с кортексом
	_membrane_blob(img, 48, 48, 32, Color("#1d3b2a"), Color(C_TEAL))
	_circle(img, 48, 48, 18, Color("#2f5d46"))
	for k in 6:
		var a := TAU / 6.0 * k
		_circle(img, 48 + cos(a) * 24, 48 + sin(a) * 24, 4, C_TEAL)

static func _draw_tech(img: Image) -> void:
	_clear(img)
	# Шестерня-сигнал: tech-символ
	_circle(img, 48, 48, 18, Color(0, 0, 0, 0), false)
	for k in 8:
		var a := TAU / 8.0 * k
		_line(img, 48 + cos(a) * 20, 48 + sin(a) * 20, 48 + cos(a) * 32, 48 + sin(a) * 32, C_ICE)
	_circle(img, 48, 48, 10, C_ICE.darkened(0.3))
	_circle(img, 48, 48, 5, C_WHITEBLU)

static func _draw_prestige(img: Image) -> void:
	_clear(img)
	# Новый хозяин: силуэт тела с ядром света
	_circle(img, 48, 26, 12, C_WHITEBLU)
	_round_rect(img, 34, 38, 62, 78, C_WHITEBLU.darkened(0.15))
	_circle(img, 48, 56, 8, C_GOLD)

static func _draw_inflammation(img: Image) -> void:
	_clear(img)
	# Пламя воспаления поверх ткани
	for i in 3:
		var x := 32.0 + i * 16.0
		var hgt := 30.0 + fmod(i * 17.0, 20.0)
		for y in range(int(80 - hgt), 80):
			var t := float(y - (80 - hgt)) / hgt
			var w := (1.0 - t) * 8.0
			var col := Color("#ff6b6b").lerp(Color("#ffd166"), t)
			for xx in range(int(x - w), int(x + w)):
				_px(img, xx, y, col)

static func _draw_placeholder(img: Image) -> void:
	_clear(img)
	_circle(img, 48, 48, 30, C_BG2)
	_circle(img, 48, 48, 30, C_CYAN, false)
