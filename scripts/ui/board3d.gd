class_name Board3D
extends Node3D
## Scena 3D di StarSoldier: la mappa SPI distesa sul tavolo, i soldati alle tre quote (a terra, in volo
## radente su uno stelo, in alta quota molto più in alto), segnalini di civili, crateri, fumo, missili e
## basi; i percorsi e i colpi dei piani; gli effetti del fuoco e delle esplosioni.
## Due grafiche: "originale" (pedine del modulo TTS, fronte a terra e retro in volo) e "reborn"
## (miniature 3D, alberi, rocce ed edifici sulla mappa, luci ed effetti).
## Comandi: un dito o tasto sinistro trascina la mappa, due dita pizzicano per lo zoom e ruotano
## (trascinate insieme in su o in giù inclinano la vista),
## rotella per lo zoom, tasto destro (o Maiusc + sinistro) per ruotare e inclinare.

const D = preload("res://scripts/data/ss_data.gd")
const M = preload("res://scripts/ui/models.gd")

signal picked_unit(id: String)
signal picked_hex(h: int)
signal hover_hex(h: int)

const ALT_Y := [0.05, 1.0, 2.8]

var eng: SSEngine
var viewer := 0                  # lato che guarda (-1 tutti, nel replay)
var style := "originale"

var cam: Camera3D
var pivot: Node3D
var yaw := 0.0
var pitch := -0.92
var dist := 34.0
var target := Vector3.ZERO
var target_goal := Vector3.ZERO
var env: WorldEnvironment
var sun: DirectionalLight3D

var static_root: Node3D
var props_root: Node3D
var units_root: Node3D
var marks_root: Node3D
var over_root: Node3D
var fx_root: Node3D

var unit_nodes := {}
var unit_goal := {}
var selected := ""
var hl_hex := -1
var hover_h := -1
var input_locked := false
var show_labels := true
var snap = null                  # istantanea mostrata (replay) oppure null = stato attuale
var replay_smooth := false      # nel replay le unità scivolano a velocità costante
var replay_time := 0.45          # durata di un momento del replay
var step_time := 0.35            # durata di un passo di movimento nel gioco (dipende dalla velocità)
var unit_speed := {}
var gui_hit: Callable            # la vista dice se un punto dello schermo è sopra un suo pannello
var terr: SSTerrain               # rilievo del terreno

var _drag := false
var _drag_btn := 0
var _moved := 0.0
var _touches := {}
var _touch_moved := 0.0
var _touch_start := Vector2.ZERO
var _t := 0.0
var _cursor: MeshInstance3D
var _hover_ring: MeshInstance3D
const DIST_MIN := 4.0
const DIST_MAX := 75.0


func setup(e: SSEngine, v: int, st: String) -> void:
	eng = e
	viewer = v
	style = st
	terr = SSTerrain.new()
	_build_env()
	_build_camera()
	static_root = Node3D.new()
	add_child(static_root)
	props_root = Node3D.new()
	add_child(props_root)
	marks_root = Node3D.new()
	add_child(marks_root)
	units_root = Node3D.new()
	add_child(units_root)
	over_root = Node3D.new()
	add_child(over_root)
	fx_root = Node3D.new()
	add_child(fx_root)
	_build_static()
	_build_cursor()
	refresh()


func set_style(st: String) -> void:
	style = st
	for c in props_root.get_children():
		c.queue_free()
	for id in unit_nodes:
		unit_nodes[id].queue_free()
	unit_nodes.clear()
	_apply_env()
	_build_props()
	refresh()


## centro dell'esagono alla quota del terreno
func _hw(h: int) -> Vector3:
	var c := Hex.world(h)
	if terr != null:
		c.y = terr.at_hex(h)
	return c


func ground_at(p: Vector3) -> float:
	return terr.ground(p.x, p.z) if terr != null else 0.0


# ================================================================ ambiente e telecamera

func _build_env() -> void:
	env = WorldEnvironment.new()
	env.environment = Environment.new()
	add_child(env)
	sun = DirectionalLight3D.new()
	# il sole viene da Ovest e un po' da Nord, come le ombre stampate a destra dei simboli della mappa
	sun.rotation = Vector3(-0.62, -1.75, 0)
	sun.light_energy = 0.82
	sun.shadow_enabled = not OS.has_feature("web")
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.6, 1.2, 0)
	fill.light_energy = 0.12
	fill.light_color = Color("#ffd2b8")
	add_child(fill)
	_apply_env()


func _apply_env() -> void:
	var e := env.environment
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if style == "reborn":
		e.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = UI.tex("res://assets/misc/cielo.jpg")
		pm.energy_multiplier = 0.8
		sky.sky_material = pm
		e.sky = sky
		e.ambient_light_color = Color("#d8ccb8")
		e.ambient_light_energy = 0.4
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		e.glow_enabled = true
		e.glow_intensity = 0.6
		e.glow_hdr_threshold = 1.0
	else:
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("#1a120d")
		e.ambient_light_color = Color("#e8ddc8")
		e.ambient_light_energy = 0.42
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		e.glow_enabled = false


func _build_camera() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.far = 900.0
	cam.near = 0.1
	pivot.add_child(cam)
	cam.current = true
	_update_cam()


func _update_cam() -> void:
	pivot.position = target
	pivot.rotation = Vector3(pitch, yaw, 0)
	cam.position = Vector3(0, 0, dist)


