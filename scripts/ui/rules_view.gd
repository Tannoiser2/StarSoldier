extends Control
## Regolamento in italiano (assets/regole.md) e tabelle del gioco. Si apre dal menu o sopra la partita.

const D = preload("res://scripts/data/ss_data.gd")

signal closed

var main
var page := "regole"
var embedded := false
var body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if embedded:
		var sh := ColorRect.new()
		sh.color = Color(0.1, 0.06, 0.04, 0.6)
		sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(sh)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		panel.set("offset_" + k, 60 if k in ["left", "top"] else -60)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	top.add_child(UI.title("Regole" if page == "regole" else "Tabelle", 42))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	for p in [["regole", "Regole"], ["tabelle", "Tabelle"]]:
		var pp: String = p[0]
		var b := UI.toggled(UI.button(p[1], 160, 48, 19), page == pp)
		b.pressed.connect(func():
			page = pp
			_fill())
		top.add_child(b)
	var bc := UI.primary(UI.button("Chiudi", 160, 48, 19))
	bc.pressed.connect(_close)
	top.add_child(bc)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	sc.add_child(body)
	_fill()


func _close() -> void:
	if embedded:
		closed.emit()
		queue_free()
	else:
		main.show_menu()


func _fill() -> void:
	for c in body.get_children():
		c.queue_free()
	if page == "regole":
		_rules()
	else:
		_tables()


func _md(t: String) -> String:
	var out := t
	var re := RegEx.new()
	re.compile("\\*\\*(.+?)\\*\\*")
	out = re.sub(out, "[b]$1[/b]", true)
	var re2 := RegEx.new()
	re2.compile("\\*(.+?)\\*")
	out = re2.sub(out, "[i]$1[/i]", true)
	return out


func _rules() -> void:
	var f := FileAccess.open("res://assets/regole.md", FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	var table := []
	for line in txt.split("\n"):
		if line.begins_with("|"):
			if not line.begins_with("|---"):
				table.append(line)
			continue
		if not table.is_empty():
			body.add_child(_md_table(table))
			table = []
		if line.begins_with("# "):
			continue
		if line.begins_with("## "):
			body.add_child(UI.head(line.substr(3).to_upper(), 26, UI.RED_D))
			continue
		if line.strip_edges() == "":
			continue
		var r := UI.rich(19)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := line
		if l.begins_with("- "):
			l = "  •  " + l.substr(2)
		elif l.length() > 2 and l[0].is_valid_int() and l[1] == ".":
			l = "  " + l
		r.text = _md(l)
		body.add_child(r)
	if not table.is_empty():
		body.add_child(_md_table(table))


func _md_table(rows: Array) -> Control:
	var g := GridContainer.new()
	var first: Array = rows[0].split("|", false)
	g.columns = first.size()
	g.add_theme_constant_override("h_separation", 28)
	g.add_theme_constant_override("v_separation", 4)
	for i in rows.size():
		for c in rows[i].split("|", false):
			g.add_child(UI.label(c.strip_edges(), 18, UI.RED_D if i == 0 else UI.INK, UI.font_head if i == 0 else null))
	return g


func _grid(title: String, head: Array, rows: Array, note := "") -> void:
	body.add_child(UI.head(title, 24, UI.RED_D))
	var g := GridContainer.new()
	g.columns = head.size()
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 2)
	for h in head:
		g.add_child(UI.label(str(h), 17, UI.RED_D, UI.font_head))
	for r in rows:
		for c in r:
			var l := UI.mono(str(c), 18)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			g.add_child(l)
	body.add_child(g)
	if note != "":
		body.add_child(UI.wrap(UI.label(note, 15, UI.MUTED), 1200))
	body.add_child(UI.hsep())


func _cell(v: int) -> String:
	if v == 0:
		return "·"
	if v < 0:
		return "S"
	return str(v)


