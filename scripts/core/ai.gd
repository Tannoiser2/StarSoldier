class_name SSAI
extends RefCounted
## Avversario automatico di StarSoldier. Per ogni soldato valuta i bersagli visibili (stima del
## differenziale con le contromisure probabili), sceglie fra fuoco, armi lanciate, movimento verso
## l'obiettivo dello scenario e contromisure; usa il fuoco d'opportunità quando difende fermo.
## Non conosce i piani dell'avversario né le posizioni segrete: vede solo quello che vede il suo lato.

const D = preload("res://scripts/data/ss_data.gd")

var level := 1
var rng := RandomNumberGenerator.new()
var _ends := {}            # esagoni d'arrivo già scelti per i compagni in questo piano


func _init(lv := 1) -> void:
	level = lv
	rng.randomize()


func decide(eng: SSEngine, s: int, req: Dictionary):
	match str(req.get("k", "")):
		"schiera":
			return auto_deploy(eng, s, req)
		"piano":
			return plan(eng, s)
	return {}


# ================================================================ schieramento

func auto_deploy(eng: SSEngine, s: int, req: Dictionary) -> Dictionary:
	var out := {"pos": {}, "civ": [], "gen": [], "mine": [], "orb": {}}
	var taken := {}
	var ids: Array = req.get("units", [])
	var zone := str(req.get("zone", ""))
	# civili
	var ncv := int(req.get("civ", 0))
	if ncv > 0 and eng.sit == "B":
		var bb := _basic_civs(ncv, int(req.get("gen", 3)))
		out["civ"] = bb[0]
		out["gen"] = bb[1]
	elif ncv > 0:
		out["civ"] = _civ_spots(eng, ncv, int(req.get("dist_civ", 2)))
		if int(req.get("gen", 0)) > 0:
			var idx := []
			for i in ncv:
				idx.append(i)
			# 13.2: al massimo due veri per gruppo di città
			var g := []
			for i in ncv:
				g.append(false)
			var k := 0
			idx.shuffle()
			for i in idx:
				if k >= int(req["gen"]):
					break
				g[i] = true
				k += 1
			out["gen"] = g
	# basi
	var bases := []
	for id in ids:
		if eng.units[id]["kind"] == "base":
			bases.append(id)
	if not bases.is_empty():
		var anchor := _good_hex(eng, zone, taken, ["o", "b", "m"])
		var spots := [anchor]
		if req.get("contigue", false):
			for n in Hex.neighbors(anchor):
				if spots.size() >= bases.size():
					break
				if eng.deploy_zone_ok(s, n, req):
					spots.append(n)
		while spots.size() < bases.size():
			var h := _good_hex(eng, zone, taken, ["o", "b"], spots, 6)
			spots.append(h)
		for i in bases.size():
			out["pos"][bases[i]] = spots[i]
			taken[spots[i]] = true
	# soldati: vicino alle basi o ai civili, in copertura
	var centers: Array = []
	for b in bases:
		centers.append(out["pos"][b])
	if centers.is_empty() and not out["civ"].is_empty():
		centers = out["civ"]
		if eng.sit == "B" and out["gen"].size() == out["civ"].size():
			centers = []
			for i in out["civ"].size():
				if out["gen"][i]:
					centers.append(out["civ"][i])
	for id in ids:
		var u: Dictionary = eng.units[id]
		if u["kind"] == "base":
			continue
		var h := 0
		if eng.sit == "A" and s == 0:
			# assalto dall'orbita: si scende vicino alle basi sospettate (a caso nella metà Est)
			h = _rand_hex(eng, func(x): return Hex.col(x) >= 20 and Hex.col(x) <= 46)
		elif not centers.is_empty():
			var c: int = centers[rng.randi_range(0, centers.size() - 1)]
			h = _near_cover(eng, c, 5, taken, s, req)
		else:
			h = _good_hex(eng, zone, taken, ["o", "u", "b"])
		out["pos"][id] = h
		taken[h] = true
	# mine: sulle vie d'accesso verso le basi o i civili
	for i in int(req.get("mine", 0)):
		var c2: int = centers[i % centers.size()] if not centers.is_empty() else _rand_hex(eng, func(x): return Hex.col(x) > 15)
		var h2 := _rand_ring(eng, c2, 3, 7)
		out["mine"].append(h2)
	# bombardamento preparatorio
	if req.has("orb_pre"):
		var bb := []
		for i in 10:
			bb.append(_rand_hex(eng, func(x): return Hex.col(x) >= 14 and D.terrain(x) in ["o", "b", "."]))
		var oo := []
		for i in 3:
			oo.append(_rand_hex(eng, func(x): return Hex.col(x) >= 14))
		out["orb"] = {"b": bb, "o": oo}
	return out