func focus(p: Vector3, d := -1.0) -> void:
	target_goal = Vector3(p.x, ground_at(p), p.z)
	if d > 0:
		dist = d


func focus_hex(h: int) -> void:
	if Hex.valid(h):
		focus(_hw(h))


func reset_view() -> void:
	target_goal = Vector3.ZERO
	yaw = 0.0
	pitch = -0.92
	dist = 50.0


func _process(dt: float) -> void:
	_t += dt
	target = target.lerp(target_goal, minf(1.0, dt * 5.0))
	_update_cam()
	for id in unit_nodes:
		var n: Node3D = unit_nodes[id]
		if not is_instance_valid(n):
			continue
		var goal: Vector3 = unit_goal.get(id, n.position)
		var step := goal - n.position
		# velocità costante: arriva esattamente alla fine del passo, senza frenate fra un passo e l'altro
		n.position = n.position.move_toward(goal, float(unit_speed.get(id, 4.0)) * dt)
		# la miniatura si gira verso dove va
		if style == "reborn" and Vector2(step.x, step.z).length() > 0.05:
			var v: Node3D = n.get_node_or_null("vis")
			if v != null:
				v.rotation.y = lerp_angle(v.rotation.y, atan2(step.x, step.z), minf(1.0, dt * 8.0))
		var body := n.get_node_or_null("vis/corpo")
		if body != null and n.has_meta("air"):
			body.position.y = sin(_t * 2.0 + float(n.get_instance_id() % 13)) * 0.04
	if is_instance_valid(_cursor) and _cursor.visible:
		var k := 1.0 + 0.08 * sin(_t * 5.0)
		_cursor.scale = Vector3(k, 1, k)


func _over_gui(sp: Vector2) -> bool:
	var c := get_viewport().gui_get_hovered_control()
	if c == null:
		return false
	return c.get_global_rect().has_point(sp) and c.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _gui_at(sp: Vector2) -> bool:
	# per il tocco: gui_get_hovered_control non vale, chiede alla vista
	if gui_hit.is_valid():
		return gui_hit.call(sp)
	return _over_gui(sp)


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or input_locked:
		_drag = false
		_touches.clear()
		return
	# tocco (iPad): un dito sposta, due dita pizzicano e ruotano, un tocco breve seleziona
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if _touches.is_empty() and _gui_at(ev.position):
				return
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				_touch_moved = 0.0
				_touch_start = ev.position
		else:
			if _touches.has(ev.index):
				_touches.erase(ev.index)
				if _touches.is_empty() and _touch_moved < 14.0 and ev.position.distance_to(_touch_start) < 18.0:
					_click(ev.position)
		return
	if ev is InputEventScreenDrag:
		if not _touches.has(ev.index):
			return
		var old: Vector2 = _touches[ev.index]
		_touch_moved += ev.relative.length()
		if _touches.size() == 1:
			_pan(ev.position - old)
		else:
			var other := Vector2.ZERO
			for k in _touches:
				if k != ev.index:
					other = _touches[k]
			var d0 := old.distance_to(other)
			var d1: float = ev.position.distance_to(other)
			if d0 > 1.0:
				dist = clampf(dist * d0 / maxf(d1, 1.0), DIST_MIN, DIST_MAX)
			var a0 := (old - other).angle()
			var a1: float = (ev.position - other).angle()
			yaw += wrapf(a1 - a0, -PI, PI)
			# due dita trascinate insieme: in su o in giù inclinano la vista (come in Mappe), di lato la spostano
			var mid: Vector2 = (ev.position - old) * 0.5
			pitch = clampf(pitch + mid.y * 0.006, -1.52, -0.25)
			_pan(Vector2(mid.x, 0))
		_touches[ev.index] = ev.position
		return
	if ev is InputEventMagnifyGesture:
		if not _over_gui(ev.position):
			dist = clampf(dist / ev.factor, DIST_MIN, DIST_MAX)
		return
	if ev is InputEventPanGesture:
		if not _over_gui(ev.position):
			_pan(-ev.delta * 12.0)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		match ev.keycode:
			KEY_Q:
				yaw += 0.26
			KEY_E:
				yaw -= 0.26
			KEY_LEFT:
				_pan(Vector2(80, 0))
			KEY_RIGHT:
				_pan(Vector2(-80, 0))
			KEY_UP:
				_pan(Vector2(0, 80))
			KEY_DOWN:
				_pan(Vector2(0, -80))
			KEY_EQUAL, KEY_KP_ADD:
				dist = clampf(dist * 0.85, DIST_MIN, DIST_MAX)
			KEY_MINUS, KEY_KP_SUBTRACT:
				dist = clampf(dist * 1.18, DIST_MIN, DIST_MAX)
		return
	# il mouse emulato dal tocco si ignora: il tocco ha già i suoi comandi
	if ev is InputEventMouse and ev.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if ev is InputEventMouseButton:
		if ev.pressed and _over_gui(ev.position):
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist * 0.9, DIST_MIN, DIST_MAX)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist * 1.1, DIST_MIN, DIST_MAX)
		elif ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if ev.pressed:
				_drag = true
				_drag_btn = ev.button_index
				_moved = 0.0
			elif _drag and ev.button_index == _drag_btn:
				_drag = false
				if ev.button_index == MOUSE_BUTTON_LEFT and _moved < 7.0 and not _over_gui(ev.position):
					_click(ev.position)
	elif ev is InputEventMouseMotion:
		if _drag and ev.button_mask == 0:
			_drag = false
		if _drag:
			_moved += ev.relative.length()
			if _moved > 5.0:
				if _drag_btn == MOUSE_BUTTON_RIGHT or (_drag_btn == MOUSE_BUTTON_LEFT and ev.shift_pressed):
					yaw -= ev.relative.x * 0.006
					pitch = clampf(pitch - ev.relative.y * 0.005, -1.52, -0.25)
				else:
					_pan(ev.relative)
		elif not _over_gui(ev.position):
			_hover(ev.position)


