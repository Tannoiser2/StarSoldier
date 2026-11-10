class_name SSFx
extends RefCounted
## Effetti della mappa 3D: fiamme dei jetpack, colpi traccianti, lampi alla bocca dell'arma, scintille
## all'impatto, esplosioni con palla di fuoco, onda d'urto, detriti e colonna di fumo, granate e missili
## con la scia. Tutto con CPUParticles3D (funziona anche sul web, renderer di compatibilità).

static var _soft: Texture2D
static var _mats := {}


## puntino morbido per le particelle
static func soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


static func _pmat(additive: bool) -> StandardMaterial3D:
	var k := "add" if additive else "mix"
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# fusione normale: su una mappa chiara quella additiva sbianca tutto
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mats[k] = m
	return m


static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / float(cols.size() - 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


static func _shrink() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.2))
	return c


static func _grow() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.0))
	return c


## sistema di particelle generico. Attenzione: nel renderer di compatibilità le particelle non ancora nate
## si vedono come dischi neri, quindi i getti singoli nascono tutti insieme (explosiveness 1) e quelli
## continui partono già pieni (preprocess)
static func particles(amount: int, life: float, size: float, cols: Array, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _pmat(additive)
	p.mesh = q
	p.color_ramp = _ramp(cols)
	p.scale_amount_curve = _shrink()
	p.local_coords = false
	# variare la durata compensa il fatto che le particelle nascano tutte insieme
	p.lifetime_randomness = 0.35
	return p


# ---------------------------------------------------------------- jetpack

## fiamma e fumo del jetpack, da appendere sotto il soldato in volo (resta acceso finché è in volo)
static func jetpack(col: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "jetpack"
	var hot := Color(1.0, 0.93, 0.55, 1.0)
	var fire := particles(36, 0.3, 0.2, [hot, Color(col, 0.95), Color(col.darkened(0.3), 0.6), Color(col.darkened(0.5), 0.0)])
	fire.direction = Vector3.DOWN
	fire.spread = 10.0
	fire.initial_velocity_min = 1.4
	fire.initial_velocity_max = 2.0
	fire.gravity = Vector3.ZERO
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.025
	fire.preprocess = 0.4
	n.add_child(fire)
	var smoke := particles(16, 1.0, 0.24, [Color(0.75, 0.75, 0.78, 0.0), Color(0.62, 0.62, 0.64, 0.45), Color(0.6, 0.6, 0.62, 0.0)], false)
	smoke.direction = Vector3.DOWN
	smoke.spread = 25.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.7
	smoke.gravity = Vector3(0, 0.25, 0)
	smoke.scale_amount_curve = _grow()
	smoke.position = Vector3(0, -0.12, 0)
	smoke.preprocess = 1.0
	n.add_child(smoke)
	# il bagliore caldo sotto la miniatura
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 8
	sm.rings = 4
	core.mesh = sm
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = hot
	cm.emission_enabled = true
	cm.emission = col
	cm.emission_energy_multiplier = 3.0
	core.material_override = cm
	n.add_child(core)
	return n


# ---------------------------------------------------------------- spari

## lampo alla bocca dell'arma
static func muzzle(parent: Node3D, p: Vector3, col: Color, life: float) -> void:
	var s := particles(12, maxf(life, 0.15), 0.22, [Color(1, 0.95, 0.6, 1), Color(col, 0.9), Color(col, 0.0)])
	s.one_shot = true
	s.explosiveness = 1.0
	s.spread = 180.0
	s.initial_velocity_min = 0.3
	s.initial_velocity_max = 0.8
	s.gravity = Vector3.ZERO
	parent.add_child(s)
	s.global_position = p
	s.emitting = true
	_free_later(s, life + 0.4)


## scintille all'impatto (big: colpo andato a segno)
static func sparks(parent: Node3D, p: Vector3, col: Color, big: bool) -> void:
	var s := particles(30 if big else 14, 0.55, 0.09, [Color(1, 0.95, 0.6, 1), Color(col, 1), Color(col.darkened(0.5), 0)])
	s.one_shot = true
	s.explosiveness = 1.0
	s.spread = 180.0
	s.direction = Vector3.UP
	s.initial_velocity_min = 0.8
	s.initial_velocity_max = 2.4 if big else 1.5
	s.gravity = Vector3(0, -4.0, 0)
	parent.add_child(s)
	s.global_position = p
	s.emitting = true
	_free_later(s, 1.2)


## proiettile tracciante che vola da a a b; al termine chiama on_hit
static func tracer(owner: Node3D, a: Vector3, b: Vector3, col: Color, dur: float, on_hit: Callable) -> void:
	var n := Node3D.new()
	owner.add_child(n)
	n.global_position = a
	var bolt := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.03
	cm.height = 0.34
	cm.radial_segments = 8
	cm.rings = 2
	bolt.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col.lightened(0.5)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 4.0
	bolt.material_override = m
	n.add_child(bolt)
	var dir := (b - a)
	if dir.length() > 0.01:
		var up := dir.normalized()
		var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		bolt.basis = Basis(side, up, side.cross(up))
	var trail := particles(24, 0.25, 0.07, [Color(col, 0.9), Color(col, 0.0)])
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.05
	trail.preprocess = 0.3
	n.add_child(trail)
	var tw := owner.create_tween()
	tw.tween_property(n, "global_position", b, dur)
	tw.tween_callback(func() -> void:
		bolt.visible = false
		trail.emitting = false
		if on_hit.is_valid():
			on_hit.call())
	tw.tween_interval(0.4)
	tw.tween_callback(n.queue_free)


# ---------------------------------------------------------------- esplosioni

## palla di fuoco, onda d'urto a terra, detriti e colonna di fumo
static func explosion(owner: Node3D, p: Vector3, k: float, big: bool, life: float, light: bool) -> void:
	var col := Color("#ff8a1c") if not big else Color("#ffd040")
	# palla di fuoco
	var ball := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	sp.radial_segments = 16
	sp.rings = 8
	ball.mesh = sp
	# guscio arancio ombreggiato (si vede il volume) con un nucleo giallo acceso dentro
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, 0.8)
	m.emission_enabled = true
	m.emission = col.darkened(0.2)
	m.emission_energy_multiplier = 0.8
	m.rim_enabled = true
	m.rim = 0.6
	m.roughness = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material_override = m
	owner.add_child(ball)
	ball.global_position = p + Vector3(0, 0.15, 0)
	ball.scale = Vector3.ONE * 0.1
	var core := MeshInstance3D.new()
	core.mesh = sp
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1.0, 0.95, 0.55, 1.0)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.material_override = cm
	core.scale = Vector3.ONE * 0.55
	ball.add_child(core)
	var r := 0.9 * k * (1.6 if big else 1.0)
	var tw := owner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * r, life * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color", Color(Color("#7a2a12"), 0.0), life)
	tw.tween_property(m, "emission_energy_multiplier", 0.0, life)
	tw.tween_property(cm, "albedo_color:a", 0.0, life * 0.45)
	tw.chain().tween_callback(ball.queue_free)
	# onda d'urto
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 0.75, 0.4, 0.75)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	owner.add_child(ring)
	ring.global_position = p + Vector3(0, 0.05, 0)
	ring.scale = Vector3(0.2, 0.3, 0.2)
	var tr := owner.create_tween()
	tr.set_parallel(true)
	tr.tween_property(ring, "scale", Vector3(2.4 * k, 0.3, 2.4 * k), life * 0.7)
	tr.tween_property(rm, "albedo_color:a", 0.0, life * 0.7)
	tr.chain().tween_callback(ring.queue_free)
	# fuoco e scintille
	var fire := particles(int(40 * k) + 10, 0.7, 0.36, [Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.12, 0.95), Color(0.75, 0.2, 0.05, 0.7), Color(0.25, 0.1, 0.05, 0)])
	fire.one_shot = true
	fire.explosiveness = 1.0
	fire.spread = 180.0
	fire.direction = Vector3.UP
	fire.initial_velocity_min = 0.6
	fire.initial_velocity_max = 2.2 * k
	fire.gravity = Vector3(0, 0.6, 0)
	owner.add_child(fire)
	fire.global_position = p + Vector3(0, 0.15, 0)
	fire.emitting = true
	_free_later(fire, 1.5)
	var debris := particles(int(26 * k) + 6, 1.0, 0.06, [Color(1, 0.8, 0.4, 1), Color(0.45, 0.35, 0.25, 1), Color(0.35, 0.3, 0.25, 0)], false)
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.spread = 70.0
	debris.direction = Vector3.UP
	debris.initial_velocity_min = 1.5
	debris.initial_velocity_max = 3.5 * k
	debris.gravity = Vector3(0, -6.0, 0)
	owner.add_child(debris)
	debris.global_position = p + Vector3(0, 0.1, 0)
	debris.emitting = true
	_free_later(debris, 1.6)
	# colonna di fumo che sale e si allarga
	var smoke := particles(int(22 * k) + 6, 2.4, 0.45, [Color(0.45, 0.43, 0.4, 0.05), Color(0.45, 0.43, 0.4, 0.45), Color(0.62, 0.62, 0.62, 0.0)], false)
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.spread = 25.0
	smoke.direction = Vector3.UP
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0, 0.15, 0)
	#smoke.damping_min = 0.3
	#smoke.damping_max = 0.6
	smoke.scale_amount_curve = _grow()
	owner.add_child(smoke)
	smoke.global_position = p + Vector3(0, 0.25, 0)
	smoke.emitting = true
	_free_later(smoke, 3.2)
	if light:
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 4.0 * k
		l.omni_range = 3.5 * k
		owner.add_child(l)
		l.global_position = p + Vector3(0, 0.6, 0)
		var tl := owner.create_tween()
		tl.tween_property(l, "light_energy", 0.0, life)
		tl.tween_callback(l.queue_free)