## 13.2: un segnalino per esagono, al massimo tre per gruppo di città contigue e due veri per gruppo
func _basic_civs(n: int, ngen: int) -> Array:
	var groups := urban_groups()
	groups.shuffle()
	var hexes := []
	var gen := []
	var per := {}
	var gi := 0
	# prima i veri, in gruppi diversi
	while hexes.size() < n and gi < 400:
		var g: Array = groups[gi % groups.size()]
		var k := gi % groups.size()
		gi += 1
		var used: int = per.get(k, 0)
		if used >= 3 or used >= g.size():
			continue
		var free := []
		for h in g:
			if not hexes.has(h):
				free.append(h)
		if free.is_empty():
			continue
		var h2: int = free[rng.randi_range(0, free.size() - 1)]
		var is_gen := ngen > 0 and used < 2 and gen.count(true) < ngen and (hexes.size() % 3 == 0 or n - hexes.size() <= ngen - gen.count(true))
		hexes.append(h2)
		gen.append(is_gen)
		per[k] = used + 1
	while hexes.size() < n:
		hexes.append(_rand_hex(null, func(x): return not hexes.has(x)))
		gen.append(false)
	while gen.count(true) < ngen:
		gen[gen.find(false)] = true
	return [hexes, gen]


static func urban_groups() -> Array:
	var seen := {}
	var out := []
	for h in Hex.all_hexes():
		if D.terrain(h) != "u" or seen.has(h):
			continue
		var g := []
		var stack := [h]
		seen[h] = true
		while not stack.is_empty():
			var x: int = stack.pop_back()
			g.append(x)
			for n in Hex.neighbors(x):
				if D.terrain(n) == "u" and not seen.has(n):
					seen[n] = true
					stack.append(n)
		out.append(g)
	return out


func _civ_spots(eng: SSEngine, n: int, mind: int) -> Array:
	var urb := []
	for h in Hex.all_hexes():
		if D.terrain(h) == "u":
			urb.append(h)
	urb.shuffle()
	var out := []
	for h in urb:
		if out.size() >= n:
			break
		var ok := true
		for o in out:
			if Hex.dist(o, h) < mind:
				ok = false
		if ok:
			out.append(h)
	# se le città non bastano si scende a distanze minori, poi si usa qualsiasi esagono
	var d := mind - 1
	while out.size() < n and d >= 1:
		for h in urb:
			if out.size() >= n:
				break
			if out.has(h):
				continue
			var ok2 := true
			for o in out:
				if Hex.dist(o, h) < d:
					ok2 = false
			if ok2:
				out.append(h)
		d -= 1
	while out.size() < n:
		var h3 := _rand_hex(eng, func(x): return not out.has(x))
		out.append(h3)
	return out


func _rand_hex(eng: SSEngine, cond: Callable) -> int:
	for k in 500:
		var h := Hex.code(rng.randi_range(1, Hex.ROWS), rng.randi_range(1, 53))
		if Hex.valid(h) and cond.call(h):
			return h
	return 2027


func _rand_ring(eng: SSEngine, c: int, a: int, b: int) -> int:
	for k in 200:
		var h := Hex.code(Hex.row(c) + rng.randi_range(-b, b), Hex.col(c) + rng.randi_range(-b, b))
		if Hex.valid(h) and Hex.dist(h, c) >= a and Hex.dist(h, c) <= b:
			return h
	return c


func _good_hex(eng: SSEngine, zone: String, taken: Dictionary, pref: Array, avoid := [], mind := 0) -> int:
	for k in 600:
		var h := Hex.code(rng.randi_range(2, Hex.ROWS - 1), rng.randi_range(2, 52))
		if not Hex.valid(h) or taken.has(h):
			continue
		if zone == "est" and Hex.col(h) < 14:
			continue
		if k < 400 and not D.terrain(h) in pref:
			continue
		var ok := true
		for a in avoid:
			if Hex.dist(a, h) < mind:
				ok = false
		if ok:
			return h
	return Hex.code(20, 30)


