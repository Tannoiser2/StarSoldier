class_name SSCitta3D
extends RefCounted
## Le città della mappa in 3D: gli stessi edifici modellati in Blender (citta_starsoldier.blend), ricostruiti
## qui con le stesse misure sulla pianta di SSCitta, così coincidono con i simboli stampati sulla mappa.
## Ogni edificio poggia sul terreno; tutti i pezzi dello stesso materiale finiscono in una sola mesh
## (pochi oggetti, leggero sul web).
## Le misure sono scritte come in Blender (x Est, y Nord, z su) e convertite al mondo del gioco.

const C = preload("res://scripts/data/citta.gd")

var _st := {}            # materiale -> SurfaceTool
var _mats := {}
var _ground: Callable
var _gy := 0.0           # quota del terreno sotto l'edificio in costruzione


func _init() -> void:
	_mats = {
		"cemento": _mat(Color(0.80, 0.76, 0.68), 0.0, 0.8),
		"cemento_scuro": _mat(Color(0.58, 0.55, 0.50), 0.0, 0.8),
		"metallo": _mat(Color(0.70, 0.72, 0.74), 0.7, 0.35),
		"inchiostro": _mat(Color(0.16, 0.13, 0.11), 0.2, 0.6),
		"vetro": _mat(Color(0.45, 0.70, 0.85), 0.3, 0.15),
		"luce": _mat(Color(1.0, 0.62, 0.25), 0.0, 0.5, 2.0),
	}


