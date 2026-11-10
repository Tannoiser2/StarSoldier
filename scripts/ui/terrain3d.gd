class_name SSTerrain
extends RefCounted
## Terreno in rilievo di StarSoldier: la mappa SPI stesa su una superficie 3D le cui quote vengono dal
## tipo di terreno di ogni esagono (montagne alte e frastagliate, terreno accidentato a colline basse,
## copertura organica appena rialzata, laghi incassati, città in piano). La griglia viene ammorbidita
## perché i passaggi fra esagoni diventino pendii, poi le città sono rispianate.
## ground(x, z) dà la quota in ogni punto: serve per posare pedine, segni, edifici e alberi e per
## capire quale esagono si tocca sullo schermo.

const D = preload("res://scripts/data/ss_data.gd")

const STEP := 0.2                 # passo della griglia (un esagono è largo 1)
const BASE := {".": 0.0, "b": 0.36, "o": 0.08, "m": 1.25, "u": 0.0, "l": -0.18}
const NOISE := {".": 0.025, "b": 0.16, "o": 0.04, "m": 0.55, "u": 0.0, "l": 0.0}
const H_MAX := 2.4
const H_MIN := -0.4
const SKIRT := -0.45               # quota del tavolo sotto la mappa

var nx := 0
var nz := 0
var x0 := 0.0
var z0 := 0.0
var w := 0.0
var d := 0.0
var h := PackedFloat32Array()
var hex_h := {}                   # quota al centro di ogni esagono


func _init() -> void:
	w = Hex.IMG_W / Hex.DX
	d = Hex.IMG_H / Hex.DX
	x0 = -w * 0.5
	z0 = -d * 0.5
	nx = int(ceil(w / STEP)) + 1
	nz = int(ceil(d / STEP)) + 1
	_compute()


func _idx(i: int, j: int) -> int:
	return j * nx + i


func _compute() -> void:
	var n := nx * nz
	var base := PackedFloat32Array()
	var rough := PackedFloat32Array()
	var flat := PackedFloat32Array()        # 1 dove la città va rispianata
	base.resize(n)
	rough.resize(n)
	flat.resize(n)
	for j in nz:
		for i in nx:
			var p := Vector3(x0 + float(i) * STEP, 0, z0 + float(j) * STEP)
			var hh := Hex.at_world(p)
			var t := "."
			if hh > 0:
				t = D.terrain(hh)
			var k := _idx(i, j)
			base[k] = BASE.get(t, 0.0)
			rough[k] = NOISE.get(t, 0.0)
			flat[k] = 1.0 if t == "u" else 0.0
	# pendii: tre passate di media 3×3 (circa mezzo esagono di raggio)
	for pass_i in 3:
		base = _blur(base)
		rough = _blur(rough)
	for pass_i in 2:
		flat = _blur(flat)
	var noise := FastNoiseLite.new()
	noise.seed = 2451
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.55
	noise.fractal_octaves = 3
	h.resize(n)
	for j in nz:
		for i in nx:
			var k := _idx(i, j)
			var nv := noise.get_noise_2d(float(i) * STEP, float(j) * STEP)   # -1..1
			var v := base[k] + rough[k] * nv
			# le cime delle montagne più aguzze
			if base[k] > 0.6:
				v += (base[k] - 0.6) * 0.6 * maxf(nv, 0.0)
			v = lerpf(v, 0.0, clampf(flat[k] * 1.6, 0.0, 1.0))
			# ai bordi della mappa il terreno scende verso il tavolo
			var edge := minf(minf(float(i), float(nx - 1 - i)), minf(float(j), float(nz - 1 - j))) * STEP
			if edge < 0.6:
				v *= edge / 0.6
			h[k] = clampf(v, H_MIN, H_MAX)
	for hx in Hex.all_hexes():
		var c := Hex.world(hx)
		hex_h[hx] = ground(c.x, c.z)


