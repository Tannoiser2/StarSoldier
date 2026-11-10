extends Control
## Menu principale: scelta dello scenario, della situazione e delle forze, dei giocatori (persone o IA),
## della grafica; partite online con codice; caricamento di una partita salvata; regole e tabelle.

const SC = preload("res://scripts/data/scenari.gd")

var main
var scen_id := 13
var sit := "B"
var match_i := 0
var swap := false
var side_ai := [true, false]     # Alpha IA, Bravo persona (per difetto si gioca Bravo dove ha senso)
var style := "originale"
var speed := 1.0

var list_box: VBoxContainer
var detail: VBoxContainer
var scen_buttons := {}
var list_scroll: ScrollContainer

# online
var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button
var host_side := 0
var on_join := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	scen_id = int(st.get("scen", 13))
	sit = str(st.get("sit", "B"))
	match_i = int(st.get("match", 0))
	swap = bool(st.get("swap", false))
	side_ai = st.get("ai", [true, false]).duplicate()
	style = str(st.get("style", "originale"))
	speed = float(st.get("speed", 1.0))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 22)
	add_child(margin)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	margin.add_child(hb)
	# colonna sinistra: logo e scenari
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 560
	left.add_theme_constant_override("separation", 6)
	hb.add_child(left)
	var logo_row := HBoxContainer.new()
	logo_row.add_theme_constant_override("separation", 16)
	left.add_child(logo_row)
	var cov := TextureRect.new()
	cov.texture = UI.tex("res://assets/misc/copertina.png")
	cov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cov.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	cov.custom_minimum_size = Vector2(108, 108)
	logo_row.add_child(cov)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_row.add_child(tv)
	tv.add_theme_constant_override("separation", 0)
	tv.add_child(UI.title("StarSoldier", 56))
	tv.add_child(UI.head("TACTICAL WARFARE IN THE 25TH CENTURY", 19, UI.INK))
	tv.add_child(UI.label("SPI, 1977 · versione digitale", 15, UI.MUTED))
	left.add_child(UI.hsep(UI.SEPIA))
	left.add_child(UI.head("SCENARI", 19, UI.RED_D))
	list_scroll = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_box)
	for s in SC.list():
		var id := int(s["id"])
		var b := UI.button("", 0, 44, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%d d.C.   %s" % [s["anno"], s["nome"]]
		if s.get("base", false):
			b.text += "  ·  gioco base"
		b.pressed.connect(func():
			scen_id = id
			var ss: Array = SC.get_scn(id)["situazioni"]
			if not sit in ss:
				sit = ss[0]
			match_i = 0
			swap = false
			_refresh())
		list_box.add_child(b)
		scen_buttons[id] = b
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	left.add_child(row)
	var br := UI.button("Regole", 0, 46, 17)
	br.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.pressed.connect(func():
		_store()
		main.show_rules("regole"))
	row.add_child(br)
	var bt := UI.button("Tabelle", 0, 46, 17)
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.pressed.connect(func():
		_store()
		main.show_rules("tabelle"))
	row.add_child(bt)
	var bl := UI.button("Carica", 0, 46, 17)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bl.pressed.connect(_load_panel)
	row.add_child(bl)
	var bj := UI.button("Entra online", 0, 46, 17)
	bj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bj.pressed.connect(_online_join_panel)
	row.add_child(bj)
	# colonna destra: dettagli
	var right_panel := PanelContainer.new()
	right_panel.add_theme_stylebox_override("panel", UI.panel_style(0.93))
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right_panel)
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(rs)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 12)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(detail)
	_refresh()
	# rientro in una stanza online lasciata a metà
	var ses: Dictionary = main.get_net().load_session()
	if str(ses.get("room", "")) != "":
		var hint := UI.wrap(UI.label("Eri in una partita online (stanza %s): usa «Entra in una partita online» per rientrare." % ses["room"], 16, UI.RED_D), 540)
		left.add_child(hint)


func _store() -> void:
	main.menu_state = {"scen": scen_id, "sit": sit, "match": match_i, "swap": swap, "ai": side_ai, "style": style, "speed": speed}


func _scn() -> Dictionary:
	return SC.get_scn(scen_id)


## [indice fazione Alpha, indice fazione Bravo]
func _match() -> Array:
	var s := _scn()
	var m: Array = s["scontri"][clampi(match_i, 0, s["scontri"].size() - 1)]
	if swap and _can_swap():
		return [m[1], m[0]]
	return [m[0], m[1]]


