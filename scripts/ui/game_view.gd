extends Control
## Schermata di gioco: mappa 3D, forze del giocatore, editor dei piani (movimento, fuoco, contromisure,
## lanci, fuoco d'opportunità, ricerca e trasporto, cannone laser, supporto orbitale), schieramento,
## registro degli eventi, tendina per passare il dispositivo, salvataggio, fine partita e replay.

const D = preload("res://scripts/data/ss_data.gd")
const SC = preload("res://scripts/data/scenari.gd")

var main
var config: Dictionary
var eng: SSEngine
var board: Board3D
var viewport_c: SubViewportContainer
var online: OnlineSession

# pannelli
var top_bar: PanelContainer
var lbl_title: Label
var lbl_phase: Label
var lbl_score: Label
var left_panel: PanelContainer
var left_box: VBoxContainer
var right_panel: PanelContainer
var right_box: VBoxContainer
var log_panel: PanelContainer
var log_text: RichTextLabel
var log_scroll: ScrollContainer
var hover_panel: PanelContainer
var hover_lbl: RichTextLabel
var action_bar: HBoxContainer
var msg_lbl: Label
var curtain: Control
var end_panel: Control
var overlay_panel: Control
var replay_bar: PanelContainer

# stato del piano
var req := {}                     # richiesta in corso
var seat := -1                    # lato che sta decidendo
var draft := {}                   # piano in costruzione
var sel := ""                     # unità selezionata
var mode := ""                    # "", "mv", "df", "rf", "ln:gpb", "lc", "lcr", "orb:b", "place"
var df_alt := 0
var place_item := ""              # schieramento: id unità, "c<i>", "m<i>"
var dep := {}                     # schieramento in costruzione
var my_seats: Array = []          # lati giocati su questo dispositivo
var last_hover := -1
var replay_i := -1
var replay_play := false
var _replay_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	eng = SSEngine.new()
	var cfg := config.duplicate()
	if cfg.has("online"):
		online = cfg["online"]
		cfg.erase("online")
	var pre: Array = cfg.get("preload", [])
	cfg.erase("preload")
	eng.setup(cfg)
	eng.preload_acts = pre
	if online != null:
		eng.online = online
		online.view = self
		add_child(online)
		my_seats = [online.seat]
	else:
		for i in 2:
			if not eng.players[i]["ai"]:
				my_seats.append(i)
	add_child(eng)
	_build_ui()
	eng.changed.connect(_on_changed)
	eng.log_added.connect(_on_log)
	eng.decision_requested.connect(_on_request)
	eng.fx.connect(_on_fx)
	eng.game_ended.connect(_on_end)
	board.picked_hex.connect(_on_hex)
	board.picked_unit.connect(_on_unit)
	board.hover_hex.connect(_on_hover)
	_viewer_default()
	board.reset_view()
	_refresh()
	if online != null:
		online.heartbeat_loop()
	await get_tree().process_frame
	eng.run()


func _viewer_default() -> void:
	if my_seats.size() == 1:
		board.viewer = my_seats[0]
	elif my_seats.is_empty():
		board.viewer = -1
	else:
		board.viewer = -2


# ================================================================ costruzione

func _build_ui() -> void:
	viewport_c = SubViewportContainer.new()
	viewport_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_c.stretch = true
	viewport_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_c)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	viewport_c.add_child(vp)
	board = Board3D.new()
	vp.add_child(board)
	board.setup(eng, 0, str(config.get("style", "originale")))
	board.gui_hit = func(sp): return _gui_hit(sp)
	# barra in alto
	top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", UI.box(Color(UI.PAPER, 0.96), UI.SEPIA, 0, 0, 8))
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 66
	add_child(top_bar)
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 14)
	top_bar.add_child(tb)
	lbl_title = UI.title("StarSoldier", 34)
	tb.add_child(lbl_title)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -4)
	tb.add_child(tv)
	var sname: String = eng.sc["nome"] + ((" · " + SC.SIT_NAME[eng.sit]) if SC.SIT_NAME.has(eng.sit) else "")
	tv.add_child(UI.head(sname, 20, UI.INK))
	lbl_phase = UI.label("", 17, UI.RED_D)
	tv.add_child(lbl_phase)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_child(sp)
	lbl_score = UI.head("", 20, UI.SEPIA)
	tb.add_child(lbl_score)
	for b in [["Vista", _reset_view], ["Grafica", _toggle_style], ["Etichette", _toggle_labels], ["Tabelle", _show_tables], ["Regole", _show_rules], ["Salva", _save], ["Menu", _to_menu]]:
		var bt := UI.button(b[0], 0, 46, 18)
		bt.pressed.connect(b[1])
		tb.add_child(bt)
	# pannello sinistro: forze
	left_panel = PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	left_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_panel.offset_top = 76
	left_panel.offset_left = 8
	left_panel.offset_right = 392
	left_panel.offset_bottom = -8
	add_child(left_panel)
	var ls := ScrollContainer.new()
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(ls)
	left_box = VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 6)
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(left_box)
	# pannello destro: piano dell'unità e registro
	right_panel = PanelContainer.new()
	right_panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	right_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_panel.offset_top = 76
	right_panel.offset_left = -440
	right_panel.offset_right = -8
	right_panel.offset_bottom = -330
	add_child(right_panel)
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(rs)
	right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(right_box)
	log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	log_panel.offset_top = -320
	log_panel.offset_left = -440
	log_panel.offset_right = -8
	log_panel.offset_bottom = -8
	add_child(log_panel)
	var lv := VBoxContainer.new()
	log_panel.add_child(lv)
	lv.add_child(UI.head("REGISTRO", 17, UI.RED_D))
	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(log_scroll)
	log_text = UI.rich(15)
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_text)
	# informazioni sull'esagono sotto il puntatore
	hover_panel = PanelContainer.new()
	hover_panel.add_theme_stylebox_override("panel", UI.box(Color(UI.PAPER_L, 0.92), UI.SEPIA, 1, 4, 8))
	hover_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hover_panel.offset_left = 402
	hover_panel.offset_bottom = -8
	hover_panel.offset_top = -120
	hover_panel.offset_right = 900
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.visible = false
	add_child(hover_panel)
	hover_lbl = UI.rich(15)
	hover_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.add_child(hover_lbl)
	# barra delle azioni in basso al centro
	var ab_panel := PanelContainer.new()
	ab_panel.add_theme_stylebox_override("panel", UI.box(Color(UI.PAPER, 0.95), UI.SEPIA, 2, 4, 8))
	ab_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ab_panel.offset_bottom = -130
	ab_panel.offset_top = -200
	ab_panel.offset_left = -330
	ab_panel.offset_right = 230
	ab_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(ab_panel)
	ab_panel.visible = false
	ab_panel.name = "azioni"
	var abv := VBoxContainer.new()
	ab_panel.add_child(abv)
	msg_lbl = UI.label("", 17, UI.RED_D)
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abv.add_child(msg_lbl)
	action_bar = HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 10)
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	abv.add_child(action_bar)


func _gui_hit(sp: Vector2) -> bool:
	for c in [top_bar, left_panel, right_panel, log_panel, get_node_or_null("azioni"), curtain, end_panel, overlay_panel, replay_bar]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(sp):
			return true
	return false


func _ab_panel() -> PanelContainer:
	return get_node("azioni")


# ================================================================ aggiornamento