func _pan(rel: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var k := dist * 0.0013
	target_goal += (-right * rel.x + fwd * rel.y) * k
	target_goal.x = clampf(target_goal.x, -30.0, 30.0)
	target_goal.z = clampf(target_goal.z, -20.0, 20.0)
	target_goal.y = ground_at(target_goal)


func _ray_plane(sp: Vector2) -> Variant:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	return terr.ray(o, d)


func _hover(sp: Vector2) -> void:
	var h := -1
	var p = _ray_plane(sp)
	if p != null:
		h = Hex.at_world(p)
	if h != hover_h:
		hover_h = h
		_set_ring(_hover_ring, h)
		hover_hex.emit(h)


func _click(sp: Vector2) -> void:
	var best := ""
	var bd := 24.0
	for id in unit_nodes:
		var n: Node3D = unit_nodes[id]
		if not is_instance_valid(n) or not n.visible:
			continue
		var pos := n.global_position + Vector3(0, 0.15, 0)
		if cam.is_position_behind(pos):
			continue
		var d := cam.unproject_position(pos).distance_to(sp)
		if d < bd:
			bd = d
			best = str(id)
	if best != "":
		picked_unit.emit(best)
		return
	var p = _ray_plane(sp)
	if p != null:
		var h := Hex.at_world(p)
		if h > 0:
			picked_hex.emit(h)


# ================================================================ mappa

func _build_static() -> void:
	# la mappa originale stesa sul terreno in rilievo (luce vera, così colline e montagne si leggono)
	var tex: Texture2D = UI.tex("res://assets/map/mappa.jpg")
	var q := MeshInstance3D.new()
	q.name = "terreno"
	q.mesh = terr.build_mesh()
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	q.material_override = m
	static_root.add_child(q)
	# il bordo del tavolo
	var tb := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(terr.w + 2.4, 0.6, terr.d + 2.4)
	tb.mesh = bm
	tb.position = Vector3(0, SSTerrain.SKIRT - 0.3, 0)
	tb.material_override = M.mat(Color("#3b2618"), 0.0, 0.9)
	static_root.add_child(tb)
	_build_water()
	_build_city()
	_build_props()


## specchi d'acqua sui laghi, un po' sotto il bordo della conca
func _build_water() -> void:
	var lake := []
	for h in Hex.all_hexes():
		if D.terrain(h) == "l":
			lake.append(h)
	if lake.is_empty():
		return
	var lvl := 0.0
	for h in lake:
		lvl += terr.at_hex(h)
	lvl = lvl / float(lake.size()) + 0.07
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.6
	cm.height = 0.01
	cm.radial_segments = 6
	cm.rings = 1
	mm.mesh = cm
	mm.instance_count = lake.size()
	for i in lake.size():
		var c := Hex.world(lake[i])
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3(c.x, lvl, c.z)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.25, 0.5, 0.72, 0.5)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic = 0.3
	wm.roughness = 0.1
	mi.material_override = wm
	static_root.add_child(mi)


## le città modellate in Blender sulla pianta dei simboli della mappa (in entrambe le grafiche)
func _build_city() -> void:
	SSCitta3D.new().build(static_root, func(x: float, z: float) -> float: return terr.ground(x, z))


func _multi(parent: Node3D, mesh: Mesh, arr: Array, rough: float) -> MultiMeshInstance3D:
	if arr.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = arr.size()
	for i in arr.size():
		mm.set_instance_transform(i, arr[i][0])
		mm.set_instance_color(i, arr[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.roughness = rough
	mmi.material_override = mt
	parent.add_child(mmi)
	return mmi


func _build_props() -> void:
	if style != "reborn":
		return
	# alberi e rocce con le MultiMesh: migliaia di elementi in pochi oggetti (leggero sul web)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2451
	var lists := {"chioma": [], "tronco": [], "roccia": []}
	for h in Hex.all_hexes():
		var t := D.terrain(h)
		var c := Hex.world(h)
		match t:
			"o":
				for i in 4:
					var p := c + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
					p.y = ground_at(p)
					var hh := rng.randf_range(0.28, 0.5)
					var col := Color("#3f6a24").lerp(Color("#6d8f2a"), rng.randf())
					lists["chioma"].append([Transform3D(Basis().scaled(Vector3(rng.randf_range(0.8, 1.2), hh / 0.4, rng.randf_range(0.8, 1.2))), p + Vector3(0, hh * 0.45 + 0.08, 0)), col])
					lists["tronco"].append([Transform3D(Basis(), p + Vector3(0, 0.06, 0)), Color("#4a3423")])
			"m", "b":
				for i in (2 if t == "m" else 1):
					if t == "b" and rng.randf() < 0.5:
						continue
					var p2 := c + Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
					p2.y = ground_at(p2)
					var h2 := rng.randf_range(0.2, 0.45) * (1.0 if t == "m" else 0.6)
					lists["roccia"].append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.8, 1.3), h2 / 0.5, rng.randf_range(0.8, 1.3))), p2 + Vector3(0, h2 * 0.3, 0)), Color("#7a5532").lerp(Color("#a3825d"), rng.randf())])
	var meshes := {"chioma": M._cyl(0.0, 0.15, 0.4, 7), "tronco": M._cyl(0.02, 0.03, 0.14, 5), "roccia": M._cyl(0.03, 0.26, 0.5, 5)}
	for k in lists:
		_multi(props_root, meshes[k], lists[k], 0.9)


