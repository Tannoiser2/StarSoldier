class_name SSModels
extends RefCounted
## Miniature "Reborn" costruite in codice (nessun modello esterno): StarSoldier in tuta da battaglia
## attiva per Umani e L'Chal Dah, androidi metallici, Rame a forma di blob con gli occhi sugli steli,
## Xenofobi con tentacoli, piattaforme di supporto, basi a cupola, il Dinkblog. Ogni miniatura ha la
## base colorata del lato e, in volo, la scia luminosa del propulsore.

static var _mats := {}


static func mat(col: Color, metal := 0.1, rough := 0.6, emis := 0.0) -> StandardMaterial3D:
	var k := "%s|%.2f|%.2f|%.2f" % [col.to_html(), metal, rough, emis]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	_mats[k] = m
	return m


static func _mesh(m: Mesh, mt: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mt
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	return mi


static func _sphere(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0 else h
	s.radial_segments = 14
	s.rings = 8
	return s


static func _cyl(rt: float, rb: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 4
	return c


## Una miniatura completa. race: h, l, r, x, d; kind: ss, hw, an, pl, base, dink.
static func build(race: String, kind: String, side_col: Color) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "corpo"
	root.add_child(body)
	var mini := miniature(race if kind != "dink" else "d", kind)
	if mini != null:
		body.add_child(mini)
	else:
		match kind:
			"pl":
				_platform(body, race)
			"base":
				_base(body, race)
			"dink":
				_dinkblog(body)
			_:
				_build_code(body, race, kind)
	# base del lato solo per piattaforme e basi senza miniatura (le miniature hanno il cerchio colorato a terra)
	if kind in ["pl", "base"] and mini == null:
		var ring := _mesh(_cyl(0.3, 0.32, 0.04, 20), mat(side_col, 0.2, 0.4, 0.4), Vector3(0, 0.02, 0))
		ring.name = "basetta"
		ring.scale = Vector3(1.6, 1, 1.6)
		root.add_child(ring)
	return root


static func _build_code(body: Node3D, race: String, kind: String) -> void:
	match kind:
		_:
			match race:
				"r":
					_rame(body, kind == "an")
				"x":
					_xeno(body)
				"l":
					_trooper(body, Color("#7f9a1f"), Color("#d8e6a0"), kind, true)
				_:
					_trooper(body, Color("#cfd8e3"), Color("#6fb6ff"), kind, false)


# ---------------------------------------------------------------- miniature 3D (assets/miniature)

## file della miniatura e altezza (prima della scala della scena) per specie e tipo
const MINI := {
	"h|ss": ["umani_leggero", 1.05], "h|hw": ["umani_pesante", 1.1], "h|an": ["umani_leggero", 1.05],
	"l|ss": ["lchal_leggero", 1.1], "l|hw": ["lchal_pesante", 1.1], "l|an": ["lchal_leggero", 1.1],
	"r|ss": ["rame", 0.8], "r|an": ["rame", 0.8],
	"x|ss": ["xenofobi", 1.15], "x|an": ["xenofobi", 1.15],
	"d|dink": ["dinkblog", 0.75],
	# le piattaforme sono navette allungate sull'asse x: il terzo valore le gira col muso in avanti (+z)
	"h|pl": ["piattaforma_umana", 0.55, PI / 2.0], "l|pl": ["piattaforma_lchal", 0.55, PI / 2.0], "r|pl": ["piattaforma_rame", 0.55, -PI / 2.0],
}
static var _scenes := {}
static var _aabbs := {}


static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		var path := "res://assets/miniature/%s.glb" % name
		_scenes[name] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[name]


static func _aabb_of(n: Node, xf := Transform3D()) -> AABB:
	var box := AABB()
	var first := true
	var stack := [[n, xf]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is Node3D:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var b: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		for c in node.get_children():
			stack.append([c, t])
	return box


## un modello qualsiasi della cartella delle miniature, poggiato a terra, centrato e alto h
static func model(name: String, h: float) -> Node3D:
	var ps := _scene(name)
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if not _aabbs.has(name):
		_aabbs[name] = _aabb_of(inst, Transform3D())
	var box: AABB = _aabbs[name]
	var k := h / maxf(box.size.y, 0.001)
	var holder := Node3D.new()
	holder.name = "miniatura"
	holder.add_child(inst)
	inst.scale = Vector3.ONE * k
	var c := box.get_center()
	inst.position = Vector3(-c.x * k, -box.position.y * k, -c.z * k)
	return holder


## la miniatura di un'unità (null se manca: si usa quella costruita in codice)
static func miniature(race: String, kind: String) -> Node3D:
	var key := "%s|%s" % [race, kind]
	if not MINI.has(key):
		return null
	var n := model(MINI[key][0], MINI[key][1])
	if n != null and MINI[key].size() > 2:
		n.rotation.y = float(MINI[key][2])
	if n != null and kind == "an":
		# gli androidi: la stessa tuta con un velo metallico azzurrato
		var ov := StandardMaterial3D.new()
		ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ov.albedo_color = Color(0.55, 0.8, 1.0, 0.28)
		ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay(n, ov)
	return n


static func _overlay(n: Node, m: Material) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_overlay = m
	for c in n.get_children():
		_overlay(c, m)


## trasparenza per le unità nascoste viste dal proprietario
static func ghost(n: Node, a: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).transparency = a
	for c in n.get_children():
		ghost(c, a)


static func _trooper(b: Node3D, suit: Color, visor: Color, kind: String, tall: bool) -> void:
	var android := kind == "an"
	if android:
		suit = suit.lerp(Color("#9aa3ad"), 0.7)
	var ms := mat(suit, 0.55 if android else 0.25, 0.35)
	var dark := mat(suit.darkened(0.45), 0.4, 0.5)
	var hgt := 1.12 if tall else 1.0
	# gambe e corpo
	b.add_child(_mesh(_capsule(0.065, 0.38 * hgt), dark, Vector3(-0.07, 0.2 * hgt, 0)))
	b.add_child(_mesh(_capsule(0.065, 0.38 * hgt), dark, Vector3(0.07, 0.2 * hgt, 0)))
	b.add_child(_mesh(_capsule(0.13, 0.36 * hgt), ms, Vector3(0, 0.5 * hgt, 0)))
	# zaino propulsore
	b.add_child(_mesh(_box(0.2, 0.24, 0.1), dark, Vector3(0, 0.52 * hgt, -0.12)))
	# casco con visiera
	var head_r := 0.11 if not tall else 0.095
	var head := _mesh(_sphere(head_r, head_r * (2.0 if not tall else 2.6)), ms, Vector3(0, 0.78 * hgt, 0))
	b.add_child(head)
	b.add_child(_mesh(_sphere(head_r * 0.75, head_r * 0.9), mat(visor, 0.8, 0.1, 1.2 if android else 0.6), Vector3(0, 0.79 * hgt, 0.06)))
	# braccia e arma
	b.add_child(_mesh(_capsule(0.045, 0.3), ms, Vector3(-0.16, 0.52 * hgt, 0.04), Vector3(0.9, 0, 0.2)))
	b.add_child(_mesh(_capsule(0.045, 0.3), ms, Vector3(0.16, 0.52 * hgt, 0.04), Vector3(0.9, 0, -0.2)))
	var heavy := kind == "hw"
	var gun := _mesh(_box(0.06 if not heavy else 0.11, 0.06 if not heavy else 0.1, 0.42 if not heavy else 0.55), mat(Color("#2b2b30"), 0.7, 0.3), Vector3(0.05, 0.55 * hgt, 0.2))
	b.add_child(gun)
	if heavy:
		b.add_child(_mesh(_cyl(0.035, 0.035, 0.2), mat(Color("#ff7a3d"), 0.3, 0.3, 1.5), Vector3(0.05, 0.55 * hgt, 0.5), Vector3(PI / 2, 0, 0)))


static func _rame(b: Node3D, android: bool) -> void:
	var col := Color("#f2c21c") if not android else Color("#b8a46a")
	var m := mat(col, 0.5 if android else 0.05, 0.45)
	var blob := _mesh(_sphere(0.24, 0.42), m, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.1, 1, 0.9))
	b.add_child(blob)
	b.add_child(_mesh(_sphere(0.14), m, Vector3(0.15, 0.2, 0.08)))
	b.add_child(_mesh(_sphere(0.12), m, Vector3(-0.16, 0.18, -0.05)))
	for i in 2:
		var x := -0.08 + 0.16 * i
		b.add_child(_mesh(_cyl(0.015, 0.02, 0.3), mat(col.darkened(0.3)), Vector3(x, 0.6, 0.05), Vector3(0.3, 0, (i - 0.5) * 0.5)))
		b.add_child(_mesh(_sphere(0.06), mat(Color.WHITE, 0.0, 0.2), Vector3(x * 1.6, 0.76, 0.1)))
		b.add_child(_mesh(_sphere(0.03), mat(Color.BLACK, 0.0, 0.2), Vector3(x * 1.6, 0.76, 0.15)))
	b.add_child(_mesh(_box(0.05, 0.05, 0.3), mat(Color("#3a3020"), 0.6, 0.3), Vector3(0.18, 0.35, 0.2)))


static func _xeno(b: Node3D) -> void:
	var col := Color("#98b58a")
	var m := mat(col, 0.1, 0.5)
	b.add_child(_mesh(_cyl(0.13, 0.17, 0.5), m, Vector3(0, 0.48, 0)))
	b.add_child(_mesh(_sphere(0.16, 0.24), m, Vector3(0, 0.78, 0)))
	b.add_child(_mesh(_sphere(0.05), mat(Color("#ff3b2f"), 0.0, 0.2, 1.4), Vector3(0, 0.8, 0.13)))
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.4
		b.add_child(_mesh(_capsule(0.04, 0.34), mat(col.darkened(0.25)), Vector3(cos(a) * 0.12, 0.15, sin(a) * 0.12), Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4)))
	b.add_child(_mesh(_box(0.05, 0.05, 0.38), mat(Color("#20251d"), 0.6, 0.3), Vector3(0.16, 0.55, 0.18)))


static func _platform(b: Node3D, race: String) -> void:
	var col: Color = {"h": Color("#cfd8e3"), "l": Color("#9db04a"), "r": Color("#e8c64a")}.get(race, Color.GRAY)
	var m := mat(col, 0.6, 0.3)
	b.add_child(_mesh(_cyl(0.42, 0.3, 0.16, 18), m, Vector3(0, 0.25, 0)))
	b.add_child(_mesh(_sphere(0.18, 0.2), mat(Color("#6fd0ff"), 0.6, 0.1, 0.8), Vector3(0, 0.38, 0)))
	var tur := _mesh(_box(0.08, 0.08, 0.5), mat(Color("#303038"), 0.7, 0.3), Vector3(0, 0.36, 0.3))
	b.add_child(tur)
	for i in 3:
		var a := float(i) * TAU / 3.0
		b.add_child(_mesh(_cyl(0.06, 0.09, 0.08), mat(Color("#ffb347"), 0.2, 0.3, 2.0), Vector3(cos(a) * 0.28, 0.13, sin(a) * 0.28)))


static func _base(b: Node3D, race: String) -> void:
	var m := mat(Color("#d9d2c3"), 0.3, 0.5)
	b.add_child(_mesh(_cyl(0.42, 0.46, 0.08, 20), mat(Color("#6b6358"), 0.2, 0.8), Vector3(0, 0.04, 0)))
	b.add_child(_mesh(_sphere(0.34, 0.5), m, Vector3(0, 0.1, 0)))
	b.add_child(_mesh(_cyl(0.015, 0.015, 0.5), mat(Color("#444")), Vector3(0.2, 0.55, 0)))
	b.add_child(_mesh(_sphere(0.04), mat(Color("#ff4030"), 0.0, 0.3, 2.0), Vector3(0.2, 0.82, 0)))


static func _dinkblog(b: Node3D) -> void:
	var m := mat(Color("#8a5a2a"), 0.05, 0.8)
	b.add_child(_mesh(_capsule(0.17, 0.7), m, Vector3(0, 0.34, 0), Vector3(PI / 2, 0, 0)))
	b.add_child(_mesh(_sphere(0.16), m, Vector3(0, 0.45, 0.38)))
	b.add_child(_mesh(_box(0.22, 0.05, 0.16), mat(Color("#f0e8d0")), Vector3(0, 0.38, 0.5)))
	b.add_child(_mesh(_sphere(0.04), mat(Color("#ffde00"), 0.0, 0.2, 1.5), Vector3(0.07, 0.53, 0.5)))
	b.add_child(_mesh(_sphere(0.04), mat(Color("#ffde00"), 0.0, 0.2, 1.5), Vector3(-0.07, 0.53, 0.5)))
	for i in 4:
		var x := -0.12 if i % 2 == 0 else 0.12
		var z := -0.22 if i < 2 else 0.22
		b.add_child(_mesh(_capsule(0.05, 0.3), m, Vector3(x, 0.14, z)))


## Effetto del propulsore sotto una miniatura in volo
static func jet(col: Color) -> Node3D:
	var n := Node3D.new()
	var c := _mesh(_cyl(0.02, 0.09, 0.35, 10), mat(col, 0.0, 0.2, 2.5), Vector3(0, -0.18, -0.08), Vector3(PI, 0, 0))
	c.material_override = c.material_override.duplicate()
	c.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c.material_override.albedo_color.a = 0.55
	n.add_child(c)
	return n


## Elementi del terreno per la mappa Reborn
static func tree(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(0.28, 0.5)
	n.add_child(_mesh(_cyl(0.02, 0.03, h * 0.4), mat(Color("#4a3423")), Vector3(0, h * 0.2, 0)))
	n.add_child(_mesh(_cyl(0.0, rng.randf_range(0.11, 0.17), h, 7), mat(Color("#3f6a24").lerp(Color("#5d7f2a"), rng.randf()), 0.0, 0.9), Vector3(0, h * 0.4 + h * 0.5, 0)))
	return n


static func rock(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(0.35, 0.8)
	n.add_child(_mesh(_cyl(0.02, rng.randf_range(0.2, 0.33), h, 5), mat(Color("#7a5532").lerp(Color("#9b7a55"), rng.randf()), 0.0, 0.95), Vector3(0, h * 0.5, 0), Vector3(0, rng.randf() * TAU, 0)))
	return n


static func building(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var k := rng.randi_range(0, 2)
	var col := Color("#d8d2c4").lerp(Color("#bfb6a4"), rng.randf())
	if k == 0:
		n.add_child(_mesh(_sphere(0.22, 0.3), mat(col, 0.2, 0.5), Vector3(0, 0.0, 0)))
	elif k == 1:
		var h := rng.randf_range(0.3, 0.75)
		n.add_child(_mesh(_cyl(0.1, 0.13, h, 8), mat(col, 0.3, 0.4), Vector3(0, h * 0.5, 0)))
		n.add_child(_mesh(_cyl(0.16, 0.1, 0.06, 8), mat(Color("#6fd0ff"), 0.5, 0.2, 0.6), Vector3(0, h, 0)))
	else:
		var h2 := rng.randf_range(0.2, 0.45)
		n.add_child(_mesh(_box(0.26, h2, 0.2), mat(col, 0.2, 0.5), Vector3(0, h2 * 0.5, 0)))
	return n