func _on_changed() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	board.refresh()
	_update_top()
	_update_left()
	_update_right()
	_update_overlays()


func _update_top() -> void:
	var ph := {"schieramento": "Schieramento", "comando": "Comunicazioni di comando", "piano": "Piani segreti", "fuoco": "Fuoco e lanci", "movimento": "Movimento", "detonazione": "Dispersione e detonazioni", "recupero": "Recupero", "orbitale": "Bombardamento orbitale", "fine": "Partita finita"}
	var t := "Turno %d" % eng.turn if eng.turn > 0 else "Preparazione"
	if eng.std and eng.turn > 0:
		t += ", stadio %d" % eng.stage
	t += " · " + str(ph.get(eng.phase, eng.phase))
	if eng.turn > 0:
		t += " · limite %d turni" % eng.max_turns
	lbl_phase.text = t
	lbl_score.text = eng.score_text()


func _update_left() -> void:
	for c in left_box.get_children():
		c.queue_free()
	var sides_to_show: Array = my_seats.duplicate() if not my_seats.is_empty() else [0, 1]
	if seat >= 0 and my_seats.size() > 1:
		sides_to_show = [seat]
	for s in [0, 1]:
		var mine: bool = s in sides_to_show
		var sd: Dictionary = eng.sides[s]
		left_box.add_child(UI.head(eng.pname(s), 20, UI.side_color(s)))
		var info := []
		if eng.std and int(sd["pl"]) > 0:
			info.append("TP persi %d / preservazione %d%s" % [sd["lost"], sd["pl"], " (superata)" if sd["pres_pending"] else ""])
		if not sd["orb"].is_empty():
			var q: Dictionary = sd["orb"]
			info.append("Orbitale per turno: %d bombardamenti, %d laser, %d bombe opacizzanti" % [q.get("b", 0), q.get("l", 0), q.get("o", 0)])
		if eng.std and int(sd["ccp"]) > 0:
			info.append("Vittime civili causate: %d" % sd["ccp"])
		if eng.sit == "P" and s == 0:
			info.append("Usciti dal bordo della base: %d" % (int(sd["pts"]) / 10))
		for line in info:
			left_box.add_child(UI.wrap(UI.label(line, 15, UI.MUTED), 350))
		if not mine:
			var known := 0
			for u in eng.live(s):
				if eng.visible_to(u, board.viewer if board.viewer >= 0 else 1 - s) and u["on"]:
					known += 1
			left_box.add_child(UI.label("Unità visibili sulla mappa: %d" % known, 15, UI.MUTED))
			left_box.add_child(UI.hsep())
			continue
		for u in eng.units.values():
			if u["side"] != s:
				continue
			left_box.add_child(_unit_row(u))
		left_box.add_child(UI.hsep())


func _unit_row(u: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	b.add_child(hb)
	var tr := TextureRect.new()
	tr.texture = board._counter_tex(u, u["alt"] > 0)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(44, 44)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tr)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	var st := ""
	if u["dead"]:
		st = "eliminato"
	elif u["exited"]:
		st = "uscito dalla mappa"
	elif not u["on"]:
		st = "entra dal bordo %s" % eng._edge_name(u["entry"]) if u["entry"] != "" else "fuori mappa"
	else:
		st = "%s · %s" % [Hex.label(u["h"]), eng.ALT_NAME[u["alt"]]]
		if u["hidden"]:
			st += " · nascosto"
		if u["ind"]:
			st += " · indipendente"
		if u["leader"]:
			st += " · capo"
	var name := "%s  %s" % [u["lab"], D.KIND_NAME.get(u["kind"], "")]
	var l1 := UI.label(name, 16, UI.INK if alive_u(u) else UI.MUTED, UI.font_head)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	var l2 := UI.label(st, 14, UI.MUTED)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l2)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sp)
	var tp := "%d/%d" % [u["tpa"], u["tpa0"]]
	if mode != "place" and seat == u["side"] and alive_u(u) and req.get("k", "") == "piano":
		var t: Dictionary = draft.get("u", {}).get(u["id"], {})
		tp = "%s / %d" % [_n(eng.task_cost(u, t)), eng.avail(u)]
	var l3 := UI.mono(tp, 17, UI.RED_D if u["tpa"] < u["tpa0"] else UI.INK)
	l3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(l3)
	if u["id"] == sel:
		UI.toggled(b, true)
		l1.add_theme_color_override("font_color", UI.PAPER_L)
		l2.add_theme_color_override("font_color", UI.PAPER_D)
		l3.add_theme_color_override("font_color", UI.PAPER_L)
	b.disabled = not alive_u(u)
	var id: String = u["id"]
	b.pressed.connect(func(): _select(id, true))
	return b


func alive_u(u: Dictionary) -> bool:
	return eng.alive(u)


func _n(v: float) -> String:
	return str(int(v)) if absf(v - roundf(v)) < 0.01 else "%.1f" % v


# ================================================================ registro ed effetti

func _on_log(t: String) -> void:
	var col := "#2b1a10"
	if t.begins_with("—"):
		col = "#a62a17"
		t = "[b]" + t + "[/b]"
	elif t.find("eliminat") >= 0 or t.find("Vince") >= 0 or t.find("vaporizz") >= 0:
		col = "#a62a17"
	log_text.append_text("[color=%s]%s[/color]\n" % [col, t])
	await get_tree().process_frame
	if is_instance_valid(log_scroll):
		log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func _on_fx(kind: String, d: Dictionary) -> void:
	if eng.replaying() or (online != null and online.catchup):
		return
	if kind in ["move", "dead", "crater", "smoke", "smoke_off", "exit", "civ", "teleport", "found", "search", "hm_on", "hm_move", "blast", "stage_end", "plotted", "turn", "deploy", "start"]:
		board.refresh()
	board.play_fx(kind, d, eng.anim)
	if kind in ["dead", "stage_end", "plotted", "turn", "exit", "deploy"]:
		_update_left()
		_update_top()


# ================================================================ richieste del motore

func _on_request(r: Dictionary) -> void:
	req = r
	seat = int(r.get("seat", 0))
	mode = ""
	sel = ""
	if my_seats.size() > 1:
		await _show_curtain(seat)
	board.viewer = seat
	match str(r.get("k", "")):
		"schiera":
			_start_deploy()
		"piano":
			_start_plot()
	_refresh()


