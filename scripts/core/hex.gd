class_name Hex
extends RefCounted
## Geometria della mappa di StarSoldier.
## La mappa SPI ha gli esagoni numerati XXYY (XX = 01-39, YY = 01-54). Nel modulo TTS la mappa è
## girata in orizzontale: la riga XX = 39 sta in alto, le colonne YY vanno da sinistra (01, Ovest) a
## destra (54, Est). Le righe pari sono spostate di mezzo esagono a destra e hanno 53 esagoni.
## Un esagono si indica con l'intero XXYY (es. 3321): righe r = XX, colonne c = YY.

const ROWS := 39
const COLS := 54
## Pixel dell'immagine originale (7539 × 4840) del modulo TTS
const IMG_W := 7539.0
const IMG_H := 4840.0
const X0 := 145.0
const Y0 := 160.0
const DX := 137.12
const DY := 119.2

static var wrap := false   # Stazione Zulu (40.5): bordi Est e Ovest uniti

## Direzioni del diagramma di dispersione stampato sulla mappa (1-6), in coordinate assiali
const DIRS := [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1)]


static func code(r: int, c: int) -> int:
	return r * 100 + c


static func row(h: int) -> int:
	return h / 100


static func col(h: int) -> int:
	return h % 100


static func width(r: int) -> int:
	return COLS if r % 2 == 1 else COLS - 1


static func valid(h: int) -> bool:
	var r := row(h)
	var c := col(h)
	return r >= 1 and r <= ROWS and c >= 1 and c <= width(r)


static func label(h: int) -> String:
	return "%04d" % h if h > 0 else "fuori"


## coordinate assiali (q, r0) con righe 0-based "dispari spostate"
static func axial(h: int) -> Vector2i:
	var r0 := row(h) - 1
	var c0 := col(h) - 1
	return Vector2i(c0 - (r0 - (r0 & 1)) / 2, r0)


static func from_axial(a: Vector2i) -> int:
	var r0 := a.y
	var c0 := a.x + (r0 - (r0 & 1)) / 2
	var r := r0 + 1
	var c := c0 + 1
	if wrap and r >= 1 and r <= ROWS:
		var w := width(r)
		while c < 1:
			c += w
		while c > w:
			c -= w
	return code(r, c)


static func adist(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


static func dist(a: int, b: int) -> int:
	if a <= 0 or b <= 0:
		return 99
	var aa := axial(a)
	var bb := axial(b)
	var d := adist(aa, bb)
	if wrap:
		d = mini(d, adist(aa, bb + Vector2i(COLS, 0)))
		d = mini(d, adist(aa, bb - Vector2i(COLS, 0)))
	return d


static func neighbor(h: int, dir: int) -> int:
	var a: Vector2i = axial(h) + DIRS[(dir - 1) % 6]
	var n := from_axial(a)
	return n if valid(n) else -1


static func neighbors(h: int) -> Array:
	var out := []
	for d in range(1, 7):
		var n := neighbor(h, d)
		if n > 0:
			out.append(n)
	return out


static func ring(h: int, rad: int) -> Array:
	var out := []
	var a := axial(h)
	for dq in range(-rad, rad + 1):
		for dr in range(maxi(-rad, -dq - rad), mini(rad, -dq + rad) + 1):
			var n := from_axial(a + Vector2i(dq, dr))
			if valid(n) and not out.has(n):
				out.append(n)
	return out


## Esagoni attraversati dalla linea di tiro (esclusi i due estremi). Restituisce due elenchi: la linea
## leggermente spostata da una parte e dall'altra, così chi tira lungo il lato fra due esagoni sceglie
## il passaggio più favorevole.
static func lines(a: int, b: int) -> Array:
	var aa := axial(a)
	var bb := axial(b)
	if wrap:
		var best := bb
		for k in [-1, 1]:
			var alt := bb + Vector2i(COLS * k, 0)
			if adist(aa, alt) < adist(aa, best):
				best = alt
		bb = best
	var n := adist(aa, bb)
	var out := []
	for eps in [1e-4, -1e-4]:
		var path := []
		for i in range(1, n):
			var t := float(i) / float(n)
			var q := lerpf(float(aa.x) + eps, float(bb.x) + eps, t)
			var r := lerpf(float(aa.y) + eps * 0.5, float(bb.y) + eps * 0.5, t)
			var hh := from_axial(_round(q, r))
			if valid(hh) and hh != a and hh != b and not path.has(hh):
				path.append(hh)
		out.append(path)
	return out


static func _round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


## Bordo della mappa: "O" Ovest (colonna 1), "E" Est (ultima colonna), "N" (riga 39), "S" (riga 1)
static func on_edge(h: int, edge: String) -> bool:
	if not valid(h):
		return false
	match edge:
		"O":
			return col(h) == 1
		"E":
			return col(h) == width(row(h))
		"N":
			return row(h) == ROWS
		"S":
			return row(h) == 1
		"*":
			return col(h) == 1 or col(h) == width(row(h)) or row(h) == 1 or row(h) == ROWS
	return false


static func edge_hexes(edge: String) -> Array:
	var out := []
	for r in range(1, ROWS + 1):
		for c in range(1, width(r) + 1):
			var h := code(r, c)
			if on_edge(h, edge):
				out.append(h)
	return out


static func all_hexes() -> Array:
	var out := []
	for r in range(1, ROWS + 1):
		for c in range(1, width(r) + 1):
			out.append(code(r, c))
	return out


## centro dell'esagono in pixel dell'immagine originale
static func pixel(h: int) -> Vector2:
	var r := row(h)
	var c := col(h)
	return Vector2(X0 + float(c - 1) * DX + (DX * 0.5 if r % 2 == 0 else 0.0), Y0 + float(ROWS - r) * DY)


## centro dell'esagono nel mondo 3D (1 unità = distanza fra due esagoni vicini)
static func world(h: int) -> Vector3:
	var p := pixel(h)
	return Vector3((p.x - IMG_W * 0.5) / DX, 0.0, (p.y - IMG_H * 0.5) / DX)


static func at_world(p: Vector3) -> int:
	var px := p.x * DX + IMG_W * 0.5
	var py := p.z * DX + IMG_H * 0.5
	var r0 := int(round(float(ROWS) - (py - Y0) / DY))
	var best := -1
	var bd := 1e12
	for r in range(r0 - 1, r0 + 2):
		if r < 1 or r > ROWS:
			continue
		var c0 := int(round((px - X0 - (DX * 0.5 if r % 2 == 0 else 0.0)) / DX)) + 1
		for c in range(c0 - 1, c0 + 2):
			var h := code(r, c)
			if not valid(h):
				continue
			var d := pixel(h).distance_squared_to(Vector2(px, py))
			if d < bd:
				bd = d
				best = h
	return best if bd < DX * DX * 0.36 else -1