func _mat(c: Color, metal: float, rough: float, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


## da Blender (x, y Nord, z su) al gioco (x, y su, z Sud)
static func _g(b: Vector3) -> Vector3:
	return Vector3(b.x, b.z, -b.y)


func _add(mesh: Mesh, mat: String, xf: Transform3D) -> void:
	if not _st.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[mat] = st
	xf.origin.y += _gy
	_st[mat].append_from(mesh, 0, xf)


# ---------------------------------------------------------------- primitive (come nello script di Blender)

func _cyl(r: float, h: float, loc: Vector3, verts := 24, mat := "cemento", r2 := -1.0, rot := 0.0) -> void:
	var m := CylinderMesh.new()
	m.bottom_radius = r
	m.top_radius = r if r2 < 0.0 else r2
	m.height = h
	m.radial_segments = verts
	m.rings = 1
	# in Blender il primo vertice è sull'asse x: in Godot il cilindro parte da z, si ruota di un quarto
	var b := Basis(Vector3.UP, PI / 2.0 + rot)
	_add(m, mat, Transform3D(b, _g(loc + Vector3(0, 0, h / 2.0))))


func _dome(r: float, loc: Vector3, mat := "cemento", seg := 24) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r
	m.is_hemisphere = true
	m.radial_segments = seg
	m.rings = 6
	_add(m, mat, Transform3D(Basis(), _g(loc)))


func _sphere(r: float, loc: Vector3, mat := "cemento", seg := 20) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = 10
	_add(m, mat, Transform3D(Basis(), _g(loc)))


func _box(sx: float, sy: float, sz: float, loc: Vector3, rot := 0.0, mat := "cemento") -> void:
	var m := BoxMesh.new()
	m.size = Vector3(sx, sz, sy)
	_add(m, mat, Transform3D(Basis(Vector3.UP, rot), _g(loc + Vector3(0, 0, sz / 2.0))))


# ---------------------------------------------------------------- costruzione

## parent: dove appendere le mesh; ground: Callable(x, z) -> quota del terreno
func build(parent: Node3D, ground: Callable) -> void:
	_ground = ground
	var top := {}           # nome -> [centro (Blender), quota dei tubi, quota del terreno]
	for e in C.EDIFICI:
		var t: String = e["t"]
		var c := Vector3(e["x"], -e["z"], 0.0)
		_gy = float(ground.call(e["x"], e["z"])) - 0.02
		match t:
			"torre", "hub":
				var r: float = e["r"]
				var hh := r * (1.4 if t == "hub" else 1.1)
				_cyl(r, hh, c, 28, "cemento")
				_cyl(r * 1.05, r * 0.12, c + Vector3(0, 0, hh * 0.55), 28, "inchiostro")
				_cyl(r * 0.98, r * 0.08, c + Vector3(0, 0, hh * 0.25), 28, "vetro")
				var dc := c + Vector3(-r * 0.25, r * 0.08, hh)
				_cyl(r * 0.62, r * 0.12, dc - Vector3(0, 0, 0.001), 24, "cemento_scuro")
				_dome(r * 0.55, dc + Vector3(0, 0, r * 0.12), "metallo")
				if t == "hub":
					_cyl(r * 0.05, r * 1.1, dc + Vector3(0, 0, r * 0.6), 8, "inchiostro")
					_sphere(r * 0.1, dc + Vector3(0, 0, r * 1.75), "luce", 10)
				top[e["n"]] = [c, hh * 0.6, _gy]
			"sfera":
				var r: float = e["r"]
				_cyl(r * 0.45, r * 0.7, c, 16, "cemento_scuro")
				_sphere(r, c + Vector3(0, 0, r * 1.45), "cemento")
				_cyl(r * 1.01, r * 0.12, c + Vector3(0, 0, r * 1.35), 20, "vetro")
				top[e["n"]] = [c, r * 1.45, _gy]
			"pod":
				var r: float = e["r"]
				_cyl(r, r * 0.35, c, 18, "cemento_scuro")
				_dome(r * 0.9, c + Vector3(0, 0, r * 0.35), "cemento")
				_sphere(r * 0.25, c + Vector3(-r * 0.35, 0, r * 1.1), "luce", 10)
				top[e["n"]] = [c, r * 0.4, _gy]
			"blocco":
				var s: float = e["s"]
				var rot := deg_to_rad(float(e.get("rot", 0)))
				var h := s * 0.85
				_box(s, s, h, c, rot, "cemento")
				_box(s * 1.04, s * 1.04, s * 0.06, c + Vector3(0, 0, h * 0.6), rot, "inchiostro")
				_box(s * 0.5, s * 0.5, s * 0.18, c + Vector3(0, 0, h), rot, "cemento_scuro")
				_box(s * 1.01, s * 1.01, s * 0.1, c + Vector3(0, 0, h * 0.3), rot, "vetro")
				top[e["n"]] = [c, h * 0.45, _gy]
			"gruppo":
				var w: float = e["w"]
				var d: float = e["h"]
				var x0 := c.x - w / 2.0
				var y0 := c.y - d / 2.0
				_box(w * 0.42, d * 0.42, d * 0.55, Vector3(x0 + w * 0.22, y0 + d * 0.22, 0), 0.0, "cemento")
				_box(w * 0.42, d * 0.42, d * 0.85, Vector3(x0 + w * 0.36, y0 + d * 0.44, 0), 0.0, "cemento")
				_box(w * 0.40, d * 0.40, d * 1.15, Vector3(x0 + w * 0.50, y0 + d * 0.66, 0), 0.0, "cemento_scuro")
				for i in 2:
					for j in 3:
						var hb := d * (0.6 + 0.35 * float((i + j) % 2))
						_box(w * 0.14, d * 0.28, hb, Vector3(x0 + w * (0.76 + 0.15 * i), y0 + d * (0.17 + 0.32 * j), 0), 0.0, "inchiostro" if (i + j) % 2 == 1 else "cemento")
				_box(w * 0.43, d * 0.06, d * 0.08, Vector3(x0 + w * 0.22, y0 + d * 0.22, d * 0.4), 0.0, "vetro")
				top[e["n"]] = [c, d * 0.4, _gy]
			"bunker", "bunker2":
				var r: float = e["r"]
				var h := r * 0.55
				_cyl(r, h, c, 6, "cemento", r * 0.9)
				if t == "bunker2":
					_cyl(r * 0.7, h * 0.9, c + Vector3(r * 0.2, r * 0.25, h), 6, "cemento_scuro", r * 0.65)
				else:
					_cyl(r * 0.5, h * 0.3, c + Vector3(0, 0, h), 24, "inchiostro")
					for i in 5:
						_box(r * 0.06, r * 0.8, h * 0.18, c + Vector3(-r * 0.24 + i * r * 0.12, 0, h * 1.3), 0.0, "metallo")
				top[e["n"]] = [c, h * 0.6, _gy]
			"quarto":
				var r: float = e["r"]
				_cyl(r, r * 0.2, c, 28, "cemento_scuro")
				_dome(r * 0.95, c + Vector3(0, 0, r * 0.2), "cemento")
				for i in 5:
					var a := deg_to_rad(95.0 + i * 17.0)
					_box(r * 0.08, r * 0.9, r * 0.75, c + Vector3(cos(a) * r * 0.45, sin(a) * r * 0.45, r * 0.2), a - PI / 2.0, "metallo")
				_cyl(r * 0.12, r * 0.5, c + Vector3(0, 0, r * 1.1), 8, "inchiostro")
				top[e["n"]] = [c, r * 0.4, _gy]
			"rene":
				var r: float = e["r"]
				_cyl(r, r * 0.3, c, 28, "cemento_scuro")
				_dome(r * 0.92, c + Vector3(0, 0, r * 0.3), "cemento")
				var oc := c + Vector3(r * 0.55, r * 0.55, 0)
				_cyl(r * 0.55, r * 0.25, oc, 20, "cemento_scuro")
				_dome(r * 0.5, oc + Vector3(0, 0, r * 0.25), "cemento")
				_cyl(r * 0.22, r * 0.3, c + Vector3(0, 0, r * 1.15), 16, "vetro")
				top[e["n"]] = [c, r * 0.5, _gy]
			"freccia":
				_wedge(e["pts"])
	_build_tubes(top)
	for k in _st:
		var st: SurfaceTool = _st[k]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "citta_" + k
		mi.mesh = st.commit()
		mi.material_override = _mats[k]
		parent.add_child(mi)
	_st.clear()


## la piramide a freccia di 3533: tre punti a terra, punta bassa verso Est
func _wedge(pts: Array) -> void:
	var p: Array = []
	for q in pts:
		p.append(Vector3(q[0], float(_ground.call(q[0], q[1])) - 0.02, q[1]))
	var tp := [p[0] + Vector3(0, 0.16, 0), p[1] + Vector3(0, 0.03, 0), p[2] + Vector3(0, 0.16, 0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := [[tp[0], tp[2], tp[1]]]
	for i in 3:
		var j := (i + 1) % 3
		tris.append([p[i], tp[j], p[j]])
		tris.append([p[i], tp[i], tp[j]])
	var cen: Vector3 = (p[0] + p[1] + p[2]) / 3.0
	for tr in tris:
		# triangoli rivolti verso l'esterno (in Godot la faccia davanti gira in senso orario)
		var n: Vector3 = (tr[1] - tr[0]).cross(tr[2] - tr[0])
		var mid: Vector3 = (tr[0] + tr[1] + tr[2]) / 3.0
		if n.dot(mid - cen - Vector3(0, -0.05, 0)) > 0.0:
			tr = [tr[0], tr[2], tr[1]]
		for v in tr:
			st.add_vertex(v)
	st.index()
	st.generate_normals()
	_gy = 0.0
	_add(st.commit(), "metallo", Transform3D())
	var m := SphereMesh.new()
	m.radius = 0.03
	m.height = 0.06
	m.radial_segments = 10
	m.rings = 5
	_gy = 0.0
	_add(m, "luce", Transform3D(Basis(), p[1] + Vector3(0, 0.06, 0)))


func _build_tubes(top: Dictionary) -> void:
	for tb in C.TUBI:
		var a: Array = top[tb[0]]
		var b: Array = top[tb[1]]
		var k: int = tb[2]
		var h: float = minf(a[1], b[1])
		# estremi alla quota dei due edifici
		var pa := _g(a[0]) + Vector3(0, a[2] + h, 0)
		var pb := _g(b[0]) + Vector3(0, b[2] + h, 0)
		var d := pb - pa
		var length := d.length()
		var r: float = [0.018, 0.035, 0.025][k]
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = length
		m.radial_segments = 10
		m.rings = 1
		var up := d.normalized()
		var side := up.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var basis := Basis(side, up, side.cross(up))
		_gy = 0.0
		_add(m, "metallo" if k != 1 else "cemento_scuro", Transform3D(basis, (pa + pb) * 0.5))
		# piloni sotto i tubi
		var n := int(length / 0.35)
		for i in range(1, n):
			var q := pa + d * (float(i) / float(n))
			var gq := float(_ground.call(q.x, q.z))
			var ph := q.y - gq
			if ph <= 0.01:
				continue
			var pm := CylinderMesh.new()
			pm.top_radius = r * 0.6
			pm.bottom_radius = r * 0.6
			pm.height = ph
			pm.radial_segments = 8
			pm.rings = 1
			_add(pm, "inchiostro", Transform3D(Basis(), Vector3(q.x, gq + ph * 0.5, q.z)))