func _show_curtain(s: int) -> void:
	board.viewer = -2
	board.refresh()
	curtain = Control.new()
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)
	var sh := UI.Airbrush.new()
	curtain.add_child(sh)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	curtain.add_child(vb)
	vb.add_child(UI.title("Tocca a %s" % eng.sides[s]["nome"], 56))
	var t := UI.label("Passa il dispositivo: il piano è segreto.", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var b := UI.primary(UI.button("Sono pronto", 320, 70, 26))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(b)
	board.input_locked = true
	await b.pressed
	board.input_locked = false
	curtain.queue_free()
	curtain = null


func _finish_decision(r) -> void:
	var s := seat
	req = {}
	seat = -1
	mode = ""
	sel = ""
	_ab_panel().visible = false
	_viewer_default()
	if my_seats.size() > 1:
		board.viewer = -2
	board.set_overlays([])
	board.highlight(-1)
	eng.provide_decision(r)
	_refresh()


# ================================================================ schieramento

func _start_deploy() -> void:
	dep = SSAI.new(1).auto_deploy(eng, seat, req)
	place_item = ""
	mode = "place"
	_ab_panel().visible = true
	_set_actions([["Schieramento automatico", func():
		dep = SSAI.new(1).auto_deploy(eng, seat, req)
		_refresh()], ["Conferma lo schieramento", _confirm_deploy, true]])
	msg_lbl.text = "Scegli un pezzo a destra, poi tocca l'esagono dove metterlo."
	_apply_dep_preview()


func _apply_dep_preview() -> void:
	# anteprima: si spostano davvero le unità del lato (il motore le rimette al loro posto alla conferma)
	for id in req.get("units", []):
		var u: Dictionary = eng.units[id]
		var h := int(dep["pos"].get(id, 0))
		u["h"] = h
		u["on"] = Hex.valid(h)
		u["alt"] = 2 if u["kind"] == "pl" else int(req.get("alt", 0))
	for i in eng.civs.size():
		if i < dep.get("civ", []).size():
			eng.civs[i]["h"] = int(dep["civ"][i])
		if eng.sit == "B" and i < dep.get("gen", []).size():
			eng.civs[i]["genuine"] = bool(dep["gen"][i])
	var k := 0
	for m in eng.missiles:
		if m["side"] == seat and m["mine"]:
			m["h"] = int(dep["mine"][k]) if k < dep.get("mine", []).size() else 0
			k += 1
	_refresh()


func _confirm_deploy() -> void:
	# vincoli del gioco base: al massimo tre segnalini e due veri per gruppo di città
	if eng.sit == "B" and seat == 1:
		var err := eng.civ_error(dep.get("civ", []), dep.get("gen", []))
		if err != "":
			msg_lbl.text = "Schieramento non valido: %s." % err
			return
	_finish_decision(dep.duplicate(true))


func _deploy_panel() -> void:
	right_box.add_child(UI.title("Schieramento", 34))
	var txt := "Tocca un pezzo e poi l'esagono dove metterlo."
	if eng.sit in ["R", "A"] and seat == 1:
		txt += " Le tue forze restano nascoste all'avversario finché non spendono punti di compito; le basi finché un soldato Alpha non passa entro quattro esagoni. Schierati ad almeno dieci colonne dal bordo Ovest."
	if eng.sit == "A" and seat == 0:
		txt += " Le tue forze scendono dall'orbita in alta quota. Scegli anche dove cadranno i dieci bombardamenti preparatori e le tre bombe opacizzanti."
	if eng.sit == "B":
		txt += " Dieci segnalini di civili nelle città: tre veri (segnati «vero») e sette fittizi. Tocca un segnalino schierato per cambiarlo da vero a finto."
	right_box.add_child(UI.wrap(UI.label(txt, 16, UI.MUTED), 400))
	var items := []
	for id in req.get("units", []):
		items.append([id, eng.units[id]["lab"], Hex.label(int(dep["pos"].get(id, 0)))])
	for i in eng.civs.size():
		if int(req.get("civ", 0)) > 0:
			var g := ""
			if eng.sit == "B":
				g = " (vero)" if bool(dep["gen"][i]) else " (finto)"
			items.append(["c%d" % i, "Civili %d%s" % [i + 1, g], Hex.label(int(dep["civ"][i]))])
	for i in dep.get("mine", []).size():
		items.append(["m%d" % i, "Missile nascosto %d" % (i + 1), Hex.label(int(dep["mine"][i]))])
	if dep.get("orb", {}).has("b") and req.has("orb_pre"):
		for i in dep["orb"]["b"].size():
			items.append(["ob%d" % i, "Bombardamento %d" % (i + 1), Hex.label(int(dep["orb"]["b"][i]))])
		for i in dep["orb"]["o"].size():
			items.append(["oo%d" % i, "Bomba opacizzante %d" % (i + 1), Hex.label(int(dep["orb"]["o"][i]))])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	right_box.add_child(grid)
	for it in items:
		var k: String = it[0]
		var b := UI.toggled(UI.button("%s · %s" % [it[1], it[2]], 196, 40, 15), place_item == k)
		b.pressed.connect(func():
			if eng.sit == "B" and k.begins_with("c") and place_item == k:
				var i2 := int(k.substr(1))
				dep["gen"][i2] = not dep["gen"][i2]
				_apply_dep_preview()
				return
			place_item = k
			var h := _item_hex(k)
			if Hex.valid(h):
				board.focus_hex(h)
			_refresh())
		grid.add_child(b)


func _item_hex(k: String) -> int:
	if k.begins_with("ob"):
		return int(dep["orb"]["b"][int(k.substr(2))])
	if k.begins_with("oo"):
		return int(dep["orb"]["o"][int(k.substr(2))])
	if k.begins_with("c") and not eng.units.has(k):
		return int(dep["civ"][int(k.substr(1))])
	if k.begins_with("m") and not eng.units.has(k):
		return int(dep["mine"][int(k.substr(1))])
	return int(dep["pos"].get(k, 0))


func _place(h: int) -> void:
	if place_item == "":
		msg_lbl.text = "Prima scegli un pezzo a destra."
		return
	var k := place_item
	if k.begins_with("ob"):
		dep["orb"]["b"][int(k.substr(2))] = h
	elif k.begins_with("oo"):
		dep["orb"]["o"][int(k.substr(2))] = h
	elif k.begins_with("c") and not eng.units.has(k):
		if eng.sit == "B" and D.terrain(h) != "u":
			msg_lbl.text = "I civili vanno in un esagono urbano."
			return
		dep["civ"][int(k.substr(1))] = h
	elif k.begins_with("m") and not eng.units.has(k):
		dep["mine"][int(k.substr(1))] = h
	else:
		if not eng.deploy_zone_ok(seat, h, req):
			msg_lbl.text = "Esagono fuori dalla zona di schieramento."
			return
		dep["pos"][k] = h
	msg_lbl.text = "%s in %s." % [k, Hex.label(h)]
	_apply_dep_preview()


# ================================================================ piano

func _start_plot() -> void:
	draft = {"u": {}, "orb": []}
	_ab_panel().visible = true
	_set_actions([["Piano automatico", _auto_plan], ["Cancella tutto", func():
		draft = {"u": {}, "orb": []}
		mode = ""
		_refresh()], ["Conferma il piano", _confirm_plot, true]])
	var first := ""
	for u in eng.live(seat):
		if (u["on"] or u["entry"] != "") and u["kind"] != "base":
			first = u["id"]
			break
	msg_lbl.text = "Scegli un soldato e assegnagli i compiti. %s" % ("Stadio %d: al massimo 6 TP per soldato." % eng.stage if eng.std else "")
	if first != "":
		_select(first, true)


func _set_actions(list: Array) -> void:
	for c in action_bar.get_children():
		c.queue_free()
	for a in list:
		var b := UI.button(a[0], 0, 50, 19)
		if a.size() > 2 and a[2]:
			UI.primary(b)
		b.pressed.connect(a[1])
		action_bar.add_child(b)


func _auto_plan() -> void:
	var p: Dictionary = eng.ais[seat].plan(eng, seat)
	draft = p
	mode = ""
	msg_lbl.text = "Piano proposto dal computer: puoi modificarlo prima di confermare."
	_refresh()


func _confirm_plot() -> void:
	var p := draft.duplicate(true)
	_finish_decision(p)


func _tasks(id: String) -> Dictionary:
	if not draft["u"].has(id):
		draft["u"][id] = {}
	return draft["u"][id]


func _select(id: String, focus := false) -> void:
	sel = id
	mode = ""
	board.select(id)
	var u: Dictionary = eng.units.get(id, {})
	if focus and not u.is_empty() and u["on"]:
		board.focus_hex(u["h"])
	_refresh()


func _on_unit(id: String) -> void:
	var u: Dictionary = eng.units[id]
	# in modalità bersaglio un clic su un'unità vale come clic sul suo esagono
	if mode in ["df", "lc", "lcr", "mv", "place"] or mode.begins_with("ln:") or mode.begins_with("orb:"):
		if mode == "place" and u["side"] == seat and req.get("units", []).has(id):
			place_item = id
			_refresh()
			return
		_on_hex(u["h"], u["alt"])
		return
	if mode == "rf":
		if u["side"] != seat:
			_add_rf(u)
		return
	if seat >= 0 and u["side"] == seat:
		_select(id)
	else:
		_info_unit(u)


func _on_hex(h: int, alt := -1) -> void:
	if seat < 0:
		_hover_info(h)
		return
	if mode == "place":
		_place(h)
		return
	if sel == "" or not eng.units.has(sel):
		_pick_unit_at(h)
		return
	var u: Dictionary = eng.units[sel]
	match mode:
		"mv":
			_add_step(u, h)
		"df":
			_add_df(u, h, alt)
		"lc", "lcr":
			_tasks(sel)["lc"] = {"h": h, "alt": alt if alt >= 0 else _enemy_alt(h, 0), "reg": mode == "lcr"}
			mode = ""
			_refresh()
		_:
			if mode.begins_with("ln:"):
				_add_ln(u, mode.substr(3), h)
			elif mode.begins_with("orb:"):
				_add_orb(mode.substr(4), h, alt)
			else:
				_pick_unit_at(h)


func _pick_unit_at(h: int) -> void:
	for u in eng.units_at(h):
		if u["side"] == seat:
			_select(u["id"])
			return
	_hover_info(h)


func _enemy_alt(h: int, dflt: int) -> int:
	for o in eng.units_at(h):
		if o["side"] != seat and eng.visible_to(o, seat):
			return o["alt"]
	return dflt


func _avail_left(u: Dictionary, t: Dictionary) -> float:
	return float(eng.avail(u)) - eng.task_cost(u, t)


func _add_step(u: Dictionary, h: int) -> void:
	var t := _tasks(u["id"])
	var mv: Array = t.get("mv", [])
	var sp := eng.sim_path(u, mv, int(t.get("alt0", 1)) if not u["on"] else -1)
	var cur: int = sp["h"]
	var alt: int = sp["alt"]
	var steps := []
	if not u["on"] and mv.is_empty():
		if not eng._entry_ok(u, h):
			msg_lbl.text = "Si entra da un esagono del bordo %s." % eng._edge_name(u["entry"])
			return
		steps = [h]
	elif cur <= 0:
		return
	elif Hex.dist(cur, h) == 1:
		steps = [h]
	elif Hex.dist(cur, h) > 1:
		steps = SSAI.new(1)._path(eng, cur, h, alt)
	if steps.is_empty():
		return
	var left := _avail_left(u, t)
	var added := 0
	for s in steps:
		var c := eng.move_cost(s, alt)
		if c > left + 0.001:
			break
		mv.append(s)
		left -= c
		added += 1
	if added == 0:
		msg_lbl.text = "Non bastano i punti di compito per entrare in %s." % Hex.label(steps[0])
		return
	t["mv"] = mv
	msg_lbl.text = ""
	_refresh()


func _add_alt(u: Dictionary, a: String) -> void:
	var t := _tasks(u["id"])
	var mv: Array = t.get("mv", [])
	if not u["on"] and mv.is_empty():
		t["alt0"] = eng.ALT_SHORT.find(a)
		_refresh()
		return
	var sp := eng.sim_path(u, mv, int(t.get("alt0", 1)) if not u["on"] else -1)
	var na := eng.ALT_SHORT.find(a)
	if na == sp["alt"]:
		return
	var c := float(eng.ALT_COST[sp["alt"]][na])
	if c > _avail_left(u, t) + 0.001:
		msg_lbl.text = "Cambiare quota costa %d TP." % int(c)
		return
	mv.append(a)
	t["mv"] = mv
	_refresh()


func _add_df(u: Dictionary, h: int, alt: int) -> void:
	var t := _tasks(u["id"])
	if alt < 0:
		alt = _enemy_alt(h, df_alt)
	if not eng.lof(seat, u["h"], u["alt"], h, alt, false, u["id"]):
		msg_lbl.text = "Linea di fuoco bloccata verso %s (%s)." % [Hex.label(h), eng.ALT_NAME[alt]]
		return
	if eng.sit == "B" and eng._civ_marker_at(h):
		msg_lbl.text = "In un esagono con civili si usa solo il fuoco ristretto."
		return
	if _avail_left(u, t) < 1.0:
		msg_lbl.text = "Non restano punti di compito."
		return
	var df: Array = t.get("df", [])
	for f in df:
		if f["h"] == h and f["alt"] == alt:
			return
	var tp := clampi(int(floor(_avail_left(u, t))), 1, 3)
	df.append({"h": h, "alt": alt, "tp": tp})
	t["df"] = df
	mode = ""
	_refresh()


func _add_rf(tu: Dictionary) -> void:
	var u: Dictionary = eng.units[sel]
	var t := _tasks(sel)
	if u["kind"] == "hw":
		msg_lbl.text = "Le armi pesanti non possono usare il fuoco ristretto."
		return
	if not eng.lof(seat, u["h"], u["alt"], tu["h"], tu["alt"], true, u["id"]):
		msg_lbl.text = "Linea di fuoco bloccata verso %s." % tu["lab"]
		return
	if _avail_left(u, t) < 1.0:
		msg_lbl.text = "Non restano punti di compito."
		return
	var rf: Array = t.get("rf", [])
	rf.append({"u": tu["id"], "tp": clampi(int(floor(_avail_left(u, t))), 1, 3)})
	t["rf"] = rf
	mode = ""
	_refresh()


func _add_ln(u: Dictionary, w: String, h: int) -> void:
	var t := _tasks(u["id"])
	var d := Hex.dist(u["h"], h)
	var tp := 3
	if w in ["ffm", "og"] and d > 10:
		msg_lbl.text = "Gittata massima 10 esagoni."
		return
	if w == "hm":
		if d < 15:
			msg_lbl.text = "Il missile cercatore va lanciato ad almeno 15 esagoni."
			return
		tp = maxi(3, int(ceil(float(d) / 5.0)))
	if eng.sit == "B" and seat == 1 and eng._civ_marker_at(h) and not eng._genuine_taken_by_enemy(h):
		msg_lbl.text = "Non si lancia sui civili."
		return
	if float(tp) > _avail_left(u, t) + 0.001:
		msg_lbl.text = "Servono %d TP." % tp
		return
	var ln: Array = t.get("ln", [])
	ln.append({"w": w, "h": h, "tp": tp, "hi": false})
	t["ln"] = ln
	mode = ""
	_refresh()


func _add_orb(k: String, h: int, alt: int) -> void:
	var q: Dictionary = eng.sides[seat]["orb"]
	var used := 0
	for o in draft["orb"]:
		if o["t"] == k:
			used += 1
	used += int(eng.orb_used[seat].get(k, 0))
	if used >= int(q.get(k, 0)):
		msg_lbl.text = "Quota di questo turno esaurita."
		return
	draft["orb"].append({"t": k, "h": h, "alt": alt if alt >= 0 else _enemy_alt(h, 0)})
	mode = ""
	_refresh()


# ================================================================ pannello destro

func _update_right() -> void:
	for c in right_box.get_children():
		c.queue_free()
	if req.get("k", "") == "schiera" and seat >= 0:
		_deploy_panel()
		return
	if req.get("k", "") == "piano" and seat >= 0:
		if sel != "" and eng.units.has(sel) and eng.units[sel]["side"] == seat:
			_plot_panel(eng.units[sel])
		else:
			right_box.add_child(UI.head("Scegli un soldato", 24))
		if not eng.sides[seat]["orb"].is_empty():
			_orbital_panel()
		return
	# fuori dal piano: scheda dello scenario
	right_box.add_child(UI.head(eng.sc["nome"], 24, UI.RED_D))
	var txt: String = SC.SIT_TEXT.get(eng.sit, eng.sc["testo"])
	right_box.add_child(UI.wrap(UI.label(txt, 15, UI.MUTED), 400))
	if seat < 0 and not eng.over:
		var who := "Esecuzione dei piani..." if eng.phase != "piano" else "Il computer prepara il suo piano..."
		if online != null and eng.phase == "piano":
			who = "In attesa del piano dell'avversario..."
		right_box.add_child(UI.label(who, 18, UI.INK))


func _plot_panel(u: Dictionary) -> void:
	var t: Dictionary = draft["u"].get(u["id"], {})
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	right_box.add_child(hb)
	var tr := TextureRect.new()
	tr.texture = board._counter_tex(u, u["alt"] > 0)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(72, 72)
	hb.add_child(tr)
	var v := VBoxContainer.new()
	hb.add_child(v)
	v.add_child(UI.head("%s · %s" % [u["lab"], D.KIND_NAME.get(u["kind"], "")], 22))
	var where := "%s, %s" % [Hex.label(u["h"]), eng.ALT_NAME[u["alt"]]] if u["on"] else "fuori mappa: entra dal bordo %s" % eng._edge_name(u["entry"])
	v.add_child(UI.label(where, 15, UI.MUTED))
	v.add_child(UI.label("TPA %d/%d · efficienza %s · recupero %d" % [u["tpa"], u["tpa0"], _n(eng.eff(u)), u["rec"]], 15, UI.MUTED))
	var cost := eng.task_cost(u, t)
	var av := eng.avail(u)
	var bar := ProgressBar.new()
	bar.max_value = maxf(1.0, float(av))
	bar.value = cost
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", UI.box(UI.PAPER_D, UI.SEPIA, 1, 3, 0))
	bar.add_theme_stylebox_override("fill", UI.box(UI.RED, UI.RED_D, 0, 3, 0))
	right_box.add_child(bar)
	right_box.add_child(UI.label("Punti usati %s su %d disponibili in questo %s" % [_n(cost), av, "stadio" if eng.std else "turno"], 16, UI.RED_D if cost > av else UI.INK))
	if u["ind"]:
		right_box.add_child(UI.wrap(UI.label("Fuori dalle comunicazioni di comando: spara e lancia dopo i soldati in comando.", 14, UI.MUTED), 400))
	if u["kind"] == "dink":
		return
	var entering: bool = not u["on"]
	# movimento
	right_box.add_child(UI.hsep())
	right_box.add_child(UI.head("MOVIMENTO", 18, UI.SEPIA))
	var mv: Array = t.get("mv", [])
	var sp := eng.sim_path(u, mv, int(t.get("alt0", 1)) if entering else -1)
	var path_txt := ""
	if entering:
		path_txt = "Entra in %s. " % eng.ALT_NAME[int(t.get("alt0", 1))]
	for s in mv:
		path_txt += ("» %s " % eng.ALT_NAME[eng.ALT_SHORT.find(s)]) if s is String else ("» esce " if int(s) == -1 else "» %s " % Hex.label(int(s)))
	if mv.is_empty():
		path_txt += "Nessun movimento."
	else:
		path_txt += "(costo %s, effetto movimento +%d)" % [_n(sp["cost"]), int(floor(sp["cost"] + 0.001))]
	right_box.add_child(UI.wrap(UI.label(path_txt, 15), 400))
	var r1 := HFlowContainer.new()
	r1.add_theme_constant_override("h_separation", 6)
	r1.add_theme_constant_override("v_separation", 6)
	right_box.add_child(r1)
	var bm := UI.toggled(UI.button("Traccia percorso", 0, 40, 16), mode == "mv")
	bm.pressed.connect(func():
		mode = "mv" if mode != "mv" else ""
		msg_lbl.text = "Tocca gli esagoni del percorso (anche lontani: il percorso più economico)." if mode == "mv" else ""
		_refresh())
	r1.add_child(bm)
	if u["kind"] != "pl":
		for a in [["T", "A terra"], ["R", "Volo radente"], ["A", "Alta quota"]]:
			var aa: String = a[0]
			var ba := UI.button(a[1], 0, 40, 16)
			if entering and mv.is_empty():
				UI.toggled(ba, int(t.get("alt0", 1)) == eng.ALT_SHORT.find(aa))
			ba.pressed.connect(func(): _add_alt(u, aa))
			r1.add_child(ba)
	var bu := UI.button("Annulla passo", 0, 40, 16)
	bu.pressed.connect(func():
		if not mv.is_empty():
			mv.pop_back()
			t["mv"] = mv
			if mv.is_empty():
				t.erase("mv")
		_refresh())
	r1.add_child(bu)
	if not entering and sp["h"] > 0 and Hex.on_edge(sp["h"], "*") and (eng.sit in ["P", "B"]):
		var be := UI.button("Esce dalla mappa", 0, 40, 16)
		be.pressed.connect(func():
			var c := 0.5 if sp["alt"] > 0 else 1.0
			if c <= _avail_left(u, t) + 0.001:
				mv.append(-1)
				t["mv"] = mv
			_refresh())
		r1.add_child(be)
	if entering:
		right_box.add_child(UI.wrap(UI.label("Nello stadio d'ingresso si possono solo muovere e mettere contromisure.", 14, UI.MUTED), 400))
	# contromisure
	right_box.add_child(UI.hsep())
	right_box.add_child(_stepper("Contromisure (CM)", int(t.get("cm", 0)), func(v):
		if v <= 0:
			t.erase("cm")
		else:
			t["cm"] = v
		draft["u"][u["id"]] = t))
	if entering:
		return
	# fuoco
	right_box.add_child(UI.hsep())
	right_box.add_child(UI.head("FUOCO", 18, UI.SEPIA))
	var r2 := HFlowContainer.new()
	r2.add_theme_constant_override("h_separation", 6)
	r2.add_theme_constant_override("v_separation", 6)
	right_box.add_child(r2)
	var bdf := UI.toggled(UI.button("Fuoco diretto", 0, 40, 16), mode == "df")
	bdf.pressed.connect(func():
		mode = "df" if mode != "df" else ""
		msg_lbl.text = "Tocca l'esagono bersaglio (colpisce tutti i nemici a quella quota)." if mode == "df" else ""
		_refresh())
	r2.add_child(bdf)
	if u["kind"] != "hw":
		var brf := UI.toggled(UI.button("Fuoco ristretto", 0, 40, 16), mode == "rf")
		brf.pressed.connect(func():
			mode = "rf" if mode != "rf" else ""
			msg_lbl.text = "Tocca il soldato nemico bersaglio." if mode == "rf" else ""
			_refresh())
		r2.add_child(brf)
	for a in 3:
		var aa := a
		var bq := UI.toggled(UI.button("Quota %s" % eng.ALT_SHORT[a], 0, 40, 15), df_alt == a)
		bq.tooltip_text = "Quota del bersaglio per il fuoco diretto su un esagono senza nemici visibili"
		bq.pressed.connect(func():
			df_alt = aa
			_refresh())
		r2.add_child(bq)
	for f in t.get("df", []):
		var ff: Dictionary = f
		right_box.add_child(_task_row("Diretto su %s (%s)" % [Hex.label(f["h"]), eng.ALT_NAME[f["alt"]]], int(f["tp"]), _fire_hint(u, f["h"], f["alt"], int(f["tp"])), func(v):
			ff["tp"] = v, func():
			t["df"].erase(ff)))
	for f in t.get("rf", []):
		var ff2: Dictionary = f
		var tu: Dictionary = eng.units.get(f["u"], {})
		right_box.add_child(_task_row("Ristretto su %s" % tu.get("lab", "?"), int(f["tp"]), "", func(v):
			ff2["tp"] = v, func():
			t["rf"].erase(ff2)))
	if not t.has("mv"):
		right_box.add_child(_stepper("Fuoco d'opportunità", int(t.get("of", 0)), func(v):
			if v <= 0:
				t.erase("of")
				t.erase("ofs")
			else:
				t["of"] = v
				t["ofs"] = clampi(int(t.get("ofs", v)), 1, v)
			draft["u"][u["id"]] = t))
		if int(t.get("of", 0)) > 1:
			right_box.add_child(_stepper("   punti per colpo", int(t.get("ofs", 1)), func(v):
				t["ofs"] = clampi(v, 1, int(t["of"])), false))
	else:
		right_box.add_child(UI.label("Chi si muove non usa il fuoco d'opportunità.", 14, UI.MUTED))
	# lanci
	var ws: Array = eng.weapons(u)
	if not ws.is_empty():
		right_box.add_child(UI.hsep())
		right_box.add_child(UI.head("ARMI LANCIATE", 18, UI.SEPIA))
		var r3 := HFlowContainer.new()
		r3.add_theme_constant_override("h_separation", 6)
		r3.add_theme_constant_override("v_separation", 6)
		right_box.add_child(r3)
		var wn := {"gpb": "Bomba guidata", "ffm": "Missili liberi", "og": "Granata opacizzante", "hm": "Missile cercatore", "nb": "Bomba al neutrone"}
		for w in ws:
			var ww: String = w
			var bw := UI.toggled(UI.button(wn[w], 0, 40, 15), mode == "ln:" + w)
			bw.pressed.connect(func():
				mode = ("ln:" + ww) if mode != "ln:" + ww else ""
				msg_lbl.text = "Tocca l'esagono bersaglio." if mode != "" else ""
				_refresh())
			r3.add_child(bw)
		for l in t.get("ln", []):
			var ll: Dictionary = l
			var row := _task_row("%s su %s%s" % [wn[l["w"]], Hex.label(l["h"]), " (alta quota)" if l.get("hi", false) else ""], int(l["tp"]), "", func(v):
				ll["tp"] = maxi(v, 3) if ll["w"] in ["gpb", "nb", "hm"] else 3, func():
				t["ln"].erase(ll))
			right_box.add_child(row)
			if l["w"] in ["gpb", "nb", "ffm"]:
				var bh := UI.toggled(UI.button("Esplode in alta quota", 0, 36, 14), l.get("hi", false))
				bh.pressed.connect(func():
					ll["hi"] = not ll.get("hi", false)
					_refresh())
				right_box.add_child(bh)
	# ricerca e trasporto
	if eng.sit == "B":
		for c in eng.civs:
			if c["h"] != u["h"] or c["dead"]:
				continue
			if c["up"] and seat == 0:
				var bs := UI.toggled(UI.button("Cerca nel segnalino (1 TP, senza muoversi)", 0, 40, 15), t.get("se", false))
				bs.pressed.connect(func():
					if t.get("se", false):
						t.erase("se")
					else:
						t["se"] = true
					draft["u"][u["id"]] = t
					_refresh())
				right_box.add_child(bs)
			elif not c["up"] and c["genuine"]:
				var cid: String = c["id"]
				var btr := UI.toggled(UI.button("Trasporta il civile (3 TP)", 0, 40, 15), str(t.get("tr", "")) == cid)
				btr.pressed.connect(func():
					if str(t.get("tr", "")) == cid:
						t.erase("tr")
					else:
						t["tr"] = cid
					draft["u"][u["id"]] = t
					_refresh())
				right_box.add_child(btr)
	# cannone laser
	if u["kind"] == "pl":
		right_box.add_child(UI.hsep())
		right_box.add_child(UI.head("CANNONE LASER (0 TP)", 18, UI.SEPIA))
		if not u["laser"]:
			right_box.add_child(UI.label("Distrutto.", 15, UI.MUTED))
		else:
			var r4 := HBoxContainer.new()
			right_box.add_child(r4)
			for k in [["lc", "Spara"], ["lcr", "Registra un esagono"]]:
				var kk: String = k[0]
				var bl := UI.toggled(UI.button(k[1], 0, 40, 15), mode == kk)
				bl.pressed.connect(func():
					mode = kk if mode != kk else ""
					_refresh())
				r4.add_child(bl)
			var lc: Dictionary = t.get("lc", {})
			if not lc.is_empty():
				right_box.add_child(UI.label("%s %s" % ["Registra" if lc["reg"] else "Spara su", Hex.label(lc["h"])], 15))
			if not u["reg"].is_empty():
				var regs := []
				for h in u["reg"]:
					regs.append(Hex.label(h))
				right_box.add_child(UI.label("Registrato su: " + ", ".join(regs), 14, UI.MUTED))
	right_box.add_child(UI.hsep())
	var r5 := HBoxContainer.new()
	r5.add_theme_constant_override("separation", 6)
	right_box.add_child(r5)
	var bai := UI.button("Suggerisci (computer)", 0, 42, 16)
	bai.pressed.connect(func():
		draft["u"][u["id"]] = eng.ais[seat].plan_unit(eng, u, eng.ais[seat]._known_foes(eng, seat))
		_refresh())
	r5.add_child(bai)
	var bc := UI.button("Nessun compito", 0, 42, 16)
	bc.pressed.connect(func():
		draft["u"].erase(u["id"])
		_refresh())
	r5.add_child(bc)


func _fire_hint(u: Dictionary, h: int, alt: int, tp: int) -> String:
	var as_ := eng.eff(u) * float(tp) * (2.0 if u["kind"] == "hw" else 1.0)
	var parts := []
	for o in eng.units_at(h, alt):
		if o["side"] != seat and eng.visible_to(o, seat):
			var ds := float(eng.range_att(u["h"], u["alt"], h, alt)) + float(eng.terrain_def(o))
			parts.append("%s: attacco %s, difesa %s + CM e movimento" % [o["lab"], _n(as_), _n(ds)])
	return "; ".join(parts)


func _stepper(title: String, v: int, setter: Callable, refresh := true) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var l := UI.label(title, 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var bm := UI.button("-", 44, 38, 20)
	bm.pressed.connect(func():
		setter.call(maxi(0, v - 1))
		_refresh())
	hb.add_child(bm)
	hb.add_child(UI.mono("%d" % v, 20))
	var bp := UI.button("+", 44, 38, 20)
	bp.pressed.connect(func():
		var u: Dictionary = eng.units[sel]
		if _avail_left(u, draft["u"].get(sel, {})) < 1.0:
			msg_lbl.text = "Non restano punti di compito."
			return
		setter.call(v + 1)
		_refresh())
	hb.add_child(bp)
	return hb


func _task_row(title: String, v: int, hint: String, setter: Callable, remover: Callable) -> Control:
	var vb := VBoxContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	var l := UI.label(title, 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(l)
	var bm := UI.button("-", 40, 36, 18)
	bm.pressed.connect(func():
		setter.call(maxi(1, v - 1))
		_refresh())
	hb.add_child(bm)
	hb.add_child(UI.mono("%d" % v, 18))
	var bp := UI.button("+", 40, 36, 18)
	bp.pressed.connect(func():
		var u: Dictionary = eng.units[sel]
		if _avail_left(u, draft["u"].get(sel, {})) < 1.0:
			msg_lbl.text = "Non restano punti di compito."
			return
		setter.call(v + 1)
		_refresh())
	hb.add_child(bp)
	var bx := UI.button("Togli", 0, 36, 15)
	bx.pressed.connect(func():
		remover.call()
		_refresh())
	hb.add_child(bx)
	if hint != "":
		vb.add_child(UI.wrap(UI.label(hint, 13, UI.MUTED), 400))
	return vb


func _orbital_panel() -> void:
	right_box.add_child(UI.hsep(UI.RED))
	right_box.add_child(UI.head("SUPPORTO ORBITALE", 18, UI.RED_D))
	var q: Dictionary = eng.sides[seat]["orb"]
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 6)
	r.add_theme_constant_override("v_separation", 6)
	right_box.add_child(r)
	for k in [["b", "Bombardamento"], ["l", "Raffica laser"], ["o", "Bomba opacizzante"]]:
		var kk: String = k[0]
		var used := int(eng.orb_used[seat].get(kk, 0))
		for o in draft["orb"]:
			if o["t"] == kk:
				used += 1
		var left := int(q.get(kk, 0)) - used
		var b := UI.toggled(UI.button("%s (%d)" % [k[1], left], 0, 40, 15), mode == "orb:" + kk)
		b.disabled = left <= 0
		b.pressed.connect(func():
			mode = ("orb:" + kk) if mode != "orb:" + kk else ""
			msg_lbl.text = "Tocca l'esagono bersaglio." if mode != "" else ""
			_refresh())
		r.add_child(b)
	var names := {"b": "Bombardamento", "l": "Raffica laser", "o": "Bomba opacizzante"}
	for o in draft["orb"]:
		var oo: Dictionary = o
		var hb := HBoxContainer.new()
		right_box.add_child(hb)
		var l := UI.label("%s su %s" % [names[o["t"]], Hex.label(o["h"])], 15)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		var bx := UI.button("Togli", 0, 34, 14)
		bx.pressed.connect(func():
			draft["orb"].erase(oo)
			_refresh())
		hb.add_child(bx)


# ================================================================ sovrapposizioni

func _update_overlays() -> void:
	var items := []
	if req.get("k", "") == "piano" and seat >= 0:
		for id in draft.get("u", {}):
			var u: Dictionary = eng.units[id]
			var t: Dictionary = draft["u"][id]
			var strong: bool = id == sel
			var col := Color(UI.RED, 0.95) if strong else Color(UI.RED_L, 0.7)
			var mv: Array = t.get("mv", [])
			if not mv.is_empty():
				var pts := []
				var h: int = u["h"]
				var alt: int = u["alt"] if u["on"] else int(t.get("alt0", 1))
				if u["on"]:
					pts.append(board.point(h, alt))
				for s in mv:
					if s is String:
						alt = eng.ALT_SHORT.find(s)
					elif int(s) > 0:
						h = int(s)
					else:
						continue
					if h > 0:
						pts.append(board.point(h, alt))
				items.append({"k": "path", "pts": pts, "col": col})
				if h > 0:
					items.append({"k": "hex", "h": h, "col": col})
			var from := board.point(u["h"], u["alt"]) if u["on"] else Vector3.ZERO
			for f in t.get("df", []):
				items.append({"k": "fire", "a": from, "b": board.point(f["h"], f["alt"]), "col": Color("#ff3020", 0.9)})
				items.append({"k": "hex", "h": f["h"], "col": Color("#ff3020")})
			for f in t.get("rf", []):
				var tu: Dictionary = eng.units.get(f["u"], {})
				if not tu.is_empty():
					items.append({"k": "fire", "a": from, "b": board.point(tu["h"], tu["alt"]), "col": Color("#ff8020", 0.9)})
			for l in t.get("ln", []):
				items.append({"k": "fire", "a": from, "b": board.point(l["h"], 0), "col": Color("#ffd040", 0.9)})
				for hh in eng.blast(l["h"], l.get("hi", false)):
					items.append({"k": "fill", "h": hh, "col": Color(1, 0.8, 0.2, 0.25)})
			var lc: Dictionary = t.get("lc", {})
			if not lc.is_empty():
				items.append({"k": "fire", "a": from, "b": board.point(lc["h"], lc["alt"]), "col": Color("#ff2bd0", 0.9)})
		for o in draft.get("orb", []):
			items.append({"k": "hex", "h": o["h"], "col": Color("#ffcf5a")})
			if o["t"] == "b":
				for hh in eng.blast(o["h"], false):
					items.append({"k": "fill", "h": hh, "col": Color(1, 0.6, 0.1, 0.25)})
	if req.get("k", "") == "schiera" and seat >= 0 and place_item != "":
		var h2 := _item_hex(place_item)
		if Hex.valid(h2):
			items.append({"k": "hex", "h": h2, "col": UI.RED})
	board.set_overlays(items)


# ================================================================ informazioni sul puntatore

func _on_hover(h: int) -> void:
	last_hover = h
	_hover_info(h)


func _hover_info(h: int) -> void:
	if not Hex.valid(h):
		hover_panel.visible = false
		return
	hover_panel.visible = true
	var t := eng.terrain(h)
	var s := "[b]%s[/b] · %s (valore %d)" % [Hex.label(h), D.T_NAME[t], D.T_VALUE[t]]
	if eng.smoke.has(h):
		s += " · fumo"
	var parts := []
	for u in eng.units_at(h):
		if board.viewer >= 0 and not eng.visible_to(u, board.viewer):
			continue
		if board.viewer == -2 and u["hidden"]:
			continue
		parts.append("[color=%s]%s[/color] %s, TPA %d" % [UI.side_color(u["side"]).to_html(false), u["lab"], eng.ALT_NAME[u["alt"]], u["tpa"]])
	for c in eng.civs:
		if c["h"] == h and not c["dead"]:
			parts.append("civili")
	if not parts.is_empty():
		s += "\n" + "; ".join(parts)
	if sel != "" and eng.units.has(sel) and seat >= 0 and req.get("k", "") == "piano":
		var u: Dictionary = eng.units[sel]
		if u["on"]:
			var d := Hex.dist(u["h"], h)
			var ok := eng.lof(seat, u["h"], u["alt"], h, _enemy_alt(h, df_alt), false, u["id"])
			s += "\nDa %s: %d esagoni, attenuazione %d, linea di fuoco %s" % [u["lab"], d, eng.range_att(u["h"], u["alt"], h, _enemy_alt(h, df_alt)), "libera" if ok else "bloccata"]
	hover_lbl.text = s


func _info_unit(u: Dictionary) -> void:
	_hover_info(u["h"])


# ================================================================ comandi della barra

func _reset_view() -> void:
	board.reset_view()


func _toggle_style() -> void:
	board.set_style("reborn" if board.style == "originale" else "originale")
	_refresh()


func _toggle_labels() -> void:
	board.show_labels = not board.show_labels
	board.refresh()


func _show_tables() -> void:
	_rules_overlay("tabelle")


func _show_rules() -> void:
	_rules_overlay("regole")


func _rules_overlay(page: String) -> void:
	if is_instance_valid(overlay_panel):
		overlay_panel.queue_free()
	var rv := preload("res://scripts/ui/rules_view.gd").new()
	rv.page = page
	rv.embedded = true
	rv.closed.connect(func():
		board.input_locked = false
		overlay_panel = null)
	overlay_panel = rv
	board.input_locked = true
	add_child(rv)


func _save() -> void:
	var cfg := config.duplicate()
	cfg.erase("online")
	cfg.erase("preload")
	cfg.erase("save_code")
	if not cfg.has("seed"):
		cfg["seed"] = eng.rng.seed
	if online != null:
		# il salvataggio di una partita online si riprende contro il computer
		for i in 2:
			cfg["seats"][i]["ai"] = i != online.seat
	var data := {"cfg": var_to_str(_cfg_for_save(cfg)), "acts": var_to_str(eng.rec_acts)}
	_toast("Salvo la partita...")
	var net: Net = main.get_net()
	var code := await net.save_game(data, str(config.get("save_code", "")))
	if code == "":
		_toast("Salvataggio non riuscito: %s" % net.last_error)
		return
	config["save_code"] = code
	_toast("Partita salvata. Codice: %s (lo trovi in Carica partita)." % code, 8.0)


func _cfg_for_save(cfg: Dictionary) -> Dictionary:
	var out := {}
	for k in ["scenario", "sit", "match", "seats", "seed", "style", "anim", "max_turns"]:
		if cfg.has(k):
			out[k] = cfg[k]
	out["seed"] = eng.cfg.get("seed", eng.rng.seed)
	return out


func _toast(t: String, secs := 4.0) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.INK, UI.RED, 2, 4, 12))
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.offset_top = 80
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	p.add_child(UI.label(t, 19, UI.PAPER_L))
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _to_menu() -> void:
	eng.abort = true
	if eng.phase != "fine" and req.get("k", "") != "":
		eng.provide_decision(null)
	if online != null:
		online.alive = false
	main.show_menu()