func _build_cursor() -> void:
	_cursor = _ring_mesh(UI.RED, 0.07)
	_cursor.visible = false
	add_child(_cursor)
	_hover_ring = _ring_mesh(Color(1, 1, 1, 0.8), 0.04)
	_hover_ring.visible = false
	add_child(_hover_ring)


func _ring_mesh(col: Color, w: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var r0 := 0.57
	var r1 := r0 - w
	for i in 6:
		var a0 := PI / 6.0 + float(i) * TAU / 6.0
		var a1 := PI / 6.0 + float(i + 1) * TAU / 6.0
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		im.surface_add_vertex(p0 * r0)
		im.surface_add_vertex(p1 * r0)
		im.surface_add_vertex(p1 * r1)
		im.surface_add_vertex(p0 * r0)
		im.surface_add_vertex(p1 * r1)
		im.surface_add_vertex(p0 * r1)
	im.surface_end()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 2
	mi.material_override = m
	return mi


func _set_ring(r: MeshInstance3D, h: int, y := 0.03) -> void:
	if not Hex.valid(h):
		r.visible = false
		return
	r.visible = true
	r.position = _hw(h) + Vector3(0, y, 0)


func highlight(h: int) -> void:
	hl_hex = h
	_set_ring(_cursor, h, 0.04)


# ================================================================ unità

func refresh() -> void:
	_refresh_units()
	_refresh_marks()


## mostra un'istantanea registrata (replay); null = torna allo stato attuale
func show_snapshot(s) -> void:
	snap = s
	refresh()


func _state(id: String) -> Dictionary:
	var u: Dictionary = eng.units[id]
	if snap == null:
		return {"h": u["h"] if u["on"] else 0, "alt": u["alt"], "tpa": u["tpa"], "dead": u["dead"], "hidden": u["hidden"], "found": u["found"], "exited": u["exited"]}
	var a: Array = snap["u"].get(id, [0, 0, 0, 1, 0, 1, 0])
	return {"h": a[0], "alt": a[1], "tpa": a[2], "dead": a[3] == 1, "hidden": a[4] == 1, "found": a[5] == 1, "exited": a[6] == 1}


func _visible(u: Dictionary, st: Dictionary) -> bool:
	if st["dead"] or st["exited"] or st["h"] <= 0:
		return false
	if viewer == -1 or u["side"] == viewer:
		return true
	if viewer == -2:
		return not st["hidden"] and (u["kind"] != "base" or st["found"])
	if u["kind"] == "base":
		return st["found"]
	return not st["hidden"]


func _refresh_units() -> void:
	var stacks := {}
	var seen := {}
	for id in eng.order:
		var u: Dictionary = eng.units[id]
		var st := _state(id)
		if not _visible(u, st):
			if unit_nodes.has(id):
				unit_nodes[id].queue_free()
				unit_nodes.erase(id)
			continue
		var key := "%d|%d" % [st["h"], st["alt"]]
		if not stacks.has(key):
			stacks[key] = []
		stacks[key].append(id)
		seen[id] = st
	for key in stacks:
		var ids: Array = stacks[key]
		for i in ids.size():
			var id: String = ids[i]
			var u: Dictionary = eng.units[id]
			var st: Dictionary = seen[id]
			var n: Node3D = unit_nodes.get(id, null)
			var want_air: bool = st["alt"] > 0
			var sig := "%s|%d|%s" % [style, st["alt"], "1" if (st["hidden"] and u["side"] == viewer) else "0"]
			var keep_pos = null
			if n != null and n.get_meta("sig", "") != sig:
				keep_pos = n.position
				n.queue_free()
				n = null
			if n == null:
				n = _unit_node(u, st)
				n.set_meta("sig", sig)
				units_root.add_child(n)
				unit_nodes[id] = n
				n.position = keep_pos if keep_pos != null else _unit_pos(st["h"], st["alt"], i, ids.size())
			if want_air:
				n.set_meta("air", true)
			elif n.has_meta("air"):
				n.remove_meta("air")
			var goal := _unit_pos(st["h"], st["alt"], i, ids.size())
			# velocità per arrivare in tempo alla fine del momento del replay
			var tt := replay_time if replay_smooth else step_time
			unit_speed[id] = maxf(n.position.distance_to(goal) / maxf(tt, 0.05), 0.5)
			unit_goal[id] = goal
			var lab: Label3D = n.get_node_or_null("etichetta")
			if lab != null:
				lab.text = "%s · %d" % [_short(u), st["tpa"]] if u["kind"] != "dink" else "Dinkblog"
				lab.visible = show_labels
				lab.modulate = _side_label_color(u["side"]) if id != selected else Color("#ffd27a")
			var sel := n.get_node_or_null("selezione")
			if sel != null:
				sel.visible = id == selected
			_stem(n, st["alt"])
	for id in unit_nodes.keys():
		if not seen.has(id):
			unit_nodes[id].queue_free()
			unit_nodes.erase(id)


func _short(u: Dictionary) -> String:
	if u["kind"] in ["ss", "hw", "an"]:
		return str(u["num"])
	return u["lab"]


func _unit_pos(h: int, alt: int, i: int, n: int) -> Vector3:
	var c := _hw(h)
	var y: float = ALT_Y[alt]
	var p: Vector3
	if n <= 1:
		p = c + Vector3(0, y, 0)
	elif style == "originale":
		# pedine impilate e un po' sfalsate, come sul tavolo
		p = c + Vector3(-0.06 * float(i) + 0.03 * float(n - 1), y + 0.075 * float(i), -0.06 * float(i) + 0.03 * float(n - 1))
	else:
		var a := float(i) / float(n) * TAU
		var r := 0.24 if n <= 4 else 0.3
		p = c + Vector3(cos(a) * r, y, sin(a) * r)
	# mai sotto il terreno (pendii)
	p.y = maxf(p.y, ground_at(p) + y + 0.01)
	return p


func _unit_node(u: Dictionary, st: Dictionary) -> Node3D:
	var root := Node3D.new()
	var vis := Node3D.new()
	vis.name = "vis"
	root.add_child(vis)
	var ghost: bool = st["hidden"] and u["side"] == viewer
	var air: bool = st["alt"] > 0
	if style == "originale" or u["kind"] in [] :
		var t := _counter_tex(u, air)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz := 0.66 if u["kind"] != "base" else 0.72
		bm.size = Vector3(sz, 0.07, sz)
		box.mesh = bm
		box.position.y = 0.035
		var side := M.mat(UI.species_color(u["ped"]).darkened(0.25), 0.0, 0.8)
		box.material_override = side
		vis.add_child(box)
		var top := MeshInstance3D.new()
		var qm := PlaneMesh.new()
		qm.size = Vector2(sz, sz)
		top.mesh = qm
		top.position.y = 0.072
		var tm := StandardMaterial3D.new()
		tm.albedo_texture = t
		tm.roughness = 0.8
		if ghost:
			tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tm.albedo_color.a = 0.45
		top.material_override = tm
		vis.add_child(top)
		# il filo colorato del lato
		var edge := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(sz + 0.06, 0.03, sz + 0.06)
		edge.mesh = em
		edge.position.y = 0.012
		edge.material_override = M.mat(UI.side_color(u["side"]), 0.0, 0.5, 0.3)
		vis.add_child(edge)
	else:
		var mdl := M.build(u["race"] if u["kind"] != "dink" else "d", u["kind"], UI.side_color(u["side"]))
		mdl.scale = Vector3.ONE * (0.55 if u["kind"] in ["ss", "hw", "an"] else 0.75)
		vis.add_child(mdl)
		var corpo := mdl.get_node("corpo")
		mdl.remove_child(corpo)
		vis.add_child(corpo)
		corpo.scale = mdl.scale
		if ghost:
			M.ghost(corpo, 0.6)
		# lo sguardo: Alpha verso Est, Bravo verso Ovest; poi segue il movimento
		vis.rotation.y = PI / 2.0 if u["side"] == 0 else -PI / 2.0
	# in volo: fiamma e fumo del jetpack (i Rame hanno la propulsione azzurra)
	if air and u["kind"] in ["ss", "hw", "an"]:
		var jcol := Color("#ff8a2a") if u["race"] != "r" else Color("#6ad8ff")
		if style == "originale":
			root.add_child(SSFx.jetpack(jcol))
		else:
			# due ugelli sulla schiena della miniatura, inclinati all'indietro; girano con lei
			# (agganciati al corpo, così ondeggiano insieme in volo)
			var body: Node3D = vis.get_node_or_null("corpo")
			var par: Node3D = body if body != null else vis
			var k := par.scale.x
			for sx in [-0.05, 0.05]:
				var jp := SSFx.jetpack(jcol)
				jp.scale = Vector3.ONE * 0.6 / k
				jp.position = Vector3(sx, 0.36 if u["race"] != "r" else 0.2, -0.09) / k
				jp.rotation.x = 0.35
				par.add_child(jp)
	if style == "reborn":
		root.add_child(_ground_circle(u, st["alt"]))
	var sel := _ring_mesh(Color("#ffd27a"), 0.08)
	sel.name = "selezione"
	sel.scale = Vector3(0.7, 1, 0.7)
	sel.position.y = 0.09
	sel.visible = false
	vis.add_child(sel)
	var lab := Label3D.new()
	lab.name = "etichetta"
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	# grandezza nel mondo (non in pixel): da lontano si rimpiccioliscono con la mappa
	lab.fixed_size = false
	lab.pixel_size = 0.0034
	lab.font = UI.font_head
	lab.font_size = 48
	lab.outline_size = 14
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.position = Vector3(0, 0.8 if style == "reborn" else 0.5, 0)
	lab.render_priority = 3
	root.add_child(lab)
	return root


## colore delle etichette: quello del lato, schiarito per leggersi sulla mappa
func _side_label_color(side: int) -> Color:
	return UI.side_color(side).lightened(0.35)


## cerchio tenue del colore del lato, a terra sotto l'unità (anche quando vola)
func _ground_circle(u: Dictionary, alt: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "cerchio"
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.8, 0.8)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = SSFx.soft_tex()
	m.albedo_color = Color(UI.side_color(u["side"]).lightened(0.1), 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	mi.position.y = -float(ALT_Y[alt]) + 0.03
	return mi


func _stem(n: Node3D, alt: int) -> void:
	var old := n.get_node_or_null("stelo")
	if alt == 0:
		if old != null:
			old.queue_free()
		return
	if old != null:
		return
	var s := Node3D.new()
	s.name = "stelo"
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var y: float = ALT_Y[alt]
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = y
	c.mesh = cm
	c.position.y = -y * 0.5
	var m := M.mat(Color(1, 1, 1), 0.0, 0.5).duplicate()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.45)
	c.material_override = m
	s.add_child(c)
	var sh := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.18
	dm.bottom_radius = 0.18
	dm.height = 0.01
	sh.mesh = dm
	sh.position.y = -y + 0.02
	var sm := M.mat(Color(0, 0, 0), 0.0, 1.0).duplicate()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0, 0, 0, 0.35)
	sh.material_override = sm
	if style != "reborn":
		s.add_child(sh)
	n.add_child(s)