func _near_cover(eng: SSEngine, c: int, rad: int, taken: Dictionary, s: int, req: Dictionary) -> int:
	var cand := []
	for h in Hex.ring(c, rad):
		if taken.has(h) or not eng.deploy_zone_ok(s, h, req):
			continue
		cand.append(h)
	cand.shuffle()
	var best := c
	var bv := -1.0
	for h in cand:
		var v := float(eng.tv(h)) + rng.randf()
		if v > bv:
			bv = v
			best = h
	return best


# ================================================================ piano

func plan(eng: SSEngine, s: int) -> Dictionary:
	var out := {"u": {}, "orb": []}
	var foes := _known_foes(eng, s)
	var targets := {}       # esagoni già presi di mira (per non sprecare colpi)
	_ends = {}
	var mine := eng.live(s)
	for u in mine:
		if u["on"] and not tasks_moving(u):
			_ends[u["h"]] = int(_ends.get(u["h"], 0)) + 1
	for u in mine:
		if not u["on"] and u["entry"] == "":
			continue
		var t := plan_unit(eng, u, foes, targets)
		if not t.is_empty():
			out["u"][u["id"]] = t
	out["orb"] = _orbital(eng, s, foes)
	return out


func tasks_moving(u: Dictionary) -> bool:
	return false


func _known_foes(eng: SSEngine, s: int) -> Array:
	var out := []
	for u in eng.live(1 - s, true):
		if eng.visible_to(u, s):
			out.append(u)
	return out


func plan_unit(eng: SSEngine, u: Dictionary, foes: Array, targets := {}) -> Dictionary:
	var s: int = u["side"]
	if u["kind"] == "dink":
		return {"tele": _dink_target(eng, u)}
	var budget: int = eng.avail(u)
	if budget <= 0:
		return {}
	# nel gioco standard non si brucia tutto nel primo stadio
	if eng.std and eng.stage == 1 and u["tpa"] >= 8:
		budget = mini(budget, 5 if level >= 1 else 6)
	# Ricognizione e assalto: Bravo resta nascosto finché il nemico non è vicino
	if u["hidden"] and _stay_hidden(eng, u, foes):
		return {}
	var t := {}
	if not u["on"]:
		return _entry_plan(eng, u, budget)
	var goal := _goal(eng, u, foes)
	var shot := _best_shot(eng, u, foes, budget, targets)
	var a := budget
	var aggressive: bool = eng.sit in ["X", "Z", "D"] or (eng.sit == "P" and s == 1) or (eng.sit == "A" and s == 1) or (eng.sit == "B" and s == 1)
	var must_move: bool = goal > 0 and Hex.dist(u["h"], goal) > 0 and not _at_goal(eng, u, goal)
	if eng.sit == "P" and s == 0:
		aggressive = false
	# armi lanciate su gruppi o bersagli coperti
	var ln := _launch(eng, u, foes, a, targets)
	if not ln.is_empty() and (shot.is_empty() or shot["exp"] < 2.0):
		t["ln"] = [ln]
		a -= int(ln["tp"])
	if not shot.is_empty() and a >= int(shot["tp"]) and (aggressive or not must_move or shot["exp"] >= 2.5):
		if shot.has("rf"):
			t["rf"] = [{"u": shot["rf"], "tp": shot["tp"]}]
		else:
			t["df"] = [{"h": shot["h"], "alt": shot["alt"], "tp": shot["tp"]}]
			targets[shot["h"] * 10 + shot["alt"]] = true
		a -= int(shot["tp"])
	# civili (gioco base)
	if eng.sit == "B" and s == 0:
		var civ_t := _civ_tasks(eng, u, a)
		if not civ_t.is_empty():
			for k in civ_t:
				t[k] = civ_t[k]
			a -= int(civ_t.get("_cost", 0))
			t.erase("_cost")
			if civ_t.has("se"):
				must_move = false
				goal = 0
	if must_move and a > 0 and goal != 0:
		var mv := _move_toward(eng, u, goal, a, foes)
		if not mv.is_empty():
			t["mv"] = mv
			a -= int(ceil(eng.sim_path(u, mv)["cost"] - 0.001))
	# piattaforme: cannone laser sul bersaglio migliore
	if u["kind"] == "pl" and u["laser"]:
		var lc := _laser_target(eng, u, foes)
		if not lc.is_empty():
			t["lc"] = lc
	# il resto: fuoco d'opportunità se fermi e minacciati, altrimenti contromisure
	if a > 0:
		var threat := _threat(eng, u, foes)
		if not t.has("mv") and threat and a >= 3 and eng.std and rng.randf() < 0.5:
			var of := a - 1
			t["of"] = of
			t["ofs"] = clampi(int(ceil(float(of) / 2.0)), 1, of)
			a -= of
		if a > 0 and (threat or eng.sit != "R"):
			t["cm"] = a
	return t