# ================================================================ online

func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		msg_lbl.text = ""
		return
	_ab_panel().visible = true
	for c in action_bar.get_children():
		c.queue_free()
	msg_lbl.text = "In attesa di %s...%s" % [eng.pname(s), " (lento: se non torna gioca il computer)" if slow else ""]


func online_status(t: String) -> void:
	_toast(t)


func online_caught_up() -> void:
	_refresh()


# ================================================================ fine e replay

func _on_end(res: Dictionary) -> void:
	if online != null:
		online.finish()
	board.viewer = -1
	_refresh()
	end_panel = Control.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(end_panel)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(720, 0)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	end_panel.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	box.add_child(vb)
	var w := int(res.get("winner", -1))
	var title := "Partita pari" if w < 0 else "Vince %s" % eng.sides[w]["nome"]
	vb.add_child(UI.title(title, 48))
	if str(res.get("level", "")) != "":
		vb.add_child(UI.head("Vittoria %s" % res["level"], 24, UI.RED_D))
	vb.add_child(UI.wrap(UI.label(str(res.get("reason", "")), 20), 680))
	vb.add_child(UI.label("Turni giocati: %d" % eng.turn, 17, UI.MUTED))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	vb.add_child(r)
	var b1 := UI.primary(UI.button("Rivedi la partita", 0, 56, 20))
	b1.pressed.connect(_start_replay)
	r.add_child(b1)
	var b2 := UI.button("Guarda la mappa", 0, 56, 20)
	b2.pressed.connect(func(): box.visible = false)
	r.add_child(b2)
	var b3 := UI.button("Salva", 0, 56, 20)
	b3.pressed.connect(_save)
	r.add_child(b3)
	var b4 := UI.button("Menu", 0, 56, 20)
	b4.pressed.connect(func(): main.show_menu())
	r.add_child(b4)