func _counter_tex(u: Dictionary, air: bool) -> Texture2D:
	var p := ""
	match u["kind"]:
		"ss", "hw", "an":
			p = "res://assets/counters/%s%d_%s.png" % [u["ped"], u["num"], "a" if air else "g"]
		"pl":
			p = "res://assets/counters/%s_piatt%d.png" % [u["ped"], (u["num"] % 100) - 60]
		"base":
			p = "res://assets/counters/base.png"
		"dink":
			p = "res://assets/counters/dinkblog.png"
	var t := UI.tex(p)
	if t == null:
		t = UI.tex("res://assets/counters/%s%d_g.png" % [u["ped"], D.COUNTER_NUMS.get(u["ped"], {"ss": [101]})["ss"][0]])
	return t


func select(id: String) -> void:
	selected = id
	refresh()


# ================================================================ segnalini

func _refresh_marks() -> void:
	for c in marks_root.get_children():
		c.queue_free()
	var cr: Array = eng.craters.keys() if snap == null else snap["cr"]
	for h in cr:
		if style == "reborn":
			marks_root.add_child(_crater3d(int(h)))
		else:
			marks_root.add_child(_flat("cratere", int(h), 0.012, 0.8))
	var sm: Dictionary = eng.smoke if snap == null else snap["sm"]
	for h in sm:
		var k: String = sm[h]["k"]
		if style == "reborn":
			marks_root.add_child(_smoke_cloud(int(h), k == "ob"))
		else:
			marks_root.add_child(_flat("fumo" if k == "og" else "fumo_denso", int(h), 0.16, 0.6))
	# civili
	var cv: Array = []
	if snap == null:
		for c in eng.civs:
			cv.append([c["h"], 1 if c["dead"] else 0, 1 if c["up"] else 0, 1 if c["genuine"] else 0])
	else:
		cv = snap["c"]
	var i := 0
	for c in cv:
		i += 1
		if int(c[0]) <= 0 or int(c[1]) == 1:
			continue
		var t := "civile"
		if eng.sit == "B" and int(c[2]) == 0:
			t = "civile" if int(c[3]) == 1 else "fittizio"
		var cm: Node3D = M.model("civili", 0.42) if style == "reborn" else null
		if cm != null:
			# Reborn: la miniatura dei civili (veri e fittizi si somigliano: lo dice solo l'etichetta)
			var cp := _hw(int(c[0])) + Vector3(-0.28, 0, 0.26)
			cp.y = ground_at(cp)
			cm.position = cp
			cm.rotation.y = float(i) * 1.3
			marks_root.add_child(cm)
		else:
			marks_root.add_child(_flat(t, int(c[0]), 0.1 + 0.02 * float(i % 3), 0.5, Vector3(-0.28, 0, 0.26)))
		# il difensore umano vede quali segnalini sono veri
		if eng.sit == "B" and (viewer == 1 or viewer < 0) and int(c[2]) == 1:
			var lb := Label3D.new()
			lb.text = "vero" if int(c[3]) == 1 else "finto"
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.fixed_size = true
			lb.pixel_size = 0.0008
			lb.font_size = 15
			lb.outline_size = 5
			lb.modulate = Color("#fff3b0") if int(c[3]) == 1 else Color("#c9c0b0")
			lb.position = _hw(int(c[0])) + Vector3(-0.28, 0.32, 0.26)
			lb.no_depth_test = true
			marks_root.add_child(lb)
	# missili cercatori (le mine nascoste solo per chi le ha piazzate)
	var ms: Array = []
	if snap == null:
		for m in eng.missiles:
			ms.append([m["h"], 1 if m["active"] else 0, 1 if m["dead"] else 0, m["side"], 1 if m["mine"] else 0])
	else:
		ms = snap["m"]
	for m in ms:
		if int(m[2]) == 1 or int(m[0]) <= 0:
			continue
		if int(m[4]) == 1 and viewer >= 0 and int(m[3]) != viewer:
			continue
		var ped: String = eng.sides[int(m[3])]["pedine"]
		if not ped in ["h", "l", "r"]:
			ped = "h"
		var mm: Node3D = M.model("missile", 0.11) if style == "reborn" else null
		if mm != null:
			# Reborn: il missile cercatore a terra; attivo si alza e punta verso l'alto
			var mp := _hw(int(m[0])) + Vector3(0.26, 0, -0.26)
			mp.y = ground_at(mp)
			mm.position = mp
			if int(m[1]) == 1:
				mm.position.y += 0.25
				mm.rotation = Vector3(0, 0.6, 0.9)
			if int(m[4]) == 1:
				M.ghost(mm, 0.5)
			marks_root.add_child(mm)
		else:
			var nm := _flat("%s_miss%s" % [ped, "_att" if int(m[1]) == 1 else ""], int(m[0]), 0.2, 0.5, Vector3(0.26, 0, -0.26))
			if int(m[4]) == 1:
				nm.modulate_alpha = 0.5
			marks_root.add_child(nm)