func _stay_hidden(eng: SSEngine, u: Dictionary, foes: Array) -> bool:
	var near := 99
	for f in foes:
		near = mini(near, Hex.dist(u["h"], f["h"]))
	if u["kind"] == "base":
		return near > 6
	return near > (6 if eng.sit == "R" else 9)


func _entry_plan(eng: SSEngine, u: Dictionary, budget: int) -> Dictionary:
	var e: String = u["entry"]
	var goal := _goal(eng, u, _known_foes(eng, u["side"]))
	var cand: Array = Hex.edge_hexes(e if e != "Q" and e != "" else "*")
	if goal > 0 and u["entry"] in ["*", "Q"]:
		pass
	var best: int = cand[0]
	var bd := 9999
	for h in cand:
		var d := Hex.dist(h, goal) if goal > 0 else rng.randi_range(0, 100)
		d += rng.randi_range(0, 6) + 6 * int(_ends.get(h, 0))
		if d < bd:
			bd = d
			best = h
	var alt0 := 1
	# contro un nemico con il bombardamento orbitale si entra in alta quota (le esplosioni a terra non arrivano)
	if u["kind"] == "pl" or int(eng.sides[1 - u["side"]]["orb"].get("b", 0)) > 0:
		alt0 = 2
	var t := {"alt0": alt0, "mv": [best]}
	var c := eng.move_cost(best, alt0)
	var a := float(budget) - c
	# prosegue verso l'obiettivo in volo radente
	if goal > 0:
		var path := _path(eng, best, goal, alt0)
		for h in path:
			var cc := eng.move_cost(h, alt0)
			if cc > a:
				break
			t["mv"].append(h)
			a -= cc
			if a < 1.0:
				break
	var last: int = t["mv"][t["mv"].size() - 1]
	_ends[last] = int(_ends.get(last, 0)) + 1
	_ends[best] = int(_ends.get(best, 0)) + 1
	if a >= 1.0:
		t["cm"] = int(floor(a))
	return t


func _at_goal(eng: SSEngine, u: Dictionary, goal: int) -> bool:
	return u["h"] == goal


## obiettivo di movimento del soldato secondo lo scenario
func _goal(eng: SSEngine, u: Dictionary, foes: Array) -> int:
	var s: int = u["side"]
	var h: int = u["h"]
	match eng.sit:
		"P":
			if s == 0:
				return _edge_goal(eng, h, eng.base_edge, u)
			# Bravo: si mette fra Alpha e la base
			var f := _nearest(h if h > 0 else Hex.code(20, 27), foes)
			if f.is_empty():
				return Hex.code(clampi(Hex.row(h) if h > 0 else 20, 3, 37), 30 if eng.base_edge == "E" else 24)
			var dc := 4 if eng.base_edge == "E" else -4
			return _clamp_hex(Hex.row(f["h"]), Hex.col(f["h"]) + dc)
		"R", "A":
			if s == 0:
				if eng.sit == "A":
					var b := _nearest_base(eng, h)
					if b > 0:
						return b
				return _sweep(eng, u)
			var f2 := _nearest(h, foes)
			return f2["h"] if not f2.is_empty() and Hex.dist(h, f2["h"]) <= 8 else h
		"B":
			if s == 0:
				return _civ_goal(eng, u)
			# umani: proteggono i civili dove sono i L'Chal Dah
			var f3 := _nearest(h if h > 0 else Hex.code(20, 27), foes)
			if not f3.is_empty():
				return f3["h"]
			return _nearest_civ(eng, h)
		"X", "Z":
			var f4 := _nearest(h if h > 0 else Hex.code(20, 27), foes)
			if not f4.is_empty():
				return f4["h"]
			return Hex.code(20, 27)
		"D":
			var d: Dictionary = eng.units[eng.dink["id"]]
			if d["on"] and alive_dict(eng, d):
				return d["h"]
			return _nearest_civ(eng, h)
	return h