func _tables() -> void:
	var fh := ["Dadi", "+1", "+2", "+3", "+4", "+5", "+6", "+7", "+8", "+9"]
	var rows := []
	for i in 11:
		var r := [str(i + 2)]
		for c in D.FIRE_STD[i]:
			r.append(_cell(c))
		rows.append(r)
	_grid("26.1 Fuoco – gioco standard", fh, rows, "Due dadi incrociati con il differenziale (attacco meno difesa): TP persi dal bersaglio. Sotto +1 l'attacco non è possibile; oltre +9 vale +9.")
	rows = []
	for i in 11:
		var r := [str(i + 2)]
		for c in D.FIRE_BASIC[i]:
			r.append(_cell(c))
		rows.append(r)
	_grid("9.8 Fuoco – gioco base", fh.slice(0, 7), rows, "Oltre +6 vale +6.")
	var lh := ["Dadi", "1-5", "6-10", "11-15", "16-20", "21-25", "26+"]
	rows = []
	for i in 11:
		var r := [str(i + 2)]
		for c in D.LW_STD[i]:
			r.append(_cell(c))
		rows.append(r)
	_grid("26.2 Armi lanciate – gioco standard", lh, rows, "Forza dell'esplosione divisa per il valore del terreno. S = stordito: niente recupero nello stadio.")
	rows = []
	for i in 11:
		var r := [str(i + 2)]
		for c in D.LW_BASIC[i]:
			r.append(_cell(c))
		rows.append(r)
	_grid("10.5 Armi lanciate – gioco base", lh, rows)
	rows = []
	for i in 6:
		var r := [str(i + 1)]
		for c in D.SCATTER[i]:
			r.append("colpisce" if c == 0 else "%d esagoni" % c)
		rows.append(r)
	_grid("10.4 Dispersione delle bombe guidate", ["Dado", "-1", "-2", "-3", "-4", "-5", "-6 o meno"], rows, "Con differenziale di dispersione 0 o più la bomba cade dove mirata. La direzione si tira con un altro dado sul diagramma della mappa (1 Ovest, poi in senso orario).")
	rows = []
	for i in 6:
		var r := [str(i + 1)]
		for c in D.INTERCEPT[i]:
			r.append("distrutto" if c else "·")
		rows.append(r)
	_grid("10.24 Intercettazione dei missili a volo libero", ["Dado", "1-10", "11-15", "16-20", "21+"], rows, "Contromisure di tutti i bersagli nel raggio × 1 fino a 5 esagoni, × 2 da 6 a 10.")
	_grid("21.5 Danni alle piattaforme di supporto e alle basi", ["Dadi", "Risultato"], [["2-7", "nessun effetto"], ["8-9", "TPA dimezzato (se già dimezzato: distrutta)"], ["10-11", "cannone laser distrutto (le basi: TPA dimezzato)"], ["12", "distrutta"]], "Si tira solo se il risultato delle tabelle è di 6 TP o più, aggiungendo al tiro la differenza oltre 6.")
	var trows := []
	for k in [".", "b", "o", "m", "u", "l", "c"]:
		var blocks := {"o": "a terra", "m": "a terra e volo radente", "u": "a terra e volo radente", "l": "a terra (12.5)", "c": "a terra (12.4)"}
		trows.append([D.T_NAME[k], str(D.T_VALUE[k]), blocks.get(k, "–")])
	_grid("12.6 Terreno", ["Terreno", "Valore", "Blocca il fuoco di chi è"], trows)
	_grid("6.4 Specie (TPA / efficienza / recupero)", ["Specie", "Base", "Standard"], [["Umani", "5 / 2 / 1", "9 / 2 / 3"], ["L'Chal Dah", "6 / 2 / 1", "12 / 2 / 1"], ["Rame", "–", "6 / 4 / 2"], ["Xenofobi", "–", "9 / 1 / 1"], ["Androidi", "–", "come la specie, recupero 0"], ["Base (per esagono)", "–", "6 / 2 / 0"]])
	_grid("7.1 Compiti", ["Compito", "Costo"], [["Movimento a terra", "valore del terreno per esagono"], ["Movimento in volo", "½ per esagono"], ["A terra » volo radente", "3"], ["Volo radente » alta quota", "3"], ["Alta quota » volo radente o a terra", "3"], ["Volo radente » a terra", "0"], ["Bomba guidata a positroni", "3 o più"], ["Missili a volo libero, granata opacizzante", "3"], ["Missile cercatore", "3 o più (5 esagoni per TP, almeno 15)"], ["Fuoco diretto, ristretto, d'opportunità", "a scelta"], ["Contromisure", "a scelta"], ["Ricerca / trasporto (gioco base)", "1 / 3"]])