class Flat extends MeshInstance3D:
	var modulate_alpha := 1.0:
		set(v):
			modulate_alpha = v
			var m: StandardMaterial3D = material_override
			if m != null:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color.a = v


func _flat(name: String, h: int, y: float, size: float, off := Vector3.ZERO) -> Flat:
	var mi := Flat.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = UI.tex("res://assets/counters/%s.png" % name)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.roughness = 0.9
	mi.material_override = m
	var p := _hw(h) + off
	p.y = maxf(p.y, ground_at(p)) + y
	mi.position = p
	return mi


func _crater3d(h: int) -> Node3D:
	var n := Node3D.new()
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.48
	tm.rings = 18
	tm.ring_segments = 6
	rim.mesh = tm
	rim.scale = Vector3(1, 0.35, 1)
	rim.material_override = M.mat(Color("#5a4632"), 0.0, 1.0)
	n.add_child(rim)
	var pit := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.34
	cm.height = 0.01
	pit.mesh = cm
	pit.position.y = 0.006
	pit.material_override = M.mat(Color("#2a1e14"), 0.0, 1.0)
	n.add_child(pit)
	n.position = _hw(h) + Vector3(0, 0.02, 0)
	return n


func _smoke_cloud(h: int, dense: bool) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = h
	for i in (7 if dense else 5):
		var s := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = rng.randf_range(0.22, 0.38)
		sp.height = sp.radius * 1.6
		s.mesh = sp
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.75, 0.78, 0.82, 0.45) if not dense else Color(0.35, 0.36, 0.4, 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		s.material_override = m
		s.position = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.15, 0.6), rng.randf_range(-0.3, 0.3))
		n.add_child(s)
	n.position = _hw(h)
	return n