func alive_dict(eng: SSEngine, u: Dictionary) -> bool:
	return eng.alive(u)


func _clamp_hex(r: int, c: int) -> int:
	r = clampi(r, 1, Hex.ROWS)
	c = clampi(c, 1, Hex.width(r))
	return Hex.code(r, c)


func _edge_goal(eng: SSEngine, h: int, edge: String, u: Dictionary) -> int:
	var r := Hex.row(h) if h > 0 else 20
	var c := Hex.width(r) if edge == "E" else 1
	return Hex.code(r, c)


func _sweep(eng: SSEngine, u: Dictionary) -> int:
	# ogni soldato batte una fascia di righe da Ovest a Est e ritorno
	var n := 0
	var idx := 0
	for o in eng.live(0):
		if o["kind"] in ["ss", "hw", "an"]:
			if o["id"] == u["id"]:
				idx = n
			n += 1
	n = maxi(n, 1)
	var band := clampi(int(round(float(idx + 0.5) * 39.0 / float(n))), 2, 38)
	var h: int = u["h"]
	var c := Hex.col(h)
	var goal_c := 54 if (eng.turn / 4) % 2 == 0 else 1
	if absi(c - goal_c) < 3:
		goal_c = 1 if goal_c == 54 else 54
	return _clamp_hex(band, goal_c)


func _nearest_base(eng: SSEngine, h: int) -> int:
	var best := 0
	var bd := 999
	for u in eng.live(1):
		if u["kind"] == "base" and u["found"]:
			var d := Hex.dist(h, u["h"])
			if d < bd:
				bd = d
				best = u["h"]
	return best


func _nearest(h: int, foes: Array) -> Dictionary:
	var best := {}
	var bd := 999
	for f in foes:
		if f["kind"] == "base":
			continue
		var d := Hex.dist(h, f["h"])
		if d < bd:
			bd = d
			best = f
	return best


func _nearest_civ(eng: SSEngine, h: int) -> int:
	var best := 0
	var bd := 999
	for c in eng.civs:
		if c["dead"] or c["h"] <= 0:
			continue
		var d := Hex.dist(h, c["h"]) if h > 0 else rng.randi_range(0, 50)
		if d < bd:
			bd = d
			best = c["h"]
	return best


func _civ_goal(eng: SSEngine, u: Dictionary) -> int:
	var h: int = u["h"]
	if u["carry"] != "":
		# verso il bordo più vicino
		var r := Hex.row(h)
		var c := Hex.col(h)
		var opts := [[c - 1, Hex.code(r, 1)], [Hex.width(r) - c, Hex.code(r, Hex.width(r))], [r - 1, Hex.code(1, mini(c, 53))], [Hex.ROWS - r, Hex.code(Hex.ROWS, c)]]
		opts.sort_custom(func(a, b): return a[0] < b[0])
		return opts[0][1]
	# un civile vero già scoperto
	for c2 in eng.civs:
		if not c2["dead"] and not c2["up"] and c2["genuine"] and c2["carrier"] == "":
			return c2["h"]
	# il segnalino non ancora controllato più vicino che nessun altro sta cercando
	var claimed := {}
	for o in eng.live(0):
		if o["id"] != u["id"] and o["on"]:
			claimed[_nearest_up(eng, o["h"], {})] = true
	var g := _nearest_up(eng, h, claimed)
	return g if g > 0 else _nearest_up(eng, h, {})


func _nearest_up(eng: SSEngine, h: int, skip: Dictionary) -> int:
	var best := 0
	var bd := 999
	for c in eng.civs:
		if c["dead"] or not c["up"] or skip.has(c["h"]):
			continue
		var d := Hex.dist(h, c["h"]) if h > 0 else 0
		if d < bd:
			bd = d
			best = c["h"]
	return best