func _blur(a: PackedFloat32Array) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(a.size())
	for j in nz:
		var j0 := maxi(j - 1, 0)
		var j1 := mini(j + 1, nz - 1)
		for i in nx:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, nx - 1)
			var s := a[j0 * nx + i0] + a[j0 * nx + i] + a[j0 * nx + i1] \
				+ a[j * nx + i0] + a[j * nx + i] + a[j * nx + i1] \
				+ a[j1 * nx + i0] + a[j1 * nx + i] + a[j1 * nx + i1]
			o[j * nx + i] = s / 9.0
	return o


## quota del terreno nel punto (x, z), interpolata
func ground(x: float, z: float) -> float:
	var fx := clampf((x - x0) / STEP, 0.0, float(nx - 1) - 0.001)
	var fz := clampf((z - z0) / STEP, 0.0, float(nz - 1) - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - float(i)
	var tz := fz - float(j)
	var a := lerpf(h[_idx(i, j)], h[_idx(i + 1, j)], tx)
	var b := lerpf(h[_idx(i, j + 1)], h[_idx(i + 1, j + 1)], tx)
	return lerpf(a, b, tz)


func at_hex(hx: int) -> float:
	return hex_h.get(hx, 0.0)


## la superficie con la mappa sopra e le pareti laterali fino al tavolo
func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	uvs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k := _idx(i, j)
			var x := x0 + float(i) * STEP
			var z := z0 + float(j) * STEP
			verts[k] = Vector3(x, h[k], z)
			uvs[k] = Vector2(clampf((x - x0) / w, 0.0, 1.0), clampf((z - z0) / d, 0.0, 1.0))
			var hl := h[_idx(maxi(i - 1, 0), j)]
			var hr := h[_idx(mini(i + 1, nx - 1), j)]
			var hd := h[_idx(i, maxi(j - 1, 0))]
			var hu := h[_idx(i, mini(j + 1, nz - 1))]
			norms[k] = Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
	for j in nz - 1:
		for i in nx - 1:
			var a := _idx(i, j)
			var b := _idx(i + 1, j)
			var c := _idx(i, j + 1)
			var e := _idx(i + 1, j + 1)
			idx.append_array([a, b, c, b, e, c])
	# pareti laterali dal bordo della mappa fino al tavolo
	var ring := []
	for i in nx:
		ring.append(_idx(i, 0))
	for j in range(1, nz):
		ring.append(_idx(nx - 1, j))
	for i in range(nx - 2, -1, -1):
		ring.append(_idx(i, nz - 1))
	for j in range(nz - 2, 0, -1):
		ring.append(_idx(0, j))
	ring.append(ring[0])
	var start := verts.size()
	for k in ring:
		var v: Vector3 = verts[k]
		var out := Vector3(signf(v.x) if absf(absf(v.x) - w * 0.5) < STEP * 0.6 else 0.0, 0, signf(v.z) if absf(absf(v.z) - d * 0.5) < STEP * 0.6 else 0.0)
		if out == Vector3.ZERO:
			out = Vector3.UP
		verts.append(v)
		norms.append(out.normalized())
		uvs.append(uvs[k])
		verts.append(Vector3(v.x, SKIRT, v.z))
		norms.append(out.normalized())
		uvs.append(uvs[k])
	for e in ring.size() - 1:
		var a := start + e * 2
		var b := a + 2
		idx.append_array([a, a + 1, b, b, a + 1, b + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## punto del terreno sotto un punto dello schermo (raggio dalla telecamera), oppure null
func ray(o: Vector3, dir: Vector3) -> Variant:
	if absf(dir.y) < 1e-5:
		return null
	# si parte dal piano della quota massima e si scende a passi fino a passare sotto il terreno
	var t0 := 0.0
	if o.y > H_MAX:
		if dir.y >= 0.0:
			return null
		t0 = (H_MAX - o.y) / dir.y
	var t1 := (H_MIN - o.y) / dir.y if dir.y < 0.0 else t0 + 200.0
	var stp := 0.08
	var prev := t0
	var t := t0
	while t <= t1:
		var p := o + dir * t
		if p.y <= ground(p.x, p.z):
			# raffinamento
			var lo := prev
			var hi := t
			for k in 12:
				var mid := (lo + hi) * 0.5
				var q := o + dir * mid
				if q.y <= ground(q.x, q.z):
					hi = mid
				else:
					lo = mid
			return o + dir * hi
		prev = t
		t += stp
	return null