## granata o missile in volo lungo un arco, con la scia di fumo; al termine chiama on_land
static func lob(owner: Node3D, a: Vector3, b: Vector3, dur: float, missile: bool, on_land: Callable) -> void:
	var n := Node3D.new()
	owner.add_child(n)
	n.global_position = a
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.045 if not missile else 0.035
	sm.height = sm.radius * (2.0 if not missile else 5.0)
	sm.radial_segments = 8
	sm.rings = 4
	body.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#3a3a36") if not missile else Color("#d8d8d0")
	m.emission_enabled = true
	m.emission = Color("#ff7a20")
	m.emission_energy_multiplier = 0.6 if not missile else 2.0
	body.material_override = m
	n.add_child(body)
	var trail := particles(30, 0.8, 0.12, [Color(1, 0.8, 0.5, 0.8), Color(0.7, 0.7, 0.7, 0.4), Color(0.7, 0.7, 0.7, 0.0)], false)
	trail.gravity = Vector3(0, 0.2, 0)
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.1
	trail.scale_amount_curve = _grow()
	trail.preprocess = 0.8
	n.add_child(trail)
	var hgt := 0.8 + a.distance_to(b) * 0.15
	var tw := owner.create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(n):
			n.global_position = a.lerp(b, t) + Vector3(0, sin(t * PI) * hgt, 0), 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		body.visible = false
		trail.emitting = false
		if on_land.is_valid():
			on_land.call())
	tw.tween_interval(1.0)
	tw.tween_callback(n.queue_free)


static func _free_later(n: Node, t: float) -> void:
	var tw := n.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(n.queue_free)