func _civ_tasks(eng: SSEngine, u: Dictionary, a: int) -> Dictionary:
	var h: int = u["h"]
	for c in eng.civs:
		if c["h"] != h or c["dead"]:
			continue
		if c["up"] and a >= 1:
			return {"se": true, "_cost": 1}
		if not c["up"] and c["genuine"] and c["carrier"] == "" and a >= 3:
			return {"tr": c["id"], "_cost": 3}
	return {}


## Il miglior colpo diretto (o ristretto) con i punti disponibili: {h, alt, tp, exp} oppure {}.
func _best_shot(eng: SSEngine, u: Dictionary, foes: Array, budget: int, targets: Dictionary) -> Dictionary:
	var best := {}
	var bv := 0.0
	var mult := 2.0 if u["kind"] == "hw" else 1.0
	var e: float = eng.eff(u) * mult
	if e <= 0.0:
		return {}
	for f in foes:
		if not eng.lof(u["side"], u["h"], u["alt"], f["h"], f["alt"], false, u["id"]):
			if not (eng.sit == "B" and u["kind"] != "hw" and eng.lof(u["side"], u["h"], u["alt"], f["h"], f["alt"], true, u["id"])):
				continue
		var ds := float(eng.range_att(u["h"], u["alt"], f["h"], f["alt"])) + float(eng.terrain_def(f)) + _cm_guess(eng, f)
		var civ_hex: bool = eng.sit == "B" and eng._civ_marker_at(f["h"])
		for tp in range(1, budget + 1):
			var diff := int(floor(e * float(tp) - ds))
			if diff < 2:
				continue
			var exp := _exp_loss(eng, diff)
			if f["kind"] in ["pl", "base"]:
				exp = exp * 0.3 if diff >= 5 else 0.0
			var v := exp / float(tp) + (0.3 if f["tpa"] <= exp else 0.0)
			if targets.has(f["h"] * 10 + f["alt"]):
				v *= 0.7
			if v > bv:
				bv = v
				best = {"h": f["h"], "alt": f["alt"], "tp": tp, "exp": exp}
				if civ_hex or (eng.sit == "B" and not eng.lof(u["side"], u["h"], u["alt"], f["h"], f["alt"], false, u["id"])):
					best["rf"] = f["id"]
			if diff >= 5:
				break
	return best


func _cm_guess(eng: SSEngine, f: Dictionary) -> float:
	var e: float = eng.eff(f)
	if f["alt"] > 0 and f["race"] != "r":
		e *= 0.5
	return e * (1.5 if eng.std else 1.0) + 1.0


func _exp_loss(eng: SSEngine, diff: int) -> float:
	var tot := 0.0
	var w := [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]
	for r in range(2, 13):
		tot += float(D.fire_result(diff, r, eng.std)) * float(w[r - 2]) / 36.0
	return tot