func _can_swap() -> bool:
	var s := _scn()
	if not sit in ["P", "R", "A"]:
		return false
	var m: Array = s["scontri"][clampi(match_i, 0, s["scontri"].size() - 1)]
	return s["fazioni"][m[0]].has(sit) and s["fazioni"][m[1]].has(sit)


func _side_names() -> Array:
	var s := _scn()
	var m := _match()
	var a: String = s["fazioni"][m[0]]["nome"]
	var b: String = s["fazioni"][m[1]]["nome"]
	if sit in ["P", "R", "A"]:
		return [a + " (Alpha)", b + " (Bravo)"]
	return [a, b]


func _refresh() -> void:
	for id in scen_buttons:
		UI.toggled(scen_buttons[id], id == scen_id)
	for c in detail.get_children():
		c.queue_free()
	var s := _scn()
	detail.add_child(UI.title(s["nome"], 46))
	detail.add_child(UI.head("%d d.C." % s["anno"], 24, UI.RED_D))
	detail.add_child(UI.wrap(UI.label(s["testo"], 19), 900))
	# situazione
	if s["situazioni"].size() > 1 or sit in ["P", "R", "A"]:
		detail.add_child(UI.hsep())
		detail.add_child(UI.head("SITUAZIONE GENERALE", 20, UI.SEPIA))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		detail.add_child(r)
		for k in s["situazioni"]:
			var kk: String = k
			var b := UI.toggled(UI.button(SC.SIT_NAME.get(k, k), 200, 46, 19), k == sit)
			b.pressed.connect(func():
				sit = kk
				_refresh())
			r.add_child(b)
		if SC.SIT_TEXT.has(sit):
			detail.add_child(UI.wrap(UI.label(SC.SIT_TEXT[sit], 17, UI.MUTED), 900))
	# fazioni
	if s["scontri"].size() > 1 or _can_swap():
		detail.add_child(UI.hsep())
		detail.add_child(UI.head("FORZE IN CAMPO", 20, UI.SEPIA))
		var r2 := HFlowContainer.new()
		r2.add_theme_constant_override("h_separation", 8)
		r2.add_theme_constant_override("v_separation", 8)
		detail.add_child(r2)
		for i in s["scontri"].size():
			var ii: int = i
			var m: Array = s["scontri"][i]
			var b2 := UI.toggled(UI.button("%s contro %s" % [s["fazioni"][m[0]]["nome"], s["fazioni"][m[1]]["nome"]], 0, 46, 18), i == match_i)
			b2.pressed.connect(func():
				match_i = ii
				_refresh())
			r2.add_child(b2)
		if _can_swap():
			var bs := UI.button("Scambia Alpha e Bravo", 0, 46, 18)
			bs.pressed.connect(func():
				swap = not swap
				_refresh())
			r2.add_child(bs)
	# forze dettagliate
	var m2 := _match()
	var names := _side_names()
	var forces := VBoxContainer.new()
	detail.add_child(forces)
	for i in 2:
		var f: Dictionary = s["fazioni"][m2[i]]
		var txt: String = names[i]
		var spec: Dictionary = {}
		if f.has(sit):
			spec = f[sit][i if sit in ["P", "R", "A"] else 0]
		if not spec.is_empty():
			var u := str(spec.get("u", "")).replace("FT", "Squadra di fuoco").replace("HV", "Armi pesanti").replace("AD", "Androidi").replace("SW", "Sciame").replace("PL", "Piattaforma").replace("S+", "Squadra+").replace("+", ", ")
			if u == "S":
				u = "Squadra"
			if u.ends_with(", S"):
				u = u.substr(0, u.length() - 3) + ", Squadra"
			txt += ": " + u
			if int(spec.get("pl", 0)) > 0:
				txt += " · preservazione %d" % spec["pl"]
			if int(spec.get("basi", 0)) > 0:
				txt += " · %d esagoni di base" % spec["basi"]
			if int(spec.get("mine", 0)) > 0:
				txt += " · %d missili nascosti" % spec["mine"]
		if not f.get("orb", {}).is_empty() and (sit != "A" or i == 0 or true):
			txt += " · supporto orbitale"
		forces.add_child(UI.label("• " + txt, 18, UI.side_color(i)))
	# giocatori
	detail.add_child(UI.hsep())
	detail.add_child(UI.head("GIOCATORI", 20, UI.SEPIA))
	for i in 2:
		var ii2 := i
		var r3 := HBoxContainer.new()
		r3.add_theme_constant_override("separation", 8)
		detail.add_child(r3)
		var lb := UI.label(names[i], 19, UI.side_color(i))
		lb.custom_minimum_size.x = 380
		r3.add_child(lb)
		var bp := UI.toggled(UI.button("Persona", 150, 44, 18), not side_ai[i])
		bp.pressed.connect(func():
			side_ai[ii2] = false
			_refresh())
		r3.add_child(bp)
		var bi := UI.toggled(UI.button("Computer", 150, 44, 18), side_ai[i])
		bi.pressed.connect(func():
			side_ai[ii2] = true
			_refresh())
		r3.add_child(bi)
	if not side_ai[0] and not side_ai[1]:
		detail.add_child(UI.wrap(UI.label("Due persone sullo stesso dispositivo: i piani restano segreti e prima di ogni piano lo schermo chiede di passare il dispositivo. Per giocare ognuno dal suo, crea una partita online.", 16, UI.MUTED), 900))
	# grafica
	var r4 := HBoxContainer.new()
	r4.add_theme_constant_override("separation", 8)
	detail.add_child(r4)
	var lg := UI.label("Grafica", 19)
	lg.custom_minimum_size.x = 380
	r4.add_child(lg)
	for k in [["originale", "Originale SPI"], ["reborn", "Reborn 3D"]]:
		var kk: String = k[0]
		var b3 := UI.toggled(UI.button(k[1], 150, 44, 18), style == kk)
		b3.pressed.connect(func():
			style = kk
			_refresh())
		r4.add_child(b3)
	var r5 := HBoxContainer.new()
	r5.add_theme_constant_override("separation", 8)
	detail.add_child(r5)
	var lv := UI.label("Velocità delle animazioni", 19)
	lv.custom_minimum_size.x = 380
	r5.add_child(lv)
	for k in [[0.6, "Lenta"], [1.0, "Normale"], [2.0, "Veloce"]]:
		var kv: float = k[0]
		var b4 := UI.toggled(UI.button(k[1], 150, 44, 18), absf(speed - kv) < 0.01)
		b4.pressed.connect(func():
			speed = kv
			_refresh())
		r5.add_child(b4)
	detail.add_child(UI.hsep())
	var r6 := HBoxContainer.new()
	r6.add_theme_constant_override("separation", 12)
	detail.add_child(r6)
	var go := UI.primary(UI.button("Inizia la partita", 340, 64, 26))
	go.pressed.connect(_on_start)
	r6.add_child(go)
	var bo := UI.button("Crea una partita online", 0, 64, 20)
	bo.pressed.connect(_online_create_panel)
	r6.add_child(bo)