func _start_replay() -> void:
	if is_instance_valid(end_panel):
		end_panel.queue_free()
	board.viewer = -1
	replay_i = 0
	replay_play = true
	replay_bar = PanelContainer.new()
	replay_bar.add_theme_stylebox_override("panel", UI.panel_style(0.97))
	replay_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	replay_bar.offset_top = -96
	replay_bar.offset_bottom = -12
	replay_bar.offset_left = -470
	replay_bar.offset_right = 70
	replay_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(replay_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	replay_bar.add_child(hb)
	var bp := UI.button("Pausa", 120, 50, 18)
	bp.pressed.connect(func():
		replay_play = not replay_play
		bp.text = "Pausa" if replay_play else "Avanti")
	hb.add_child(bp)
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = eng.history.size() - 1
	sl.custom_minimum_size = Vector2(300, 40)
	sl.name = "cursore"
	sl.value_changed.connect(func(v):
		replay_i = int(v)
		_show_replay())
	hb.add_child(sl)
	var lb := UI.label("", 16)
	lb.name = "dove"
	lb.custom_minimum_size.x = 160
	hb.add_child(lb)
	var bx := UI.button("Chiudi", 100, 50, 18)
	bx.pressed.connect(func():
		replay_play = false
		replay_i = -1
		board.show_snapshot(null)
		replay_bar.queue_free()
		replay_bar = null
		_on_end(eng.result))
	hb.add_child(bx)
	_show_replay()


func _show_replay() -> void:
	if replay_i < 0 or replay_i >= eng.history.size():
		return
	var seg: Dictionary = eng.history[replay_i]
	board.show_snapshot(seg["s"])
	if is_instance_valid(replay_bar):
		var lb: Label = replay_bar.find_child("dove", true, false)
		if lb != null:
			lb.text = "Turno %d, stadio %d" % [seg["turn"], seg["stage"]] if seg["turn"] > 0 else "Schieramento"
		var sl: HSlider = replay_bar.find_child("cursore", true, false)
		if sl != null and int(sl.value) != replay_i:
			sl.set_value_no_signal(replay_i)
	if seg["k"] in ["fire", "launch", "blast", "orbital", "orbital_laser", "dead", "teleport"]:
		board.play_fx(seg["k"], seg, 1.5)


func _process(dt: float) -> void:
	if replay_i >= 0 and replay_play:
		_replay_t += dt
		if _replay_t > 0.18:
			_replay_t = 0.0
			if replay_i < eng.history.size() - 1:
				replay_i += 1
				_show_replay()
			else:
				replay_play = false