func _launch(eng: SSEngine, u: Dictionary, foes: Array, a: int, targets: Dictionary) -> Dictionary:
	var ws: Array = eng.weapons(u)
	if ws.is_empty() or a < 3:
		return {}
	# un gruppo di nemici o un nemico ben coperto
	var best := {}
	var bv := 0.0
	for f in foes:
		var d := Hex.dist(u["h"], f["h"])
		if d == 0 or d > 18:
			continue
		var cnt := 0
		var friends := 0
		for hh in eng.blast(f["h"], f["alt"] == 2):
			for o in eng.units_at(hh):
				if (o["alt"] == 2) != (f["alt"] == 2):
					continue
				if o["side"] != u["side"] and eng.visible_to(o, u["side"]):
					cnt += 1
				elif o["side"] == u["side"]:
					friends += 1
		if friends > 0:
			continue
		if eng.sit == "B" and eng._civ_marker_at(f["h"]):
			continue
		var cover := float(eng.terrain_def(f))
		var v := float(cnt) * 1.5 + (cover - 1.0) * 0.4
		if f["kind"] == "base":
			v += 2.0
		if v > bv and v >= 2.0:
			bv = v
			var w := ""
			if "nb" in ws:
				w = "nb"
			elif "ffm" in ws and d <= 10:
				w = "ffm"
			elif "gpb" in ws:
				w = "gpb"
			if w == "":
				continue
			var tp := 3
			if w in ["gpb", "nb"]:
				tp = clampi(3 + int(ceil(float(d) / 5.0)) / 2, 3, a)
			best = {"w": w, "h": f["h"], "tp": tp, "hi": f["alt"] == 2}
	if best.is_empty() and "og" in ws and a >= 4 and rng.randf() < 0.15:
		# a volte una granata opacizzante fra sé e il nemico più vicino
		var f2 := _nearest(u["h"], foes)
		if not f2.is_empty() and Hex.dist(u["h"], f2["h"]) <= 8 and Hex.dist(u["h"], f2["h"]) >= 3:
			var mid: Array = Hex.lines(u["h"], f2["h"])[0]
			if not mid.is_empty():
				best = {"w": "og", "h": mid[mid.size() / 2], "tp": 3, "hi": false}
	# missile cercatore: il nemico più lontano raggiungibile (almeno 15 esagoni), anche se c'è già un
	# altro bersaglio quando quello vale poco; resta in agguato e insegue chi gli passa vicino
	if "hm" in ws and a >= 3 and (best.is_empty() or bv < 3.0) and rng.randf() < 0.55:
		var bd3 := 0
		var f3 := {}
		for f in foes:
			var d3 := Hex.dist(u["h"], f["h"])
			if d3 >= 15 and d3 <= 5 * int(a) and d3 > bd3 and f["kind"] != "base":
				bd3 = d3
				f3 = f
		if not f3.is_empty():
			best = {"w": "hm", "h": f3["h"], "tp": maxi(3, int(ceil(float(bd3) / 5.0))), "hi": false}
	return best


func _laser_target(eng: SSEngine, u: Dictionary, foes: Array) -> Dictionary:
	var best := {}
	var bv := 0.0
	for f in foes:
		var ds := float(eng.range_att(u["h"], 2, f["h"], f["alt"])) + float(eng.terrain_def(f)) + _cm_guess(eng, f)
		var diff := int(floor(24.0 - ds))
		if diff < 2:
			continue
		var v := _exp_loss(eng, diff)
		if v > bv:
			bv = v
			best = {"h": f["h"], "alt": f["alt"]}
	return best


func _threat(eng: SSEngine, u: Dictionary, foes: Array) -> bool:
	for f in foes:
		if Hex.dist(u["h"], f["h"]) <= 14:
			return true
	return false


## Movimento verso l'obiettivo entro i punti disponibili. Lontano si vola radente, vicino al nemico si
## cerca la copertura a terra.
func _move_toward(eng: SSEngine, u: Dictionary, goal: int, a: int, foes: Array) -> Array:
	var h: int = u["h"]
	var d := Hex.dist(h, goal)
	var near_foe := 99
	for f in foes:
		near_foe = mini(near_foe, Hex.dist(h, f["h"]))
	var mv := []
	var alt: int = u["alt"]
	var left := float(a)
	var want_air: bool = d > 3 and (near_foe > 6 or eng.sit == "P" and u["side"] == 0)
	if u["kind"] == "pl":
		want_air = true
	if want_air and alt == 0:
		if left >= 4.0:
			mv.append("R")
			left -= 3.0
			alt = 1
	elif not want_air and alt == 1 and near_foe <= 6:
		pass
	elif alt == 2 and u["kind"] != "pl" and not want_air and left >= 4.0:
		mv.append("R")
		left -= 3.0
		alt = 1
	var path := _path(eng, h, goal, alt)
	var start_n := mv.size()
	for nh in path:
		var c := eng.move_cost(nh, alt)
		if c > left + 0.001:
			break
		mv.append(nh)
		left -= c
		h = nh
		if left < 0.5:
			break
	# non fermarsi dove ci sono già due compagni: un'esplosione o un laser li colpirebbe tutti
	while mv.size() > start_n + 1 and int(_ends.get(h, 0)) >= 2 and eng.sit != "B":
		var back = mv.pop_back()
		left += eng.move_cost(int(back), alt)
		h = int(mv[mv.size() - 1])
	if h > 0:
		_ends[h] = int(_ends.get(h, 0)) + 1
	# pattuglia: uscita dal bordo della base
	if eng.sit == "P" and u["side"] == 0 and h > 0 and Hex.on_edge(h, eng.base_edge):
		var c2 := 0.5 if alt > 0 else 1.0
		if left >= c2:
			mv.append(-1)
			left -= c2
	elif eng.sit == "B" and u["carry"] != "" and h > 0 and Hex.on_edge(h, "*"):
		var c3 := 0.5 if alt > 0 else 1.0
		if left >= c3:
			mv.append(-1)
			left -= c3
	# a fine movimento vicino al nemico, giù a terra (gratis dal volo radente)
	if alt == 1 and near_foe <= 8 and eng.sit != "P" and u["kind"] != "pl" and mv.size() > 0 and not mv.has(-1):
		mv.append("T")
	if mv.size() == 1 and mv[0] is String:
		return []
	return mv