func _config() -> Dictionary:
	var names := _side_names()
	var seats := []
	for i in 2:
		seats.append({"name": "", "ai": side_ai[i], "level": 1})
	return {"scenario": scen_id, "sit": sit, "match": _match(), "seats": seats, "style": style, "anim": speed}


func _on_start() -> void:
	_store()
	main.start_game(_config())


# ================================================================ caricamento

func _load_panel() -> void:
	_store()
	var p := _overlay()
	var vb: VBoxContainer = p.get_meta("vb")
	vb.add_child(UI.title("Carica una partita", 44))
	vb.add_child(UI.wrap(UI.label("Scrivi il codice di sei lettere che hai ricevuto quando hai salvato.", 19), 700))
	var le := _line("Codice", 6)
	le.text_changed.connect(func(t):
		le.text = t.to_upper()
		le.caret_column = t.length())
	vb.add_child(le)
	var msg := UI.wrap(UI.label("", 19, UI.RED_D), 700)
	vb.add_child(msg)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	vb.add_child(r)
	var bo := UI.primary(UI.button("Carica", 240, 56, 22))
	r.add_child(bo)
	var bc := UI.button("Indietro", 200, 56, 20)
	bc.pressed.connect(func(): p.queue_free())
	r.add_child(bc)
	bo.pressed.connect(func():
		var code := le.text.strip_edges().to_upper()
		if code.length() != 6:
			msg.text = "Il codice ha sei lettere."
			return
		msg.text = "Carico..."
		var net: Net = main.get_net()
		var d: Dictionary = await net.load_game(code)
		if d.is_empty():
			msg.text = "Partita %s non trovata. %s" % [code, net.last_error]
			return
		var cfg = str_to_var(str(d.get("cfg", "")))
		var acts = str_to_var(str(d.get("acts", "")))
		if not (cfg is Dictionary) or not (acts is Array):
			msg.text = "Salvataggio non leggibile."
			return
		cfg["preload"] = acts
		cfg["save_code"] = code
		cfg["style"] = style
		main.start_game(cfg))