# ================================================================ sovrapposizioni dei piani

## items: [{k: "path", pts: [Vector3...], col}, {k: "fire", a: Vector3, b: Vector3, col}, {k: "hex", h, col}]
func set_overlays(items: Array) -> void:
	for c in over_root.get_children():
		c.queue_free()
	for it in items:
		match it["k"]:
			"path":
				over_root.add_child(_polyline(it["pts"], it["col"], 0.05))
			"fire":
				over_root.add_child(_polyline([it["a"], it["b"]], it["col"], 0.03, true))
			"hex":
				var r := _ring_mesh(it["col"], 0.09)
				r.position = _hw(it["h"]) + Vector3(0, 0.05 + float(it.get("y", 0.0)), 0)
				over_root.add_child(r)
			"fill":
				var r2 := _ring_mesh(it["col"], 0.5)
				r2.position = _hw(it["h"]) + Vector3(0, 0.03, 0)
				over_root.add_child(r2)


func _polyline(pts: Array, col: Color, w: float, dashed := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var segs := 1
		if dashed:
			segs = maxi(1, int(a.distance_to(b) / 0.3))
		for k in segs:
			if dashed and k % 2 == 1:
				continue
			var p0 := a.lerp(b, float(k) / float(segs))
			var p1 := a.lerp(b, float(k + 1) / float(segs))
			var dir := (p1 - p0)
			if dir.length() < 1e-4:
				continue
			var side := dir.cross(Vector3.UP).normalized() * w
			if side.length() < 1e-4:
				side = Vector3(w, 0, 0)
			im.surface_add_vertex(p0 - side)
			im.surface_add_vertex(p0 + side)
			im.surface_add_vertex(p1 + side)
			im.surface_add_vertex(p0 - side)
			im.surface_add_vertex(p1 + side)
			im.surface_add_vertex(p1 - side)
	im.surface_end()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 1
	mi.material_override = m
	return mi


func point(h: int, alt: int) -> Vector3:
	return _hw(h) + Vector3(0, ALT_Y[clampi(alt, 0, 2)] + 0.2, 0)


# ================================================================ effetti

func play_fx(kind: String, d: Dictionary, speed := 1.0) -> void:
	var light := style == "reborn"
	match kind:
		"fire", "orbital_laser":
			var to := point(d["to"], d["talt"])
			var hit: bool = d.get("res", 0) > 0
			var col := Color("#ff4a2a") if d.get("side", 0) == 0 else Color("#4ab8ff")
			if d.get("laser", false) or kind == "orbital_laser":
				# laser: raggio continuo dall'orbita o dalla piattaforma
				col = Color("#ff2bd0")
				var from := point(d["to"], d["talt"]) + Vector3(0, 30, 0) if kind == "orbital_laser" else point(d["from"], d["falt"])
				_beam(from, to, col, 0.45 / speed, false)
				SSFx.sparks(fx_root, to, col, hit)
				if hit:
					SSFx.explosion(fx_root, to - Vector3(0, 0.15, 0), 0.35, false, 0.6 / speed, light)
			else:
				# colpo tracciante: lampo alla bocca, proiettile, scintille (e una piccola esplosione se va a segno)
				var from2 := point(d["from"], d["falt"])
				SSFx.muzzle(fx_root, from2, col, 0.15 / speed)
				var dur := clampf(from2.distance_to(to) * 0.035, 0.12, 0.4) / speed
				var fxr := fx_root
				SSFx.tracer(fx_root, from2, to, col, dur, func() -> void:
					SSFx.sparks(fxr, to, col, hit)
					if hit:
						SSFx.explosion(fxr, to - Vector3(0, 0.15, 0), 0.3, false, 0.5 / speed, light))
		"launch":
			# granata o missile cercatore che vola ad arco con la scia di fumo
			var a := point(d["from"], d["falt"])
			var b := point(d["to"], 0) - Vector3(0, 0.15, 0)
			var fxr2 := fx_root
			SSFx.muzzle(fx_root, a, Color("#ffd27a"), 0.15 / speed)
			SSFx.lob(fx_root, a, b, 0.5 / speed, d.get("w", "") == "hm", func() -> void:
				SSFx.sparks(fxr2, b, Color("#ffd27a"), false))
		"blast":
			var high: bool = d.get("high", false)
			var hexes: Dictionary = d.get("hexes", {})
			var big: bool = d.get("kind", "") in ["ob", "nb"]
			var first := true
			for hh in hexes:
				var k := 1.0 - 0.3 * float(hexes[hh])
				SSFx.explosion(fx_root, point(int(hh), 2 if high else 0) - Vector3(0, 0.2, 0), k, big, 0.9 / speed, light and first)
				first = false
		"orbital":
			_beam(point(d["h"], 0) + Vector3(0, 40, 0), point(d["h"], 0), Color("#ffcf5a"), 0.4 / speed, true)
			SSFx.explosion(fx_root, point(d["h"], 0) - Vector3(0, 0.2, 0), 1.3, true, 1.0 / speed, true)
		"dead":
			SSFx.explosion(fx_root, point(d["h"], d["alt"]) - Vector3(0, 0.1, 0), 0.45, false, 0.7 / speed, light)
		"hm_move":
			# il missile cercatore vola basso da un esagono all'altro con la scia
			SSFx.lob(fx_root, point(d["from"], 0) - Vector3(0, 0.05, 0), point(d["to"], 0) - Vector3(0, 0.05, 0), 0.3 / speed, true, Callable())
		"teleport", "found", "search", "hm_on":
			var h: int = int(d.get("to", d.get("h", 0)))
			if Hex.valid(h):
				_flash(point(h, 0), Color("#a0f0ff") if kind != "found" else Color("#ffd27a"), 0.7 / speed)


func _beam(a: Vector3, b: Vector3, col: Color, life: float, hit: bool) -> void:
	var n := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var len := a.distance_to(b)
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = len
	cm.radial_segments = 6
	n.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	n.material_override = m
	fx_root.add_child(n)
	n.global_position = (a + b) * 0.5
	if len > 0.01:
		var up := (b - a).normalized()
		var basis := Basis.looking_at(up, Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT)
		n.global_basis = basis * Basis(Vector3.RIGHT, PI / 2)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.tween_callback(n.queue_free)
	if hit:
		_flash(b, col, life * 1.2)


func _arc(a: Vector3, b: Vector3, col: Color, life: float) -> void:
	var pts := []
	var hgt := 1.0 + a.distance_to(b) * 0.12
	for i in 17:
		var t := float(i) / 16.0
		pts.append(a.lerp(b, t) + Vector3(0, sin(t * PI) * hgt, 0))
	var n := _polyline(pts, col, 0.025)
	fx_root.add_child(n)
	var m: StandardMaterial3D = n.material_override
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.tween_callback(n.queue_free)


func _boom(p: Vector3, k: float, big: bool, life: float) -> void:
	var n := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	n.mesh = sp
	var col := Color("#ffb347") if not big else Color("#fff0a0")
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col, 0.75)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	n.material_override = m
	fx_root.add_child(n)
	n.global_position = p
	n.scale = Vector3.ONE * 0.1
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(n, "scale", Vector3.ONE * (1.4 * k * (1.6 if big else 1.0)), life)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(n.queue_free)
	if style == "reborn":
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 3.0 * k
		l.omni_range = 3.0
		fx_root.add_child(l)
		l.global_position = p + Vector3(0, 0.5, 0)
		var tl := create_tween()
		tl.tween_property(l, "light_energy", 0.0, life)
		tl.tween_callback(l.queue_free)


func _flash(p: Vector3, col: Color, life: float) -> void:
	var r := _ring_mesh(col, 0.15)
	fx_root.add_child(r)
	r.global_position = Vector3(p.x, p.y - 0.15, p.z)
	var m: StandardMaterial3D = r.material_override
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "scale", Vector3(1.8, 1, 1.8), life)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(r.queue_free)