## Percorso più economico (Dijkstra) da h a goal con la quota data; restituisce gli esagoni dopo h.
func _path(eng: SSEngine, h: int, goal: int, alt: int) -> Array:
	if h <= 0 or goal <= 0 or h == goal:
		return []
	var dist := {h: 0.0}
	var prev := {}
	var open := [[0.0, h]]
	var limit := Hex.dist(h, goal) + 12
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if open[i][0] < open[bi][0]:
				bi = i
		var cur = open[bi]
		open.remove_at(bi)
		var ch: int = cur[1]
		if ch == goal:
			break
		if cur[0] > dist.get(ch, 1e9):
			continue
		for n in Hex.neighbors(ch):
			if Hex.dist(n, goal) > limit:
				continue
			var c: float = cur[0] + eng.move_cost(n, alt) + 0.01
			if c < dist.get(n, 1e9):
				dist[n] = c
				prev[n] = ch
				open.append([c, n])
	if not prev.has(goal):
		return []
	var out := []
	var x := goal
	while x != h:
		out.push_front(x)
		x = prev[x]
	return out


func _orbital(eng: SSEngine, s: int, foes: Array) -> Array:
	var q: Dictionary = eng.sides[s]["orb"]
	if q.is_empty():
		return []
	var out := []
	var used: Dictionary = eng.orb_used[s]
	# laser sul nemico più esposto, bombardamento sui gruppi lontani dagli amici
	var sorted := foes.duplicate()
	var cnt := {}
	for f in foes:
		var k: int = f["h"] * 10 + f["alt"]
		cnt[k] = int(cnt.get(k, 0)) + 1
	sorted.sort_custom(func(a, b): return int(cnt[a["h"] * 10 + a["alt"]]) * 10 - eng.terrain_def(a) > int(cnt[b["h"] * 10 + b["alt"]]) * 10 - eng.terrain_def(b))
	var done := {}
	var nl := int(q.get("l", 0)) - int(used.get("l", 0))
	for f in sorted:
		if nl <= 0:
			break
		if eng.civs.size() > 0 and eng._civ_marker_at(f["h"]):
			continue
		if done.has(f["h"] * 10 + f["alt"]):
			continue
		done[f["h"] * 10 + f["alt"]] = true
		out.append({"t": "l", "h": f["h"], "alt": f["alt"]})
		nl -= 1
	var nb := int(q.get("b", 0)) - int(used.get("b", 0))
	for f in foes:
		if nb <= 0:
			break
		if f["alt"] == 2:
			continue
		var safe := true
		for o in eng.live(s, true):
			if Hex.dist(o["h"], f["h"]) <= 4:
				safe = false
		for c in eng.civs:
			if not c["dead"] and Hex.dist(c["h"], f["h"]) <= 2:
				safe = false
		if safe and (eng.stage == 1 or rng.randf() < 0.5):
			out.append({"t": "b", "h": f["h"]})
			nb -= 1
	return out


func _dink_target(eng: SSEngine, u: Dictionary) -> int:
	if eng.dink["wounds"] >= 1 and eng.stage == 2:
		return u["h"]
	# il gruppo di civili più lontano dai soldati
	var best: int = u["h"] if u["on"] else 0
	var bv := -999.0
	for c in eng.civs:
		if c["dead"]:
			continue
		var v := 0.0
		for sd in eng.live(1, true):
			var d := Hex.dist(sd["h"], c["h"])
			v += minf(float(d), 12.0)
			if d <= 1:
				v += 3.0
		v += rng.randf() * 2.0
		if v > bv:
			bv = v
			best = c["h"]
	if best <= 0:
		best = Hex.code(20, 27)
	return best