func _overlay() -> Control:
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.06, 0.04, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(0.99))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.custom_minimum_size = Vector2(860, 0)
	box.offset_left = -430
	box.offset_right = 430
	box.offset_top = 110
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	p.set_meta("vb", vb)
	return p


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 56)
	le.add_theme_font_size_override("font_size", 24)
	return le


# ================================================================ online

func _online_join_panel() -> void:
	on_join = true
	_online_panel()


func _online_create_panel() -> void:
	on_join = false
	_online_panel()


func _online_panel() -> void:
	_store()
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = _overlay()
	var vb: VBoxContainer = on_panel.get_meta("vb")
	vb.add_child(UI.title("Entra in una partita online" if on_join else "Crea una partita online", 44))
	var s := _scn()
	if on_join:
		vb.add_child(UI.wrap(UI.label("Scrivi il tuo nome e il codice di quattro lettere che ti ha mandato chi ha creato la stanza. Scenario e forze li ha già scelti lui.", 19, UI.MUTED), 800))
	else:
		vb.add_child(UI.wrap(UI.label("Scenario: %s%s. Scegli il tuo lato e crea la stanza: riceverai un codice da mandare all'avversario. Se nessuno entra, l'altro lato lo gioca il computer." % [s["nome"], (", " + SC.SIT_NAME[sit]) if SC.SIT_NAME.has(sit) else ""], 19, UI.MUTED), 800))
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var r0 := HBoxContainer.new()
	r0.add_theme_constant_override("separation", 8)
	r0.visible = not on_join
	vb.add_child(r0)
	r0.add_child(UI.label("Tu giochi:", 19))
	var names := _side_names()
	for i in 2:
		var k: int = i
		var b := UI.toggled(UI.button(names[i], 0, 44, 17), host_side == i)
		b.pressed.connect(func():
			host_side = k
			_online_panel())
		r0.add_child(b)
	var b_create := UI.primary(UI.button("Crea una stanza", 0, 56, 22))
	b_create.pressed.connect(_online_create)
	b_create.visible = not on_join
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := UI.button("Entra", 200, 56, 22)
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	row.visible = on_join
	vb.add_child(row)
	on_lbl = UI.wrap(UI.label("", 20, UI.INK), 780)
	on_lbl.custom_minimum_size.y = 100
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = UI.primary(UI.button("Inizia online", 380, 60, 24))
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := UI.button("Indietro", 260, 60, 22)
	b_close.pressed.connect(func():
		main.lobby = {}
		on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s..." % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi Entra per rientrare." % ses["room"]


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seats_text(room: Dictionary, names: Array) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var w := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero (computer)"
		parts.append("%s: %s" % [names[int(idx)], w])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var seats := [host_side, 1 - host_side]
	_say("Creo la stanza...")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, seats)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": host_side, "names": _side_names()}
	net.remember_room(code, host_side)
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s..." % code)
	var net: Net = main.get_net()
	var s := await net.join_room(code, nm)
	if s == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if s == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": s, "names": ["Alpha", "Bravo"]}
	net.remember_room(code, s)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s..." % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		var names: Array = main.lobby.get("names", ["Alpha", "Bravo"])
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice al tuo avversario.\nPosti: %s.\nQuando c'è premi Inizia online." % [code, _seats_text(room, names)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ].\nAspetta che chi l'ha creata avvii la partita." % code)
		await get_tree().create_timer(2.0).timeout


func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in 2:
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary:
			cfg["seats"][i]["name"] = str(seats_db[k].get("name", ""))
			cfg["seats"][i]["ai"] = false
		else:
			cfg["seats"][i]["ai"] = true
	cfg["seed"] = 1 + randi() % 2000000000
	cfg.erase("style")
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	cfg["style"] = style
	cfg["anim"] = speed
	var ses := OnlineSession.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	main.lobby = {}
	main.start_game(cfg)
