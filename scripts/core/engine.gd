class_name SSEngine
extends Node
## Motore di StarSoldier (SPI, 1977): combattimento tattico individuale nel XXV secolo.
## Piani segreti e simultanei: in ogni Fase di piano entrambi i lati assegnano i compiti di ogni
## soldato (movimento, fuoco diretto, ristretto e d'opportunità, contromisure, lanci, ricerca, trasporto)
## spendendo punti di compito (TP). Poi il motore esegue tutto nell'ordine della Sequenza di gioco:
## fuoco, lanci, movimento con il fuoco d'opportunità e i missili cercatori, dispersione e detonazione
## delle armi lanciate, recupero.
## - Gioco base (4.0-13.0): un solo piano per turno, tabelle base, scenario del Primo contatto.
## - Gioco standard (14.0-40.5): turno diviso in due Stadi, comunicazioni di comando, livello di
##   preservazione, granate opacizzanti, missili cercatori, supporto orbitale, piattaforme di supporto,
##   androidi, Rame, Xenofobi, basi e civili; situazioni di Pattuglia, Ricognizione e Assalto.
## Tutto il caso passa da rng con il seme della partita: online ogni dispositivo esegue gli stessi
## piani nello stesso ordine e ottiene la stessa partita.

const D = preload("res://scripts/data/ss_data.gd")
const SC = preload("res://scripts/data/scenari.gd")

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(result: Dictionary)
signal fx(kind: String, data: Dictionary)

const ALT_NAME := ["a terra", "volo radente", "alta quota"]
const ALT_SHORT := ["T", "R", "A"]
const W_NAME := {"gpb": "bomba guidata a positroni", "ffm": "missili a volo libero", "og": "granata opacizzante", "hm": "missile cercatore", "nb": "bomba al neutrone"}

# ---------------------------------------------------------------- configurazione
var cfg := {}
var sc := {}
var sit := "P"                    # P, R, A (situazioni), B (gioco base), X (Xenofobi), D (Dinkblog), Z (Zulu)
var std := true                   # gioco standard (false = gioco base)
var players: Array = []           # [{name, ai, level}] per lato: 0 = Alpha, 1 = Bravo
var sides: Array = []
var ais: Array = []
var online = null
var ai_delay := 0.4
var anim := 1.0
var headless := false
var abort := false
var rng := RandomNumberGenerator.new()
var max_turns := 14
var urban_as := ""                # "o" o "." se le città valgono come altro terreno
var base_edge := "E"              # pattuglia: bordo oltre il quale c'è la base di Bravo
var entry_edge := ["O", "E"]      # bordo d'ingresso per lato

# ---------------------------------------------------------------- stato
var units := {}
var order: Array = []
var craters := {}                 # esagono -> true
var smoke := {}                   # esagono -> {k: "og"/"ob", turn, stage}
var missiles: Array = []          # missili cercatori: {id, side, h, active, target, mine, left}
var civs: Array = []              # civili
var lws: Array = []               # armi lanciate in volo in questo stadio
var orb_pending: Array = []       # bombardamenti e bombe opacizzanti orbitali in arrivo
var turn := 0
var stage := 1
var phase := ""
var over := false
var result := {}
var log_lines: Array = []
var history: Array = []
var plots := [{}, {}]             # piani dello stadio in corso
var orb_used := [{}, {}]          # supporto orbitale usato nel turno
var reinf := {"start": 0, "wave": 0}
var dink := {}                    # scenario 39
var rec_acts: Array = []
var preload_acts: Array = []
var pre_i := 0
var turn_hook = null
var mv_round := 0


# ================================================================ preparazione

func setup(c: Dictionary) -> void:
	cfg = c
	sc = SC.get_scn(int(c.get("scenario", 13)))
	sit = str(c.get("sit", sc["situazioni"][0]))
	if not sit in sc["situazioni"]:
		sit = sc["situazioni"][0]
	std = sit != "B"
	if c.has("seed"):
		rng.seed = int(c["seed"])
	else:
		rng.randomize()
	ai_delay = float(c.get("ai_delay", 0.4))
	anim = float(c.get("anim", 1.0))
	max_turns = int(c.get("max_turns", sc.get("turni", 14)))
	urban_as = str(sc.get("urbano", ""))
	Hex.wrap = sit == "Z"
	players = c.get("seats", []).duplicate(true)
	while players.size() < 2:
		players.append({"name": "", "ai": true, "level": 1})
	var m: Array = c.get("match", sc["scontri"][0])
	var fa: Dictionary = sc["fazioni"][int(m[0])]
	var fb: Dictionary = sc["fazioni"][int(m[1])]
	sides = [_side_from(fa, int(m[1]), 0), _side_from(fb, int(m[0]), 1)]
	if sc.get("identita", false):
		# 37.31-37.32: civili secondo il mondo di Bravo, supporto orbitale per l'attaccante
		var w := int(fb.get("mondo", 6))
		sc = sc.duplicate(true)
		sc["civili"] = w
		sides[0]["orb"] = SC.O_HALF.duplicate() if w in [6, 7] else SC.O_FULL.duplicate()
	for i in 2:
		ais.append(SSAI.new(int(players[i].get("level", 1))))
	_place_forces()


func _side_from(f: Dictionary, other: int, idx: int) -> Dictionary:
	var ped := str(f.get("pedine", f["razza"]))
	var pv: Dictionary = f.get("pedine_vs", {})
	if pv.has(str(other)):
		ped = str(pv[str(other)])
	var spec := {}
	if sit in ["P", "R", "A", "X", "Z"]:
		var arr: Array = f.get(sit, [])
		if not arr.is_empty():
			spec = arr[mini(idx, arr.size() - 1)]
	return {"nome": f["nome"], "razza": f["razza"], "pedine": ped, "spec": spec, "pl": int(spec.get("pl", 0)),
		"lost": 0, "pres": false, "pres_pending": false, "orb": f.get("orb", {}).duplicate(),
		"hm": str(f.get("hm", "si")), "ccp": 0, "pts": 0, "exited": 0, "killed": 0}


func pname(s: int) -> String:
	var p: String = str(players[s].get("name", ""))
	var role := "Alpha" if s == 0 else "Bravo"
	if sit == "B" or sit == "D":
		role = ""
	var base: String = sides[s]["nome"] + ("" if role == "" else " (" + role + ")")
	return base if p == "" else "%s – %s" % [p, base]


func side_short(s: int) -> String:
	return sides[s]["nome"]


func terrain(h: int) -> String:
	if craters.has(h):
		return "c"
	var t := D.terrain(h)
	if t == "u" and urban_as != "":
		return urban_as
	return t


func tv(h: int) -> int:
	return D.T_VALUE[terrain(h)]


func _stats(race: String, kind: String) -> Array:
	if not std:
		return D.BASIC[race].duplicate()
	if race == "d":
		return [0, 0, 0]
	var s: Array = D.STANDARD[race].duplicate()
	if kind == "an" or kind == "base":
		s[2] = 0
	if kind == "base":
		s[0] = 6
	return s


var _next_num := {}

func add_unit(side: int, kind: String, grp: int) -> Dictionary:
	var sd: Dictionary = sides[side]
	var ped: String = sd["pedine"]
	var race: String = sd["razza"]
	var num := 0
	var lab := ""
	if kind in ["ss", "hw", "an"]:
		var key := ped + kind
		var lst: Array = D.COUNTER_NUMS.get(ped, {}).get(kind, [])
		var k: int = _next_num.get(key, 0)
		_next_num[key] = k + 1
		num = lst[k] if k < lst.size() else (lst[0] if not lst.is_empty() else 100) + 50 + k
		lab = "%s %d" % [D.KIND_PREFIX[kind], num]
	elif kind == "pl":
		var k2: int = _next_num.get(ped + "pl", 0)
		_next_num[ped + "pl"] = k2 + 1
		num = {"h": 161, "l": 261, "r": 361}.get(ped, 161) + k2
		lab = "P %d" % num
	elif kind == "base":
		var k3: int = _next_num.get(str(side) + "base", 0)
		_next_num[str(side) + "base"] = k3 + 1
		num = k3 + 1
		lab = "Base %d" % num
	elif kind == "dink":
		lab = "Dinkblog"
	var st := _stats(race, kind)
	var id := "%d%s%s%d" % [side, ped, kind, num]
	var u := {"id": id, "side": side, "race": race, "ped": ped, "kind": kind, "num": num, "lab": lab, "grp": grp,
		"leader": false, "tpa0": st[0], "tpa": st[0], "eff": st[1], "rec": st[2], "h": 0, "alt": 0,
		"on": false, "dead": false, "exited": false, "hidden": false, "found": true, "entry": "",
		"stun": false, "hit": false, "spent": 0.0, "laser": kind == "pl", "halved": false, "wounds": 0,
		"carry": "", "reg": [], "ind": false, "cm_cur": 0, "mv_left": 0.0, "of_left": 0, "path_done": 0,
		"alt0": 0, "air_stage": false, "gnd_stage": false, "mv_tp": 0}
	if kind == "pl":
		u["alt"] = 2
	units[id] = u
	order.append(id)
	return u


func _org(side: int, spec: String) -> void:
	var race: String = sides[side]["razza"]
	var g := 0
	for tok in spec.split("+", false):
		g += 1
		var o: Dictionary = D.ORG.get(tok, {})
		var kinds: Array = o.get(race, o.get("h", []))
		if race == "x":
			kinds = D.ORG["S"]["x"]
		var first := true
		for k in kinds:
			var u := add_unit(side, k, side * 100 + g)
			# 16.23, 22.13: il primo StarSoldier organico del gruppo è il capo (i Rame non ne hanno)
			if first and k == "ss" and race != "r" and tok in ["FT", "S"]:
				u["leader"] = true
				first = false


func _place_forces() -> void:
	match sit:
		"B":
			# 13.2: Squadra L'Chal Dah (7, due armi pesanti) contro Squadra di fuoco umana (5, un'arma pesante)
			_org(0, "S")
			for k in ["ss", "ss", "ss", "ss", "hw"]:
				add_unit(1, k, 101)
			units[order[order.size() - 5]]["leader"] = true
			# rinforzi umani (13.48): altri cinque, fuori mappa
			for k in ["ss", "ss", "hw", "ss", "ss"]:
				var u := add_unit(1, k, 102)
				u["reinf"] = true
			for i in 10:
				civs.append({"id": "c%d" % i, "h": 0, "genuine": i < 3, "up": true, "dead": false, "carrier": "", "moved": false})
			var roll := _2d6()
			# l'ingresso secondo 13.2 (bordi della mappa originale: 39xx in alto = qui "N")
			var e: String = {2: "N", 6: "N", 7: "N", 8: "N", 12: "N", 4: "E", 5: "E", 3: "S", 11: "S", 9: "O", 10: "O"}.get(roll, "N")
			entry_edge = [e, ""]
			for id in order:
				if units[id]["side"] == 0:
					units[id]["entry"] = e
		"D":
			var d := add_unit(0, "dink", 1)
			d["tpa0"] = 1
			d["tpa"] = 1
			d["entry"] = "Q"
			dink = {"id": d["id"], "wounds": 0, "moved_turn": -1, "pts": [0, 0], "left": false}
			for k in ["ss", "ss", "ss"]:
				add_unit(1, k, 101)
			for i in 10:
				civs.append({"id": "c%d" % i, "h": 0, "genuine": true, "up": false, "dead": false, "carrier": "", "moved": false})
		_:
			for s in 2:
				var spec: Dictionary = sides[s]["spec"]
				_org(s, str(spec.get("u", "S")))
				for b in int(spec.get("basi", 0)) if s == 1 else 0:
					var bu := add_unit(1, "base", 199)
					bu["found"] = false
				for m in int(spec.get("mine", 0)) if s == 1 else 0:
					missiles.append({"id": "m%d" % missiles.size(), "side": 1, "h": 0, "active": false, "target": "", "mine": true, "left": 12, "dead": false})
			var nciv := int(sc.get("civili", 0))
			for i in nciv:
				civs.append({"id": "c%d" % i, "h": 0, "genuine": true, "up": false, "dead": false, "carrier": "", "moved": false})
			if sit == "P":
				base_edge = "E" if rng.randi_range(0, 1) == 0 else "O"
				entry_edge = ["O" if base_edge == "E" else "E", base_edge]
			elif sit in ["R", "A"]:
				entry_edge = ["O", ""]
			elif sit == "X":
				entry_edge = ["O", "E"]
			for id in order:
				var u: Dictionary = units[id]
				if u["kind"] == "base":
					continue
				u["entry"] = entry_edge[u["side"]]
	if sit == "Z":
		for id in order:
			units[id]["entry"] = ""


# ================================================================ utilità

func alive(u: Dictionary) -> bool:
	return not u["dead"] and not u["exited"]


func live(side := -1, on_map := false) -> Array:
	var out := []
	for id in order:
		var u: Dictionary = units[id]
		if not alive(u):
			continue
		if side >= 0 and u["side"] != side:
			continue
		if on_map and not u["on"]:
			continue
		out.append(u)
	return out


func soldiers(side: int) -> Array:
	var out := []
	for u in live(side):
		if u["kind"] in ["ss", "hw", "an", "pl", "dink"]:
			out.append(u)
	return out


func units_at(h: int, alt := -1) -> Array:
	var out := []
	for id in order:
		var u: Dictionary = units[id]
		if alive(u) and u["on"] and u["h"] == h and (alt < 0 or u["alt"] == alt):
			out.append(u)
	return out


## l'unità è nota al lato s (le proprie sempre; quelle nemiche se non sono schierate in segreto)
func visible_to(u: Dictionary, s: int) -> bool:
	if s < 0 or u["side"] == s:
		return true
	if u["kind"] == "base":
		return u["found"]
	return not u["hidden"]


func _2d6() -> int:
	return rng.randi_range(1, 6) + rng.randi_range(1, 6)


func _d6() -> int:
	return rng.randi_range(1, 6)


func log_msg(t: String) -> void:
	log_lines.append(t)
	log_added.emit(t)


func _pace(sec: float) -> void:
	if headless or anim <= 0.0 or abort or not is_inside_tree():
		return
	if online != null and online.catchup:
		return
	if replaying():
		return
	await get_tree().create_timer(sec / anim).timeout


func eff(u: Dictionary) -> float:
	var e := float(u["eff"])
	if u["side"] < sides.size() and sides[u["side"]]["pres"]:
		e *= 0.5
	return e


func avail(u: Dictionary) -> int:
	if not std:
		return int(u["tpa"])
	var a := int(u["tpa"]) - int(floor(u["spent"] + 0.001)) if stage == 2 else int(u["tpa"])
	return clampi(a, 0, 6)


func range_att(a_h: int, a_alt: int, t_h: int, t_alt: int) -> int:
	if sit == "Z":
		return 0
	var d := Hex.dist(a_h, t_h)
	if d == 0:
		return 0
	if (a_alt == 2) != (t_alt == 2):
		d += 5
	return int(ceil(float(d) / 10.0))


## valore difensivo del terreno contro il fuoco (9.62)
func terrain_def(u: Dictionary) -> int:
	if u["kind"] in ["pl", "base"]:
		return 10
	if u["alt"] == 2:
		return 1
	var t := terrain(u["h"])
	var v: int = D.T_VALUE[t]
	if t in ["c", "l"] and u["alt"] != 0:
		v = 1
	var sm: Dictionary = smoke.get(u["h"], {})
	if not sm.is_empty():
		v += 6 if sm["k"] == "ob" else 2
	return v


## contromisure di un bersaglio (9.62, 8.23, 23.11, 23.2)
func cm_value(u: Dictionary) -> float:
	var total := 0.0
	var group := [u]
	if u["race"] == "r" and u["kind"] != "an":
		group = []
		for o in units_at(u["h"], u["alt"]):
			if o["side"] == u["side"] and o["race"] == "r" and o["kind"] != "an":
				group.append(o)
	for o in group:
		var e := eff(o)
		if o["race"] == "r":
			if o["gnd_stage"]:
				e *= 0.5
		elif o["air_stage"]:
			e *= 0.5
		total += e * float(o["cm_cur"])
	return total


func defense(u: Dictionary, a_h: int, a_alt: int, ignore_cm := false) -> float:
	var d := float(range_att(a_h, a_alt, u["h"], u["alt"])) + float(u["mv_tp"]) + float(terrain_def(u))
	if not ignore_cm:
		d += cm_value(u)
	return d


func move_cost(h: int, alt: int) -> float:
	var c := 0.5 if alt > 0 else float(tv(h))
	var sm: Dictionary = smoke.get(h, {})
	if not sm.is_empty():
		c += 6.0 if sm["k"] == "ob" else 2.0
	return c


const ALT_COST := [[0, 3, 6], [0, 0, 3], [3, 3, 0]]


## Simula un movimento: restituisce {cost, h, alt, steps: [{h, alt, cost}], ok, err, air, gnd}
func sim_path(u: Dictionary, steps: Array, alt0 := -1) -> Dictionary:
	var h: int = u["h"]
	var alt: int = u["alt"] if alt0 < 0 else alt0
	var on: bool = u["on"]
	var cost := 0.0
	var out := []
	var air := alt > 0
	var gnd := alt == 0
	for s in steps:
		var c := 0.0
		if s is String:
			var na := ALT_SHORT.find(s)
			if na < 0 or na == alt or u["kind"] == "pl":
				return {"cost": cost, "h": h, "alt": alt, "steps": out, "ok": false, "err": "cambio di quota non valido", "air": air, "gnd": gnd}
			c = float(ALT_COST[alt][na])
			alt = na
			if alt > 0:
				air = true
			else:
				gnd = true
		else:
			var to := int(s)
			if to == -1:
				# uscita dalla mappa dal bordo dove si trova
				if not on or not Hex.on_edge(h, "*"):
					return {"cost": cost, "h": h, "alt": alt, "steps": out, "ok": false, "err": "si esce solo da un esagono del bordo", "air": air, "gnd": gnd}
				c = 0.5 if alt > 0 else 1.0
				h = -1
				on = false
			elif not on:
				if not Hex.valid(to) or not _entry_ok(u, to):
					return {"cost": cost, "h": h, "alt": alt, "steps": out, "ok": false, "err": "ingresso fuori dal bordo previsto", "air": air, "gnd": gnd}
				c = move_cost(to, alt)
				h = to
				on = true
			else:
				if h < 0 or Hex.dist(h, to) != 1:
					return {"cost": cost, "h": h, "alt": alt, "steps": out, "ok": false, "err": "esagono non adiacente", "air": air, "gnd": gnd}
				c = move_cost(to, alt)
				h = to
		cost += c
		out.append({"h": h, "alt": alt, "cost": c})
	return {"cost": cost, "h": h, "alt": alt, "steps": out, "ok": true, "err": "", "air": air, "gnd": gnd}


func _entry_ok(u: Dictionary, h: int) -> bool:
	var e: String = u.get("entry", "")
	if e == "" or e == "*":
		return Hex.on_edge(h, "*")
	if e == "Q":
		return true
	return Hex.on_edge(h, e)


## Linea di fuoco (9.1, 12.4, 12.5, 18.21, 40.53). restricted: fuoco ristretto (può passare fra amici).
func lof(side: int, a_h: int, a_alt: int, t_h: int, t_alt: int, restricted := false, shooter_id := "") -> bool:
	if a_h <= 0 or t_h <= 0:
		return false
	var d := Hex.dist(a_h, t_h)
	if sit == "Z":
		var lim := 5
		if a_alt == 2 and t_alt == 2:
			lim = 20
		elif a_alt == 2 or t_alt == 2:
			lim = 10
		if d > lim:
			return false
	# amici nell'esagono bersaglio
	if not restricted:
		for o in units_at(t_h):
			if o["side"] == side and o["id"] != shooter_id and o["kind"] != "base":
				return false
	# crateri e laghi a terra (12.43, 12.5)
	for pair in [[a_h, a_alt, t_h, t_alt], [t_h, t_alt, a_h, a_alt]]:
		var t := terrain(pair[0])
		if pair[1] == 0 and t == "c":
			if not (pair[3] > 0 and Hex.dist(pair[0], pair[2]) <= 1):
				return false
		if pair[1] == 0 and t == "l":
			if not (pair[3] > 0 and Hex.dist(pair[0], pair[2]) <= 1):
				# attraverso i lati di lago
				if pair[3] == 0 and terrain(pair[2]) != "l":
					return false
				var all_lake := true
				for hh in Hex.lines(pair[0], pair[2])[0]:
					if terrain(hh) != "l":
						all_lake = false
				if not all_lake:
					return false
	if d <= 1:
		return true
	for path in Hex.lines(a_h, t_h):
		var ok := true
		for hh in path:
			if smoke.has(hh):
				ok = false
				break
			if a_alt < 2 and t_alt < 2:
				var t := terrain(hh)
				if a_alt == 0 and t in ["o", "m", "u"]:
					ok = false
					break
				if a_alt == 1 and t in ["m", "u"]:
					ok = false
					break
			if not restricted:
				var blocked := false
				for o in units_at(hh):
					if o["side"] == side and o["kind"] != "base":
						blocked = true
				if blocked:
					ok = false
					break
		if ok:
			return true
	return false


## Raggio d'esplosione (10.3): {esagono: anello 0/1/2}. In alta quota il terreno non conta.
func blast(h: int, high: bool) -> Dictionary:
	var out := {h: 0}
	for n in Hex.neighbors(h):
		var c1 := 1 if high else tv(n)
		if c1 <= 2:
			out[n] = 1
			if c1 == 1:
				for n2 in Hex.neighbors(n):
					if out.has(n2):
						continue
					var c2 := 1 if high else tv(n2)
					if c1 + c2 <= 2:
						out[n2] = 2
	if high:
		for n in Hex.ring(h, 2):
			if not out.has(n):
				out[n] = 2
	return out


# ================================================================ decisioni

func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	req["turn"] = turn
	req["stage"] = stage
	if abort:
		return ais[seat].decide(self, seat, req)
	if online != null:
		changed.emit()
		var r0 = await online.decide(self, seat, req)
		rec_acts.append(r0)
		return r0
	if pre_i < preload_acts.size():
		var rp = preload_acts[pre_i]
		pre_i += 1
		rec_acts.append(rp)
		return rp
	changed.emit()
	var r = null
	if players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay * 0.5).timeout
		r = ais[seat].decide(self, seat, req)
	else:
		decision_requested.emit(req)
		r = await decision_provided
		if r == null:
			r = ais[seat].decide(self, seat, req)
	rec_acts.append(r)
	return r


func replaying() -> bool:
	return pre_i < preload_acts.size()


func decide_all(seats: Array, reqs: Array) -> Array:
	for i in seats.size():
		reqs[i]["seat"] = seats[i]
		reqs[i]["turn"] = turn
		reqs[i]["stage"] = stage
	if online != null and not abort:
		var rr = await online.decide_all(self, seats, reqs)
		for r in rr:
			rec_acts.append(r)
		return rr
	var out := []
	for i in seats.size():
		var r = await decide(seats[i], reqs[i])
		out.append(r)
	return out


func provide_decision(r) -> void:
	decision_provided.emit(r)


func humans() -> int:
	var n := 0
	for p in players:
		if not p["ai"]:
			n += 1
	return n


# ================================================================ registrazione

func snapshot() -> Dictionary:
	var us := {}
	for id in order:
		var u: Dictionary = units[id]
		us[id] = [u["h"] if u["on"] else 0, u["alt"], u["tpa"], 1 if u["dead"] else 0, 1 if u["hidden"] else 0, 1 if u["found"] else 0, 1 if u["exited"] else 0]
	var cv := []
	for c in civs:
		cv.append([c["h"], 1 if c["dead"] else 0, 1 if c["up"] else 0, 1 if c["genuine"] else 0])
	var ms := []
	for m in missiles:
		ms.append([m["h"], 1 if m["active"] else 0, 1 if m["dead"] else 0, m["side"], 1 if m["mine"] else 0])
	return {"u": us, "c": cv, "m": ms, "cr": craters.keys(), "sm": smoke.duplicate(true)}


func _rec(seg: Dictionary) -> void:
	seg["s"] = snapshot()
	seg["turn"] = turn
	seg["stage"] = stage
	seg["phase"] = phase
	history.append(seg)
	fx.emit(seg["k"], seg)


## Un effetto per la vista: si registra anche nella storia della partita (per il replay)
func _emit(kind: String, d: Dictionary) -> void:
	d["k"] = kind
	_rec(d)


func fingerprint() -> String:
	return "%d|%d|%s" % [turn, log_lines.size(), str(hash(var_to_str(snapshot()) + str(result)))]


# ================================================================ partita

func run() -> void:
	phase = "schieramento"
	var sname: String = sc["nome"]
	if sit in SC.SIT_NAME:
		sname += " – " + SC.SIT_NAME[sit]
	log_msg("%s (%d d.C.), %s." % [sname, sc["anno"], "gioco base" if not std else "gioco standard"])
	if sit == "P":
		log_msg("La base di Bravo è oltre il bordo %s." % ("Est" if base_edge == "E" else "Ovest"))
	if sit == "B":
		log_msg("I L'Chal Dah entreranno dal bordo %s." % _edge_name(entry_edge[0]))
	await _deploy()
	if abort:
		return
	_rec({"k": "start"})
	turn = 0
	while not over and not abort:
		turn += 1
		log_msg("— Turno %d —" % turn)
		_turn_start()
		var nst := 2 if std else 1
		for st in range(1, nst + 1):
			stage = st
			await _stage()
			if over or abort:
				break
		if over or abort:
			break
		_end_turn()
		if turn_hook != null:
			turn_hook.call(self)
		if not over and turn >= max_turns:
			_time_up()
	if abort:
		return
	_finish()


func _edge_name(e: String) -> String:
	return {"O": "Ovest", "E": "Est", "N": "Nord", "S": "Sud", "*": "qualsiasi"}.get(e, e)


func _finish() -> void:
	phase = "fine"
	_rec({"k": "end"})
	changed.emit()
	game_ended.emit(result)


func _win(w: int, reason: String, level := "") -> void:
	if over:
		return
	over = true
	result = {"winner": w, "reason": reason, "turn": turn, "level": level}
	log_msg(("Vince %s%s: " % [side_short(w), (" (" + level + ")") if level != "" else ""] if w >= 0 else "Partita pari: ") + reason)


func _turn_start() -> void:
	orb_used = [{}, {}]
	for s in 2:
		if sides[s]["pres_pending"] and not sides[s]["pres"]:
			sides[s]["pres"] = true
			log_msg("%s ha superato il livello di preservazione: efficienza dimezzata." % side_short(s))
	for id in order:
		units[id]["spent"] = 0.0
	# 20.34 dispersione delle bombe opacizzanti orbitali
	for h in smoke.keys():
		if smoke[h]["k"] == "ob":
			if _d6() <= 2:
				smoke.erase(h)
				log_msg("Il fumo denso in %s si disperde." % Hex.label(h))
	# 13.48 rinforzi umani nel gioco base
	if sit == "B" and turn >= 2:
		if reinf["start"] == 0:
			var d := _d6()
			if d <= turn:
				reinf["start"] = turn
				log_msg("Arrivano i rinforzi umani (tiro %d)." % d)
		if reinf["start"] > 0:
			var k: int = turn - reinf["start"]
			var n := 1 if k == 0 else (2 if k == 1 else (1 if k <= 3 else 0))
			for id in order:
				var u: Dictionary = units[id]
				if n <= 0:
					break
				if u.get("reinf", false) and u["entry"] == "":
					u["entry"] = "*"
					n -= 1
					log_msg("%s può entrare da un bordo qualsiasi." % u["lab"])
	# il Dinkblog si muove una volta per stadio (una per turno se ferito)
	_rec({"k": "turn"})


func _end_turn() -> void:
	for h in smoke.keys():
		var sm: Dictionary = smoke[h]
		if sm["k"] == "og" and turn > int(sm["turn"]) and stage >= int(sm["stage"]):
			pass
	_check_victory(true)


func _time_up() -> void:
	match sit:
		"B":
			_win(1, "nessun civile portato fuori dalla mappa entro il turno %d." % turn, "sostanziale" if not _human_killed_civ() else "marginale")
		"P":
			_patrol_end("limite di turni")
		"R":
			_win(1, "le basi non sono state scoperte entro il turno %d." % turn)
		"A":
			_win(1, "le basi resistono fino al turno %d." % turn)
		"X":
			var r := [0.0, 0.0]
			for s in 2:
				var tot := 0.0
				var tot0 := 0.0
				for u in units.values():
					if u["side"] == s and u["kind"] != "base":
						tot0 += u["tpa0"]
						if alive(u):
							tot += u["tpa"]
				r[s] = tot / maxf(tot0, 1.0)
			if absf(r[0] - r[1]) < 0.05:
				_win(-1, "nessuno ha eliminato l'avversario.")
			else:
				_win(0 if r[0] > r[1] else 1, "ha più forze intatte alla fine dei combattimenti.")
		"D":
			_dink_end("il tempo è scaduto")
		"Z":
			var f0 := float(sides[0]["lost"]) / maxf(float(sides[0]["pl"]), 1.0)
			var f1 := float(sides[1]["lost"]) / maxf(float(sides[1]["pl"]), 1.0)
			if absf(f0 - f1) < 0.01:
				_win(-1, "nessuno ha spinto l'avversario oltre il livello di preservazione.")
			else:
				_win(0 if f1 > f0 else 1, "ha avvicinato di più l'avversario al livello di preservazione.")


# ================================================================ schieramento

func _deploy() -> void:
	var reqs := [{}, {}]
	var seats := []
	for s in 2:
		var r := _deploy_req(s)
		if not r.is_empty():
			reqs[s] = r
			seats.append(s)
	if seats.is_empty():
		return
	var rr := []
	var rq := []
	for s in seats:
		rq.append(reqs[s])
	rr = await decide_all(seats, rq)
	for i in seats.size():
		_apply_deploy(seats[i], rr[i] if rr[i] is Dictionary else {}, reqs[seats[i]])
	# 27.32 assalto dall'orbita: bombardamento preparatorio
	if sit == "A" and not sides[0]["orb"].is_empty():
		await _pre_assault(rr[seats.find(0)] if seats.has(0) else {})
	_rec({"k": "deploy"})


## Richiesta di schieramento per un lato, oppure {} se non deve schierare nulla.
func _deploy_req(s: int) -> Dictionary:
	var r := {"k": "schiera", "units": [], "zone": "", "civ": 0, "gen": 0, "basi": 0, "mine": 0, "alt": 0}
	var ids := []
	for id in order:
		var u: Dictionary = units[id]
		if u["side"] != s:
			continue
		if sit == "B" and s == 1 and not u.get("reinf", false):
			ids.append(id)
		elif sit in ["R", "A"] and s == 1:
			ids.append(id)
		elif sit == "D" and s == 1:
			ids.append(id)
		elif sit == "Z":
			ids.append(id)
		elif sit == "A" and s == 0 and not sides[0]["orb"].is_empty():
			ids.append(id)
	r["units"] = ids
	if sit == "B" and s == 1:
		r["civ"] = 10
		r["gen"] = 3
		r["zone"] = "mappa"
	elif sit in ["R", "A"] and s == 1:
		r["zone"] = "est"
		r["basi"] = int(sides[1]["spec"].get("basi", 0))
		r["contigue"] = bool(sides[1]["spec"].get("contigue", false))
		r["mine"] = int(sides[1]["spec"].get("mine", 0))
	elif sit == "A" and s == 0:
		r["zone"] = "mappa"
		r["alt"] = 2
		r["orb_pre"] = {"b": 10, "o": 3}
	elif sit == "D" and s == 1:
		r["civ"] = 10
		r["zone"] = "mappa"
		r["dist_civ"] = 6
	elif sit == "Z":
		r["zone"] = "mappa"
		r["alt"] = 2 if s == 0 else 0
	# civili del gioco standard: schierati a turno da Bravo e Alpha (30.31); qui li schiera Bravo per entrambi
	if std and sit in ["P", "R", "A"] and s == 1 and civs.size() > 0:
		r["civ"] = civs.size()
		r["dist_civ"] = 2
	if ids.is_empty() and r["civ"] == 0 and r["basi"] == 0 and r["mine"] == 0:
		return {}
	return r


func deploy_zone_ok(s: int, h: int, req: Dictionary) -> bool:
	if not Hex.valid(h):
		return false
	match str(req.get("zone", "")):
		"est":
			# Bravo si schiera ad almeno dieci esagoni dal bordo d'ingresso di Alpha
			return Hex.col(h) >= 11
	return true


func _apply_deploy(s: int, r: Dictionary, req: Dictionary) -> void:
	var pos: Dictionary = r.get("pos", {})
	var fallback: Dictionary = ais[s].auto_deploy(self, s, req)
	var fpos: Dictionary = fallback.get("pos", {})
	for id in req.get("units", []):
		var u: Dictionary = units[id]
		var h := int(pos.get(id, fpos.get(id, 0)))
		if not deploy_zone_ok(s, h, req) or (u["kind"] != "base" and false):
			h = int(fpos.get(id, 0))
		if u["kind"] == "base" and not Hex.valid(h):
			h = int(fpos.get(id, 0))
		u["h"] = h
		u["on"] = Hex.valid(h)
		u["alt"] = 2 if u["kind"] == "pl" else int(req.get("alt", 0))
		if sit in ["R", "A"] and s == 1 and u["kind"] != "pl":
			u["hidden"] = true
		if u["kind"] == "base":
			u["found"] = false
			u["hidden"] = true
		u["entry"] = ""
	# civili
	var ch: Array = r.get("civ", fallback.get("civ", []))
	if ch.size() != civs.size():
		ch = fallback.get("civ", [])
	var gen: Array = r.get("gen", fallback.get("gen", []))
	if sit == "B" and civ_error(ch, gen) != "":
		ch = fallback.get("civ", [])
		gen = fallback.get("gen", [])
	for i in civs.size():
		if i < ch.size():
			civs[i]["h"] = int(ch[i])
		if sit == "B" and gen.size() == civs.size():
			civs[i]["genuine"] = bool(gen[i])
	if sit == "B":
		var ng := 0
		for c in civs:
			if c["genuine"]:
				ng += 1
		if ng != 3:
			for i in civs.size():
				civs[i]["genuine"] = i < 3
	# mine
	var mh: Array = r.get("mine", fallback.get("mine", []))
	var k := 0
	for m in missiles:
		if m["side"] == s and m["mine"]:
			var hh := int(mh[k]) if k < mh.size() else 0
			if not Hex.valid(hh) and k < fallback.get("mine", []).size():
				hh = int(fallback["mine"][k])
			m["h"] = hh
			k += 1
	if sit == "B" and s == 1:
		log_msg("Gli umani schierano la Squadra di fuoco e dieci segnalini di civili.")
	elif sit in ["R", "A"] and s == 1:
		log_msg("%s si schiera in segreto." % side_short(1))


## 13.2: controlla lo schieramento dei civili del gioco base; "" se va bene
func civ_error(ch: Array, gen: Array) -> String:
	if ch.size() != 10 or gen.size() != 10:
		return "servono dieci segnalini"
	var ng := 0
	var seen := {}
	for i in ch.size():
		var h := int(ch[i])
		if D.terrain(h) != "u":
			return "il segnalino %d non è in città" % (i + 1)
		if seen.has(h):
			return "due segnalini nello stesso esagono (%s)" % Hex.label(h)
		seen[h] = true
		if gen[i]:
			ng += 1
	if ng != 3:
		return "i civili veri devono essere tre"
	for g in SSAI.urban_groups():
		var n := 0
		var v := 0
		for i in ch.size():
			if g.has(int(ch[i])):
				n += 1
				if gen[i]:
					v += 1
		if n > 3:
			return "più di tre segnalini nello stesso gruppo di città"
		if v > 2:
			return "più di due civili veri nello stesso gruppo di città"
	return ""


func _pre_assault(r: Dictionary) -> void:
	var orb: Dictionary = r.get("orb", {})
	var fb: Dictionary = ais[0].auto_deploy(self, 0, _deploy_req(0)).get("orb", {})
	var bombs: Array = orb.get("b", fb.get("b", []))
	var opac: Array = orb.get("o", fb.get("o", []))
	log_msg("Bombardamento orbitale preparatorio: %d esplosivi e %d bombe opacizzanti." % [mini(bombs.size(), 10), mini(opac.size(), 3)])
	phase = "orbitale"
	for i in mini(bombs.size(), 10):
		orb_pending.append({"t": "b", "h": int(bombs[i]), "side": 0})
	for i in mini(opac.size(), 3):
		orb_pending.append({"t": "o", "h": int(opac[i]), "side": 0})
	await _orbital_detonations()
	# 27.32: dopo il bombardamento le forze di Bravo (non le basi) sono schierate allo scoperto
	for u in live(1):
		if u["kind"] != "base":
			u["hidden"] = false
	log_msg("Le forze di Bravo sono allo scoperto; Alpha scende in alta quota.")


# ================================================================ lo stadio

func _stage() -> void:
	for id in order:
		var u: Dictionary = units[id]
		u["hit"] = false
		u["stun"] = false
		u["cm_cur"] = 0
		u["mv_tp"] = 0
		u["air_stage"] = u["alt"] > 0
		u["gnd_stage"] = u["alt"] == 0
		u["of_left"] = 0
	lws = []
	# comunicazioni di comando
	phase = "comando"
	if std:
		_command()
	# piano
	phase = "piano"
	var who := []
	var reqs := []
	for s in 2:
		if _has_tasks(s):
			who.append(s)
			reqs.append({"k": "piano"})
	plots = [{}, {}]
	var rr: Array = await decide_all(who, reqs)
	if abort:
		return
	for i in who.size():
		plots[who[i]] = clean_plot(who[i], rr[i] if rr[i] is Dictionary else {})
	_reveal_spenders()
	_rec({"k": "plotted"})
	log_msg("Stadio %d: piani pronti." % stage if std else "Piani pronti.")
	# esecuzione
	phase = "fuoco"
	await _execution()
	if over or abort:
		return
	phase = "movimento"
	await _movement()
	if over or abort:
		return
	phase = "detonazione"
	await _projectiles()
	if over or abort:
		return
	_dinkblog_attack()
	phase = "recupero"
	_recovery()
	_expire_smoke()
	_rec({"k": "stage_end"})
	_check_victory(false)


func _has_tasks(s: int) -> bool:
	for u in live(s):
		if u["kind"] == "base" and sit == "R":
			continue
		if u["on"] or u["entry"] != "":
			return true
	return false


func _command() -> void:
	for s in 2:
		var leaders := []
		for u in live(s):
			if u["leader"] and u["on"]:
				leaders.append(u)
		for u in live(s):
			u["ind"] = false
			if u["leader"] or u["race"] in ["r", "d"] or u["kind"] in ["pl", "base"] or not u["on"]:
				continue
			var ok := false
			for l in leaders:
				var need := tv(u["h"]) + int(ceil(float(Hex.dist(u["h"], l["h"])) / 5.0))
				if need <= int(u["tpa"]):
					ok = true
					break
			u["ind"] = not ok


## Ripulisce un piano: toglie i compiti impossibili e quelli oltre i punti disponibili.
func clean_plot(s: int, p: Dictionary) -> Dictionary:
	var out := {"u": {}, "orb": []}
	var pu: Dictionary = p.get("u", {})
	for id in pu:
		if not units.has(id):
			continue
		var u: Dictionary = units[id]
		if u["side"] != s or not alive(u):
			continue
		if not u["on"] and u["entry"] == "":
			continue
		var t = pu[id]
		if not (t is Dictionary):
			continue
		var c := clean_tasks(u, t)
		if not c.is_empty():
			out["u"][id] = c
	# supporto orbitale (20.0)
	var quota: Dictionary = sides[s]["orb"]
	var used: Dictionary = orb_used[s]
	for o in p.get("orb", []):
		if not (o is Dictionary):
			continue
		var t := str(o.get("t", ""))
		var h := int(o.get("h", 0))
		if not t in ["b", "l", "o"] or not Hex.valid(h):
			continue
		if int(used.get(t, 0)) >= int(quota.get(t, 0)):
			continue
		used[t] = int(used.get(t, 0)) + 1
		out["orb"].append({"t": t, "h": h, "alt": clampi(int(o.get("alt", 0)), 0, 2)})
	return out


func task_cost(u: Dictionary, t: Dictionary) -> float:
	var c := 0.0
	var mv: Array = t.get("mv", [])
	if not mv.is_empty():
		c += sim_path(u, mv, int(t.get("alt0", -1)) if not u["on"] else -1)["cost"]
	c += float(t.get("cm", 0)) + float(t.get("of", 0))
	for f in t.get("df", []):
		c += float(f.get("tp", 0))
	for f in t.get("rf", []):
		c += float(f.get("tp", 0))
	for l in t.get("ln", []):
		c += float(l.get("tp", 0))
	if t.get("se", false):
		c += 1.0
	if str(t.get("tr", "")) != "":
		c += 3.0
	return c


func clean_tasks(u: Dictionary, t: Dictionary) -> Dictionary:
	var a := float(avail(u))
	var out := {}
	if u["kind"] == "dink":
		var to := int(t.get("tele", 0))
		if to == -1 or Hex.valid(to):
			out["tele"] = to
		return out
	if u["kind"] == "base":
		pass
	var entering: bool = not u["on"]
	# movimento
	var mv: Array = []
	for s0 in t.get("mv", []):
		mv.append(s0 if s0 is String else int(s0))
	if u["kind"] == "base":
		mv = []
	if entering:
		out["alt0"] = 2 if u["kind"] == "pl" else clampi(int(t.get("alt0", 1)), 0, 2)
	if not mv.is_empty():
		var sp := sim_path(u, mv, out.get("alt0", -1))
		var keep: int = sp["steps"].size()
		if not sp["ok"]:
			mv = mv.slice(0, keep)
			sp = sim_path(u, mv, out.get("alt0", -1))
		while not mv.is_empty() and sp["cost"] > a + 0.001:
			mv.pop_back()
			sp = sim_path(u, mv, out.get("alt0", -1))
		if not mv.is_empty():
			out["mv"] = mv
			a -= sp["cost"]
	if entering:
		# 27.14: nello stadio d'ingresso solo movimento e contromisure
		var cm0 := clampi(int(t.get("cm", 0)), 0, int(floor(a)))
		if cm0 > 0:
			out["cm"] = cm0
		return out if out.has("mv") else {}
	var cm := clampi(int(t.get("cm", 0)), 0, int(floor(a)))
	if cm > 0:
		out["cm"] = cm
		a -= cm
	# fuoco diretto
	var df := []
	var targets_seen := {}
	for f in t.get("df", []):
		var h := int(f.get("h", 0))
		var alt := clampi(int(f.get("alt", 0)), 0, 2)
		var tp := clampi(int(f.get("tp", 0)), 0, int(floor(a)))
		if tp <= 0 or not Hex.valid(h) or targets_seen.has(h * 10 + alt):
			continue
		if not lof(u["side"], u["h"], u["alt"], h, alt, false, u["id"]):
			continue
		if sit == "B" and _civ_marker_at(h) and alt <= 1:
			continue
		targets_seen[h * 10 + alt] = true
		df.append({"h": h, "alt": alt, "tp": tp})
		a -= tp
	if not df.is_empty():
		out["df"] = df
	# fuoco ristretto (non per le armi pesanti, 9.5)
	var rf := []
	if u["kind"] != "hw":
		for f in t.get("rf", []):
			var tid := str(f.get("u", ""))
			var tp := clampi(int(f.get("tp", 0)), 0, int(floor(a)))
			if tp <= 0 or not units.has(tid) or targets_seen.has(tid):
				continue
			var tu: Dictionary = units[tid]
			if not alive(tu) or not tu["on"] or tu["side"] == u["side"]:
				continue
			if not lof(u["side"], u["h"], u["alt"], tu["h"], tu["alt"], true, u["id"]):
				continue
			targets_seen[tid] = true
			rf.append({"u": tid, "tp": tp})
			a -= tp
	if not rf.is_empty():
		out["rf"] = rf
	# fuoco d'opportunità: solo per chi non si muove (9.21)
	if not out.has("mv"):
		var of := clampi(int(t.get("of", 0)), 0, int(floor(a)))
		if of > 0:
			out["of"] = of
			out["ofs"] = clampi(int(t.get("ofs", of)), 1, of)
			a -= of
	# lanci
	var ln := []
	for l in t.get("ln", []):
		var w := str(l.get("w", ""))
		var h := int(l.get("h", 0))
		var tp := int(l.get("tp", 3))
		if not Hex.valid(h) or not _weapon_ok(u, w):
			continue
		var d := Hex.dist(u["h"], h)
		if w in ["ffm", "og"]:
			tp = 3
			if d > 10:
				continue
		elif w == "hm":
			tp = maxi(tp, int(ceil(float(d) / 5.0)))
			tp = maxi(tp, 3)
			if d < 15:
				continue
		else:
			tp = maxi(tp, 3)
		if tp > int(floor(a)):
			continue
		if sit == "B" and u["side"] == 1 and _civ_marker_at(h) and not _genuine_taken_by_enemy(h):
			continue
		ln.append({"w": w, "h": h, "tp": tp, "hi": bool(l.get("hi", false)) and w in ["gpb", "nb", "ffm"]})
		a -= tp
	if not ln.is_empty():
		out["ln"] = ln
	# ricerca e trasporto (13.43, 13.44)
	if t.get("se", false) and a >= 1.0 and u["side"] == 0 and sit == "B" and not out.has("mv"):
		out["se"] = true
		a -= 1.0
	var tr := str(t.get("tr", ""))
	if tr != "" and a >= 3.0 and sit == "B":
		var cv := _civ(tr)
		if not cv.is_empty() and not cv["dead"] and not cv["up"] and cv["h"] == u["h"] and cv["genuine"]:
			out["tr"] = tr
			a -= 3.0
	# cannone laser delle piattaforme (21.22-21.25): zero punti
	if u["kind"] == "pl" and u["laser"]:
		var lc: Dictionary = t.get("lc", {})
		var h := int(lc.get("h", 0))
		if Hex.valid(h):
			out["lc"] = {"h": h, "alt": clampi(int(lc.get("alt", 0)), 0, 2), "reg": bool(lc.get("reg", false))}
	return out


func _weapon_ok(u: Dictionary, w: String) -> bool:
	if u["kind"] == "dink":
		return false
	if u["race"] == "x":
		return w == "nb"
	if w == "nb":
		return false
	if not std:
		return w in ["gpb", "ffm"]
	if w == "hm":
		return sides[u["side"]]["hm"] == "si"
	return w in ["gpb", "ffm", "og"]


func weapons(u: Dictionary) -> Array:
	var out := []
	for w in ["gpb", "ffm", "og", "hm", "nb"]:
		if _weapon_ok(u, w):
			out.append(w)
	return out


func _reveal_spenders() -> void:
	for s in 2:
		for id in plots[s].get("u", {}):
			var u: Dictionary = units[id]
			if u["hidden"] and not plots[s]["u"][id].is_empty():
				u["hidden"] = false
				if u["kind"] == "base":
					if not u["found"]:
						u["found"] = true
						log_msg("%s si rivela: %s in %s." % [side_short(s), u["lab"], Hex.label(u["h"])])
				else:
					log_msg("%s esce allo scoperto in %s." % [u["lab"], Hex.label(u["h"])])


func tasks(u: Dictionary) -> Dictionary:
	return plots[u["side"]].get("u", {}).get(u["id"], {})


# ================================================================ esecuzione: fuoco e lanci

var pending := {}                 # id -> perdite in attesa di avere effetto


func _execution() -> void:
	# prepara contromisure, effetto movimento, quota dello stadio
	for id in order:
		var u: Dictionary = units[id]
		if not alive(u):
			continue
		var t := tasks(u)
		u["cm_cur"] = int(t.get("cm", 0))
		u["of_left"] = int(t.get("of", 0))
		var mv: Array = t.get("mv", [])
		if not mv.is_empty():
			var sp := sim_path(u, mv, int(t.get("alt0", -1)) if not u["on"] else -1)
			u["mv_tp"] = int(floor(sp["cost"] + 0.001))
			u["mv_left"] = sp["cost"]
			if sp["air"]:
				u["air_stage"] = true
			if sp["gnd"]:
				u["gnd_stage"] = true
		else:
			u["mv_tp"] = 0
			u["mv_left"] = 0.0
		u["spent"] += float(u["cm_cur"])
	if not std:
		pending = {}
		await _fire_segment(func(u): return true)
		await _launch_segment(func(u): return true)
		await _apply_pending()
		return
	pending = {}
	await _orbital_laser()
	await _fire_segment(func(u): return not u["ind"])
	await _launch_segment(func(u): return not u["ind"])
	await _apply_pending()
	if over:
		return
	pending = {}
	await _fire_segment(func(u): return u["ind"])
	await _launch_segment(func(u): return u["ind"])
	await _apply_pending()


func _fire_segment(filter: Callable) -> void:
	# fuoco combinato degli sciami Rame (23.12): tre Rame nello stesso esagono e quota con lo stesso fuoco
	var pooled := {}
	if std:
		var groups := {}
		for id in order:
			var u: Dictionary = units[id]
			if not alive(u) or not u["on"] or u["race"] != "r" or u["kind"] == "an" or not filter.call(u):
				continue
			for f in tasks(u).get("df", []):
				var k := "%d|%d|%d|%d|%d" % [u["h"], u["alt"], f["h"], f["alt"], f["tp"]]
				if not groups.has(k):
					groups[k] = []
				groups[k].append(u)
		for k in groups:
			if groups[k].size() == 3:
				var u0: Dictionary = groups[k][0]
				var others := 0
				for o in units_at(u0["h"], u0["alt"]):
					if o["side"] == u0["side"] and o["race"] == "r" and o["kind"] != "an":
						others += 1
				if others == 3:
					pooled[k] = groups[k]
	var done_pool := {}
	for id in order:
		var u: Dictionary = units[id]
		if not alive(u) or not u["on"] or not filter.call(u):
			continue
		var t := tasks(u)
		for f in t.get("df", []):
			var k := "%d|%d|%d|%d|%d" % [u["h"], u["alt"], f["h"], f["alt"], f["tp"]]
			var mult := 1.0
			if pooled.has(k):
				if done_pool.has(k):
					u["spent"] += float(f["tp"])
					continue
				done_pool[k] = true
				mult = 3.0
				log_msg("Lo sciame Rame in %s spara con forza combinata." % Hex.label(u["h"]))
			u["spent"] += float(f["tp"])
			if not lof(u["side"], u["h"], u["alt"], f["h"], f["alt"], false, u["id"]):
				continue
			await _direct_fire(u, int(f["h"]), int(f["alt"]), int(f["tp"]), mult)
		for f in t.get("rf", []):
			u["spent"] += float(f["tp"])
			var tu: Dictionary = units.get(f["u"], {})
			if tu.is_empty() or not alive(tu) or not tu["on"]:
				continue
			if not lof(u["side"], u["h"], u["alt"], tu["h"], tu["alt"], true, u["id"]):
				continue
			await _attack(u, tu, eff(u) * float(f["tp"]), "fuoco ristretto")
			if sit == "B" and tu["carry"] != "" and pending.get(tu["id"], 0) > 0:
				_civ_hit(_civ(tu["carry"]), u["side"], "fuoco ristretto")
		var lc: Dictionary = t.get("lc", {})
		if not lc.is_empty() and u["kind"] == "pl" and u["laser"]:
			if lc.get("reg", false):
				var reg: Array = u["reg"]
				if not reg.has(lc["h"]):
					reg.append(lc["h"])
					while reg.size() > 2:
						reg.pop_front()
				log_msg("%s registra il cannone laser su %s." % [u["lab"], Hex.label(lc["h"])])
			else:
				await _laser_cannon(u, int(lc["h"]), int(lc["alt"]))


func _direct_fire(u: Dictionary, h: int, alt: int, tp: int, mult := 1.0) -> void:
	var as_ := eff(u) * float(tp) * mult
	if u["kind"] == "hw":
		as_ *= 2.0
	var any := false
	for tu in units_at(h, alt):
		if tu["side"] == u["side"]:
			continue
		any = true
		await _attack(u, tu, as_, "fuoco diretto")
	if alt <= 1:
		for c in civs:
			if c["h"] == h and not c["dead"] and c["carrier"] == "" and (std or not c["up"]):
				await _attack_civ_fire(u, c, as_)
	if not any:
		_emit("fire", {"from": u["h"], "falt": u["alt"], "to": h, "talt": alt, "side": u["side"], "res": -1})
		await _pace(0.25)


func _attack(u: Dictionary, tu: Dictionary, as_: float, what: String, ignore_cm := false, a_h := -1, a_alt := -1) -> void:
	var fh: int = u["h"] if a_h < 0 else a_h
	var fa: int = u["alt"] if a_alt < 0 else a_alt
	if tu["kind"] == "dink":
		ignore_cm = true
	var ds := defense(tu, fh, fa, ignore_cm)
	var diff := int(floor(as_ - ds))
	var roll := _2d6()
	var res := D.fire_result(diff, roll, std) if diff >= 1 else 0
	var who: String = u["lab"] if u.has("lab") else str(u.get("name", "Orbitale"))
	if diff < 1:
		log_msg("%s: %s su %s, attacco %s contro difesa %s: impossibile." % [who, what, _uname(tu), _num(as_), _num(ds)])
	else:
		log_msg("%s: %s su %s, differenziale %+d, dadi %d: %s." % [who, what, _uname(tu), diff, roll, ("perde %d TP" % res) if res > 0 else "nessun effetto"])
	_emit("fire", {"from": fh, "falt": fa, "to": tu["h"], "talt": tu["alt"], "side": u.get("side", 0), "res": res, "id": tu["id"]})
	if res > 0:
		_damage(tu, res, int(u.get("side", 0)), false, true)
	await _pace(0.35)


func _uname(u: Dictionary) -> String:
	return "%s (%s)" % [u["lab"], side_short(u["side"])]


func _num(v: float) -> String:
	return str(int(v)) if absf(v - roundf(v)) < 0.01 else "%.1f" % v


func _laser_cannon(u: Dictionary, h: int, alt: int) -> void:
	var reg: bool = u["reg"].has(h)
	log_msg("%s spara con il cannone laser su %s%s." % [u["lab"], Hex.label(h), " (registrato)" if reg else ""])
	for tu in units_at(h, alt):
		if tu["side"] != u["side"]:
			await _attack(u, tu, 24.0, "cannone laser", reg)
	if alt <= 1:
		for c in civs:
			if c["h"] == h and not c["dead"] and std:
				await _attack_civ_fire(u, c, 24.0)
	if units_at(h, alt).is_empty():
		_emit("fire", {"from": u["h"], "falt": 2, "to": h, "talt": alt, "side": u["side"], "res": -1, "laser": true})


func _orbital_laser() -> void:
	for s in 2:
		for o in plots[s].get("orb", []):
			if o["t"] != "l":
				continue
			log_msg("Raffica laser orbitale di %s su %s (%s)." % [side_short(s), Hex.label(o["h"]), ALT_NAME[o["alt"]]])
			var src := {"side": s, "name": "Laser orbitale", "lab": "Laser orbitale"}
			_emit("orbital_laser", {"to": o["h"], "talt": o["alt"], "side": s})
			for tu in units_at(o["h"], o["alt"]):
				if tu["side"] != s:
					await _attack(src, tu, 24.0, "raffica laser", false, o["h"], o["alt"])
			if o["alt"] <= 1 and std:
				for c in civs:
					if c["h"] == o["h"] and not c["dead"]:
						await _attack_civ_fire(src, c, 24.0, o["h"], o["alt"])
			await _pace(0.4)


func _launch_segment(filter: Callable) -> void:
	for id in order:
		var u: Dictionary = units[id]
		if not alive(u) or not u["on"] or not filter.call(u):
			continue
		for l in tasks(u).get("ln", []):
			u["spent"] += float(l["tp"])
			var w: String = l["w"]
			if w == "hm":
				var m := {"id": "m%d" % missiles.size(), "side": u["side"], "h": int(l["h"]), "active": false, "target": "", "mine": false, "left": 12, "dead": false}
				missiles.append(m)
				log_msg("%s lancia un %s verso %s." % [u["lab"], W_NAME[w], Hex.label(l["h"])])
				_emit("launch", {"from": u["h"], "falt": u["alt"], "to": l["h"], "w": w, "side": u["side"]})
				_reveal_base_spend(u)
				continue
			lws.append({"w": w, "from": u["h"], "falt": u["alt"], "h": int(l["h"]), "tp": int(l["tp"]), "hi": l["hi"], "side": u["side"], "eff": eff(u), "by": u["id"], "race": u["race"]})
			log_msg("%s lancia %s verso %s%s." % [u["lab"], W_NAME[w], Hex.label(l["h"]), " (in alta quota)" if l["hi"] else ""])
			_emit("launch", {"from": u["h"], "falt": u["alt"], "to": l["h"], "w": w, "side": u["side"]})
			await _pace(0.2)


func _reveal_base_spend(u: Dictionary) -> void:
	if u["kind"] == "base" and not u["found"]:
		u["found"] = true


func _apply_pending() -> void:
	for id in pending:
		var u: Dictionary = units[id]
		if u["dead"]:
			continue
		_take_effect(u, int(pending[id]))
	pending = {}
	_check_preservation()
	_check_victory(false)
	changed.emit()


# ================================================================ danni

## Un risultato contro un'unità. delayed: durante la fase di fuoco ha effetto alla fine del segmento.
func _damage(u: Dictionary, n: int, by_side: int, stun: bool, delayed := false) -> void:
	if u["dead"]:
		return
	if u["kind"] in ["pl", "base", "dink"]:
		_platform_damage(u, n, by_side)
		return
	if stun:
		u["stun"] = true
		return
	if n <= 0:
		return
	if delayed and phase == "fuoco":
		pending[u["id"]] = int(pending.get(u["id"], 0)) + n
		u["hit"] = true
		return
	_take_effect(u, n)


func _take_effect(u: Dictionary, n: int) -> void:
	var old: int = u["tpa"]
	u["tpa"] = maxi(0, old - n)
	var lost := old - int(u["tpa"])
	u["hit"] = true
	if u["side"] < 2 and std:
		sides[u["side"]]["lost"] += lost
	elif u["side"] < 2:
		sides[u["side"]]["lost"] += lost
	_trim_tasks(u, n)
	if u["tpa"] <= 0:
		_kill(u)
	_check_preservation()


## 11.21-11.23: le perdite tolgono i punti assegnati ai compiti non ancora eseguiti.
func _trim_tasks(u: Dictionary, n: int) -> void:
	var left := n
	var take := mini(left, int(u["of_left"]))
	u["of_left"] -= take
	left -= take
	if left > 0 and u["cm_cur"] > 0:
		take = mini(left, int(u["cm_cur"]))
		u["cm_cur"] -= take
		u["spent"] = maxf(0.0, u["spent"] - take)
		left -= take
	if left > 0 and u["mv_left"] > 0.0:
		u["mv_left"] = maxf(0.0, u["mv_left"] - float(left))


func _kill(u: Dictionary) -> void:
	if u["dead"]:
		return
	u["dead"] = true
	u["tpa"] = 0
	sides[u["side"]]["killed"] += 1
	log_msg("%s è eliminato." % _uname(u))
	_emit("dead", {"id": u["id"], "h": u["h"], "alt": u["alt"]})
	if u["carry"] != "":
		var c := _civ(u["carry"])
		if not c.is_empty():
			c["carrier"] = ""
		u["carry"] = ""
	if sit == "D" and u["side"] == 1:
		dink["pts"][0] += 2


func _platform_damage(u: Dictionary, n: int, by_side: int) -> void:
	if n < 6:
		return
	var roll := mini(12, _2d6() + (n - 6))
	var r := D.platform_damage(roll)
	if u["kind"] == "base" and r == "laser":
		r = "dimezza"
	if u["kind"] == "pl" and r == "laser" and not u["laser"]:
		r = "dimezza"
	if u["kind"] == "dink":
		if r == "nulla":
			log_msg("Il Dinkblog incassa il colpo (danni %d): nessun effetto." % roll)
			return
		if r == "distrutta" or dink["wounds"] >= 1:
			dink["wounds"] = 2
			log_msg("Il Dinkblog è ucciso!")
			_kill(u)
			return
		dink["wounds"] = 1
		u["wounds"] = 1
		log_msg("Il Dinkblog è ferito: ora si teletrasporta una sola volta per turno.")
		return
	match r:
		"nulla":
			log_msg("%s: danni %d, nessun effetto." % [_uname(u), roll])
		"dimezza":
			if u["halved"]:
				log_msg("%s: già dimezzata, è distrutta." % _uname(u))
				_kill(u)
			else:
				u["halved"] = true
				u["tpa"] = int(ceil(float(u["tpa"]) / 2.0))
				log_msg("%s: TPA dimezzato (ora %d)." % [_uname(u), u["tpa"]])
		"laser":
			u["laser"] = false
			log_msg("%s: cannone laser distrutto." % _uname(u))
		"distrutta":
			log_msg("%s: distrutta." % _uname(u))
			_kill(u)
	u["hit"] = true


func _check_preservation() -> void:
	if not std or sit in ["X", "D"]:
		return
	var crossing := []
	for s in 2:
		var pl := int(sides[s]["pl"])
		if pl > 0 and sides[s]["lost"] > pl and not sides[s]["pres_pending"]:
			crossing.append(s)
	if crossing.is_empty():
		return
	var other_already := false
	for s in 2:
		if sides[s]["pres_pending"]:
			other_already = true
	if other_already:
		return
	for s in crossing:
		sides[s]["pres_pending"] = true
		log_msg("%s supera il livello di preservazione (%d TP persi su %d)." % [side_short(s), sides[s]["lost"], sides[s]["pl"]])
	if sit == "Z":
		if crossing.size() == 2:
			_win(-1, "entrambi oltre il livello di preservazione.")
		else:
			_win(1 - int(crossing[0]), "ha spinto l'avversario oltre il livello di preservazione.")


# ================================================================ civili

func _civ(id: String) -> Dictionary:
	for c in civs:
		if c["id"] == id:
			return c
	return {}


func _civ_marker_at(h: int) -> bool:
	for c in civs:
		if c["h"] == h and not c["dead"]:
			return true
	return false


func _genuine_taken_by_enemy(h: int) -> bool:
	# 13.41: gli umani possono lanciare solo su un civile vero spostato dai L'Chal Dah e con loro nell'esagono
	for c in civs:
		if c["h"] == h and c["genuine"] and c["moved"] and not c["dead"]:
			for u in units_at(h):
				if u["side"] == 0:
					return true
	return false


func _attack_civ_fire(u: Dictionary, c: Dictionary, as_: float, a_h := -1, a_alt := -1) -> void:
	var fh: int = u.get("h", a_h) if a_h < 0 else a_h
	var fa: int = u.get("alt", a_alt) if a_alt < 0 else a_alt
	var ds := float(range_att(fh, fa, c["h"], 0)) + float(tv(c["h"]))
	var diff := int(floor(as_ - ds))
	if diff < 1:
		return
	var res := D.fire_result(diff, _2d6(), std)
	if res > 0:
		_civ_hit(c, int(u.get("side", 0)), "fuoco", res)


func _civ_lw(c: Dictionary, strength: float, by_side: int, high: bool) -> void:
	if high:
		return
	var res := D.lw_result(strength / float(tv(c["h"])), _2d6(), std)
	if res == 0:
		return
	if sit == "B":
		if res < 0:
			return
		if c["up"]:
			c["up"] = false
			if not c["genuine"]:
				c["dead"] = true
				log_msg("L'esplosione rivela un segnalino fittizio in %s." % Hex.label(c["h"]))
				return
		_civ_hit(c, by_side, "esplosione", res)
	elif res > 0:
		_civ_hit(c, by_side, "esplosione", res)


func _civ_hit(c: Dictionary, by_side: int, what: String, n := 1) -> void:
	if c.is_empty() or c["dead"]:
		return
	if sit == "B":
		if not c["genuine"]:
			return
		c["dead"] = true
		c["killed_by"] = by_side
		log_msg("Un civile vero è ucciso in %s (%s di %s)." % [Hex.label(c["h"]), what, side_short(by_side)])
		_emit("civ", {"h": c["h"]})
		if by_side == 0:
			_win(1, "un civile ucciso dai L'Chal Dah.", "decisiva")
		return
	if sit == "D":
		return
	sides[by_side]["ccp"] += n
	log_msg("%d punti di vittime civili in %s, causati da %s." % [n, Hex.label(c["h"]), side_short(by_side)])
	_emit("civ", {"h": c["h"]})


func _human_killed_civ() -> bool:
	for c in civs:
		if c["dead"] and c["genuine"] and int(c.get("killed_by", -1)) == 1:
			return true
	return false


# ================================================================ movimento

func _movement() -> void:
	var movers := []
	for id in order:
		var u: Dictionary = units[id]
		if not alive(u):
			continue
		var t := tasks(u)
		if t.has("mv") and u["mv_left"] > 0.0:
			u["path_done"] = 0
			u["_mv"] = t["mv"]
			if not u["on"]:
				u["alt"] = int(t.get("alt0", 1))
			movers.append(u)
		# trasporto: il civile parte con il soldato
		if t.has("tr"):
			var cv := _civ(t["tr"])
			if not cv.is_empty() and cv["h"] == u["h"] and cv["carrier"] == "":
				# due soldati sullo stesso civile: nessuno riesce (13.44)
				var rivals := 0
				for s in 2:
					for oid in plots[s].get("u", {}):
						if plots[s]["u"][oid].get("tr", "") == t["tr"]:
							rivals += 1
				if rivals == 1:
					cv["carrier"] = u["id"]
					u["carry"] = cv["id"]
					cv["moved"] = true
					u["spent"] += 3.0
					log_msg("%s prende con sé il civile in %s." % [u["lab"], Hex.label(u["h"])])
				else:
					log_msg("Due soldati contendono il civile in %s: nessuno riesce a portarlo via." % Hex.label(u["h"]))
	if sit == "D":
		await _dink_move()
	_check_missiles_all()
	await _opportunity_all(false)
	mv_round = 0
	var moving := true
	while moving and not over:
		moving = false
		mv_round += 1
		# a turno un passo per ogni soldato, alternando i lati
		var seq := []
		var a0 := []
		var a1 := []
		for u in movers:
			if alive(u) and u["path_done"] < u["_mv"].size():
				if u["side"] == 0:
					a0.append(u)
				else:
					a1.append(u)
		var i := 0
		while i < maxi(a0.size(), a1.size()):
			if (mv_round + i) % 2 == 0:
				if i < a0.size():
					seq.append(a0[i])
				if i < a1.size():
					seq.append(a1[i])
			else:
				if i < a1.size():
					seq.append(a1[i])
				if i < a0.size():
					seq.append(a0[i])
			i += 1
		for u in seq:
			if not alive(u):
				continue
			if await _step(u):
				moving = true
			await _move_missiles_round()
			if over:
				return
		# un passo di tutti nello stesso momento: la vista li fa scivolare insieme
		if moving:
			await _pace(0.35)
	# missili ancora attivi finiscono la corsa, poi l'ultimo fuoco d'opportunità (9.27)
	for k in 12:
		var any := false
		for m in missiles:
			if m["active"] and not m["dead"]:
				any = true
		if not any:
			break
		await _move_missiles_round()
	for m in missiles:
		if m["active"] and not m["dead"]:
			m["dead"] = true
			log_msg("Un missile cercatore non raggiunge il bersaglio e si autodistrugge.")
	await _opportunity_all(true)
	_searches()
	for u in movers:
		u.erase("_mv")
	changed.emit()


## Un passo del movimento di un soldato; false se ha finito.
func _step(u: Dictionary) -> bool:
	var mv: Array = u["_mv"]
	if u["path_done"] >= mv.size():
		return false
	var s = mv[u["path_done"]]
	var from_h: int = u["h"]
	var from_alt: int = u["alt"]
	var c := 0.0
	var nh := from_h
	var na := from_alt
	if s is String:
		na = ALT_SHORT.find(s)
		c = float(ALT_COST[from_alt][na])
	elif int(s) == -1:
		c = 0.5 if from_alt > 0 else 1.0
		nh = -1
	else:
		nh = int(s)
		c = move_cost(nh, from_alt)
	if c > u["mv_left"] + 0.001:
		u["path_done"] = mv.size()
		if c > 0:
			log_msg("%s non ha più punti per muovere." % u["lab"])
		return false
	u["mv_left"] -= c
	u["spent"] += c
	u["path_done"] += 1
	if nh == -1:
		_exit_map(u)
		return true
	if not u["on"]:
		u["on"] = true
		u["entry"] = ""
		log_msg("%s entra in %s (%s)." % [u["lab"], Hex.label(nh), ALT_NAME[na]])
	u["h"] = nh
	u["alt"] = na
	if u["carry"] != "":
		var cv := _civ(u["carry"])
		if not cv.is_empty():
			cv["h"] = nh
	_emit("move", {"id": u["id"], "from": from_h, "to": nh, "falt": from_alt, "talt": na})
	_discover(u)
	_check_missiles_for(u)
	# niente pausa qui: si aspetta una volta per giro, così tutte le unità avanzano insieme
	await _opportunity_all(false, u)
	return true


func _exit_map(u: Dictionary) -> void:
	var h: int = u["h"]
	u["on"] = false
	u["exited"] = true
	sides[u["side"]]["exited"] += 1
	log_msg("%s esce dalla mappa da %s." % [_uname(u), Hex.label(h)])
	_emit("exit", {"id": u["id"], "h": h})
	if sit == "P" and u["side"] == 0 and Hex.on_edge(h, base_edge):
		sides[0]["pts"] += 10
		u["exit_ok"] = true
	if sit == "B" and u["carry"] != "":
		var cv := _civ(u["carry"])
		if not cv.is_empty() and cv["genuine"] and u["side"] == 0:
			cv["h"] = 0
			cv["gone"] = true
			var marginal := false
			for c in civs:
				if c["dead"] and c["genuine"]:
					marginal = true
			_win(0, "un civile portato fuori dalla mappa.", "marginale" if marginal else "sostanziale")


## 27.27: una base nascosta si scopre quando un soldato Alpha (a terra o in volo radente) passa vicino
func _discover(u: Dictionary) -> void:
	if not sit in ["R", "A"] or u["side"] != 0 or u["alt"] == 2 or not u["kind"] in ["ss", "hw", "an"]:
		return
	var rad := 2 if sides[0]["pres"] else 4
	for b in live(1):
		if b["kind"] == "base" and not b["found"] and Hex.dist(b["h"], u["h"]) <= rad:
			b["found"] = true
			b["hidden"] = false
			log_msg("%s scopre una base in %s!" % [u["lab"], Hex.label(b["h"])])
			_emit("found", {"h": b["h"]})


## Fuoco d'opportunità automatico. Ogni soldato con punti d'opportunità tira con la dose scelta sul
## primo bersaglio con un differenziale di almeno +2 (alla fine del movimento basta +1).
func _opportunity_all(final: bool, mover := {}) -> void:
	for id in order:
		var u: Dictionary = units[id]
		if not alive(u) or not u["on"] or u["of_left"] <= 0:
			continue
		var size := int(tasks(u).get("ofs", u["of_left"]))
		var tries := 0
		while u["of_left"] > 0 and tries < 6:
			tries += 1
			var shot := mini(size, u["of_left"])
			var best := {}
			var best_d := -99
			var cand := live(1 - u["side"], true) if mover.is_empty() else [mover]
			if final:
				cand = live(1 - u["side"], true)
			for tu in cand:
				if tu["side"] == u["side"] or not alive(tu) or not tu["on"] or tu["kind"] == "base" and not tu["found"]:
					continue
				if tu["hidden"]:
					continue
				if not lof(u["side"], u["h"], u["alt"], tu["h"], tu["alt"], false, u["id"]):
					continue
				var as_ := eff(u) * float(shot) * (2.0 if u["kind"] == "hw" else 1.0)
				var d := int(floor(as_ - defense(tu, u["h"], u["alt"])))
				if d > best_d:
					best_d = d
					best = tu
			if best.is_empty() or best_d < (1 if final else 2):
				break
			u["of_left"] -= shot
			u["spent"] += float(shot)
			var as2 := eff(u) * float(shot) * (2.0 if u["kind"] == "hw" else 1.0)
			await _attack(u, best, as2, "fuoco d'opportunità")
			_check_victory(false)
			if over:
				return


func _searches() -> void:
	if sit != "B":
		return
	for id in plots[0].get("u", {}):
		var t: Dictionary = plots[0]["u"][id]
		if not t.get("se", false):
			continue
		var u: Dictionary = units[id]
		if not alive(u) or not u["on"]:
			continue
		u["spent"] += 1.0
		for c in civs:
			if c["h"] == u["h"] and c["up"] and not c["dead"]:
				c["up"] = false
				if c["genuine"]:
					log_msg("%s trova un civile vero in %s!" % [u["lab"], Hex.label(c["h"])])
				else:
					c["dead"] = true
					c["dummy_gone"] = true
					log_msg("%s scopre che il segnalino in %s è fittizio." % [u["lab"], Hex.label(c["h"])])
				_emit("search", {"h": c["h"], "genuine": c["genuine"]})


# ================================================================ missili cercatori (19.0)

func _hm_ds(m: Dictionary, tu: Dictionary) -> float:
	return defense(tu, m["h"], 1)


func _check_missiles_all() -> void:
	for m in missiles:
		if m["dead"] or m["active"] or not Hex.valid(m["h"]):
			continue
		var best := {}
		var bd := 999.0
		for tu in live(1 - m["side"], true):
			if tu["kind"] in ["base"]:
				continue
			if not lof(m["side"], m["h"], 1, tu["h"], tu["alt"], true):
				continue
			var ds := _hm_ds(m, tu)
			if ds <= 10.0 and (ds < bd or (ds == bd and rng.randi_range(0, 1) == 0)):
				bd = ds
				best = tu
		if not best.is_empty():
			_activate(m, best)


func _check_missiles_for(u: Dictionary) -> void:
	for m in missiles:
		if m["dead"] or m["active"] or not Hex.valid(m["h"]) or m["side"] == u["side"]:
			continue
		if u["kind"] == "base":
			continue
		if not lof(m["side"], m["h"], 1, u["h"], u["alt"], true):
			continue
		if _hm_ds(m, u) <= 10.0:
			_activate(m, u)


func _activate(m: Dictionary, tu: Dictionary) -> void:
	m["active"] = true
	m["target"] = tu["id"]
	m["left"] = 12
	log_msg("Un missile cercatore %sin %s aggancia %s!" % ["nascosto " if m["mine"] else "", Hex.label(m["h"]), _uname(tu)])
	m["mine"] = false
	_emit("hm_on", {"h": m["h"], "id": tu["id"]})


func _move_missiles_round() -> void:
	for m in missiles:
		if m["dead"] or not m["active"]:
			continue
		var tu: Dictionary = units.get(m["target"], {})
		if tu.is_empty() or not alive(tu) or not tu["on"]:
			m["dead"] = true
			continue
		# 19.33: il bersaglio con fuoco d'opportunità può abbattere il missile in arrivo
		if tu["of_left"] > 0 and Hex.dist(m["h"], tu["h"]) <= 3:
			var shot: int = tu["of_left"]
			tu["of_left"] = 0
			tu["spent"] += float(shot)
			var as_ := eff(tu) * float(shot) * (2.0 if tu["kind"] == "hw" else 1.0)
			var ds := float(range_att(tu["h"], tu["alt"], m["h"], 1) + D.T_VALUE[terrain(m["h"])])
			var diff := int(floor(as_ - ds))
			if diff >= 1 and D.fire_result(diff, _2d6(), std) > 0:
				m["dead"] = true
				log_msg("%s abbatte il missile cercatore." % tu["lab"])
				_emit("fire", {"from": tu["h"], "falt": tu["alt"], "to": m["h"], "talt": 1, "side": tu["side"], "res": 1})
				continue
		if m["h"] == tu["h"]:
			await _hm_detonate(m, tu)
			continue
		if m["left"] <= 0:
			continue
		var best: int = m["h"]
		var bd := Hex.dist(m["h"], tu["h"])
		for n in Hex.neighbors(m["h"]):
			var d := Hex.dist(n, tu["h"])
			if d < bd:
				bd = d
				best = n
		var from: int = m["h"]
		m["h"] = best
		m["left"] -= 1
		_emit("hm_move", {"from": from, "to": best})
		if m["h"] == tu["h"]:
			await _hm_detonate(m, tu)


func _hm_detonate(m: Dictionary, tu: Dictionary) -> void:
	m["dead"] = true
	log_msg("Il missile cercatore raggiunge %s ed esplode." % _uname(tu))
	await _detonate(tu["h"], tu["alt"] == 2, [30.0, 15.0, 5.0], m["side"], "hm")


# ================================================================ armi lanciate e orbitali

func _projectiles() -> void:
	# dispersione e intercettazione
	for l in lws:
		var det := int(l["h"])
		var high: bool = l["hi"]
		var w: String = l["w"]
		var cmt := _blast_cm(det, high)
		if w in ["gpb", "nb"]:
			var rng_eff := int(ceil(float(Hex.dist(l["from"], det)) / 5.0))
			var sd := int(floor(float(l["eff"]) * float(l["tp"]) - (float(rng_eff) + cmt)))
			if w == "nb":
				sd -= 1
			var die := _d6()
			var n := D.scatter(sd, die)
			if n > 0:
				var dir := _d6()
				var nh := det
				for k in n:
					nh = Hex.neighbor(nh, dir)
					if nh < 0:
						break
				log_msg("La %s verso %s si disperde di %d (differenziale %d, direzione %d)%s." % [W_NAME[w], Hex.label(det), n, sd, dir, "" if nh > 0 else " e cade fuori dalla mappa"])
				_emit("scatter", {"from": det, "to": nh})
				det = nh
			l["det"] = det
		else:
			var rmul := 1 if Hex.dist(l["from"], det) <= 5 else 2
			var val := int(ceil(cmt)) * rmul
			var die2 := _d6()
			if D.intercepted(val, die2):
				log_msg("I %s verso %s sono intercettati dalle contromisure (valore %d, dado %d)." % [W_NAME[w] if w == "ffm" else "colpi della " + W_NAME[w], Hex.label(det), val, die2])
				_emit("intercept", {"h": det})
				l["det"] = -1
			else:
				l["det"] = det
	await _pace(0.2)
	for l in lws:
		if int(l["det"]) <= 0:
			continue
		match l["w"]:
			"og":
				_opacity(int(l["det"]), "og", l["side"])
			"nb":
				await _neutron(int(l["det"]), l["hi"], l["side"])
			_:
				await _detonate(int(l["det"]), l["hi"], [30.0, 15.0, 5.0], l["side"], l["w"])
		if over:
			return
	lws = []
	await _orbital_detonations()


func _blast_cm(h: int, high: bool) -> float:
	var total := 0.0
	var seen := {}
	for hh in blast(h, high):
		for u in units_at(hh):
			if (u["alt"] == 2) != high:
				continue
			if seen.has(u["id"]):
				continue
			seen[u["id"]] = true
			if u["race"] == "r" and u["kind"] != "an":
				var e := eff(u) * (0.5 if u["gnd_stage"] else 1.0)
				total += e * float(u["cm_cur"])
			else:
				var e2 := eff(u) * (0.5 if u["air_stage"] else 1.0)
				total += e2 * float(u["cm_cur"])
	return total


func _detonate(h: int, high: bool, strength: Array, by_side: int, kind: String) -> void:
	var b := blast(h, high)
	_emit("blast", {"h": h, "high": high, "kind": kind, "hexes": b})
	log_msg("Esplosione in %s%s." % [Hex.label(h), " in alta quota" if high else ""])
	for hh in b:
		var ring: int = b[hh]
		var st: float = strength[ring]
		for u in units_at(hh):
			if (u["alt"] == 2) != high:
				continue
			var tvv := 1.0 if high else float(tv(hh))
			if u["kind"] in ["pl", "base"]:
				tvv = 10.0
			elif not high and terrain(hh) in ["c", "l"] and u["alt"] != 0:
				tvv = 1.0
			var ratio := st / tvv
			var roll := _2d6()
			var res := D.lw_result(ratio, roll, std)
			if res == 0:
				continue
			if res < 0:
				log_msg("%s è stordito." % _uname(u))
				_damage(u, 0, by_side, true)
			else:
				log_msg("%s perde %d TP nell'esplosione (%s, dadi %d)." % [_uname(u), res, _ratio(ratio), roll])
				_damage(u, res, by_side, false)
		if not high:
			for c in civs:
				if c["h"] == hh and not c["dead"]:
					_civ_lw(c, st, by_side, high)
				if over:
					return
			for m in missiles:
				if m["h"] == hh and not m["dead"] and not m["active"]:
					var r2 := D.lw_result(st / float(D.T_VALUE[terrain(hh)]), _2d6(), std)
					if r2 != 0:
						m["dead"] = true
						log_msg("Un missile cercatore in %s è distrutto dall'esplosione." % Hex.label(hh))
	if not high:
		if kind == "ob":
			for hh in b:
				if strength[b[hh]] >= 30.0:
					_crater(hh)
		else:
			_crater(h)
	_check_preservation()
	_check_victory(false)
	changed.emit()
	await _pace(0.5)


func _ratio(r: float) -> String:
	return "%d a 1" % int(floor(r + 0.001))


func _crater(h: int) -> void:
	var t := D.terrain(h)
	if craters.has(h) or t in ["m", "l", "u"]:
		return
	craters[h] = true
	_emit("crater", {"h": h})


func _neutron(h: int, high: bool, by_side: int) -> void:
	log_msg("Bomba al neutrone in %s%s!" % [Hex.label(h), " in alta quota" if high else ""])
	_emit("blast", {"h": h, "high": high, "kind": "nb", "hexes": {h: 0}})
	for u in units_at(h):
		var same: bool = (u["alt"] == 2) == high
		if u["kind"] == "pl" and not high:
			continue
		if same:
			log_msg("%s è vaporizzato." % _uname(u))
			if u["side"] < 2:
				sides[u["side"]]["lost"] += int(u["tpa"])
			_kill(u)
		else:
			u["stun"] = true
	if not high and not craters.has(h):
		craters[h] = true
		_emit("crater", {"h": h})
	_check_victory(false)
	await _pace(0.5)


func _opacity(h: int, k: String, by_side: int) -> void:
	smoke[h] = {"k": k, "turn": turn, "stage": stage}
	log_msg("%s in %s." % ["Fumo elettronico" if k == "og" else "Fumo denso orbitale", Hex.label(h)])
	_emit("smoke", {"h": h, "k": k})
	for u in units_at(h):
		u["stun"] = true


func _expire_smoke() -> void:
	# 18.12, 18.4: il fumo della granata dura un turno intero (due fasi di movimento) dopo l'esplosione
	for h in smoke.keys():
		var sm: Dictionary = smoke[h]
		if sm["k"] != "og":
			continue
		var age := (turn - int(sm["turn"])) * (2 if std else 1) + (stage - int(sm["stage"]))
		if age >= (2 if std else 1):
			smoke.erase(h)
			_emit("smoke_off", {"h": h})


func _orbital_detonations() -> void:
	var list := orb_pending.duplicate()
	orb_pending = []
	for s in 2:
		for o in plots[s].get("orb", []):
			if o["t"] in ["b", "o"]:
				list.append({"t": o["t"], "h": o["h"], "side": s})
	for o in list:
		var h := int(o["h"])
		var col := -4 if o["t"] == "b" else -2
		var n := D.scatter(col, _d6())
		if o["t"] == "b":
			n *= 2
		if n > 0:
			var dir := _d6()
			for k in n:
				var nh := Hex.neighbor(h, dir)
				if nh < 0:
					h = -1
					break
				h = nh
		if h <= 0:
			log_msg("Un colpo orbitale cade fuori dalla mappa.")
			continue
		_emit("orbital", {"h": h, "t": o["t"]})
		if o["t"] == "b":
			log_msg("Bombardamento orbitale in %s." % Hex.label(h))
			await _detonate(h, false, [90.0, 30.0, 15.0], int(o["side"]), "ob")
		else:
			_opacity(h, "ob", int(o["side"]))
		if over:
			return


# ================================================================ Dinkblog (39.0)

func _dinkblog_attack() -> void:
	if sit != "D" or dink.is_empty():
		return
	var d: Dictionary = units[dink["id"]]
	if not alive(d) or not d["on"]:
		return
	for u in units_at(d["h"]):
		if u["side"] == 1:
			var res := D.lw_result(30.0, _2d6(), true)
			if res > 0:
				log_msg("Il Dinkblog attacca %s: perde %d TP." % [u["lab"], res])
				_damage(u, res, 0, false)
			elif res < 0:
				u["stun"] = true
	for c in civs:
		if c["h"] == d["h"] and not c["dead"]:
			var r2 := D.lw_result(30.0, _2d6(), true)
			if r2 > 0:
				c["dead"] = true
				dink["pts"][0] += 1
				log_msg("Il Dinkblog divora i civili in %s!" % Hex.label(c["h"]))
				_emit("civ", {"h": c["h"]})
	_emit("dink", {"h": d["h"]})


func _dink_move() -> void:
	var d: Dictionary = units[dink["id"]]
	if not alive(d):
		return
	var t := tasks(d)
	if not t.has("tele"):
		return
	if dink["wounds"] >= 1 and int(dink["moved_turn"]) == turn:
		return
	var to := int(t["tele"])
	if to == d["h"] and d["on"]:
		return
	dink["moved_turn"] = turn
	if to == -1:
		if d["on"]:
			log_msg("Il Dinkblog si teletrasporta via dalla mappa.")
			dink["left"] = true
			d["on"] = false
			d["exited"] = true
			_emit("exit", {"id": d["id"], "h": d["h"]})
		return
	var from: int = d["h"]
	d["h"] = to
	d["alt"] = 0
	d["on"] = true
	d["entry"] = ""
	log_msg("Il Dinkblog si teletrasporta in %s!" % Hex.label(to))
	_emit("teleport", {"id": d["id"], "from": from, "to": to})
	await _pace(0.4)


func _dink_end(why: String) -> void:
	var hp: int = dink["pts"][1]
	var dp: int = dink["pts"][0]
	if dink["wounds"] >= 2:
		hp += 5
	elif dink["wounds"] == 1:
		hp += 1
	if dink.get("left", false):
		hp += 1
	if hp > dp + 1:
		_win(1, "%s; punti %d a %d." % [why, hp, dp])
	elif dp > hp + 1:
		_win(0, "%s; punti %d a %d." % [why, dp, hp])
	else:
		_win(-1, "%s; punti %d a %d." % [why, hp, dp])


# ================================================================ recupero e vittoria

func _recovery() -> void:
	for id in order:
		var u: Dictionary = units[id]
		if not alive(u) or u["kind"] in ["pl", "base", "dink"]:
			continue
		if u["hit"] or u["stun"] or u["rec"] <= 0:
			continue
		var cap: int = u["tpa0"]
		var gain := mini(int(u["rec"]), cap - int(u["tpa"]))
		if gain > 0:
			u["tpa"] += gain
			sides[u["side"]]["lost"] = maxi(0, sides[u["side"]]["lost"] - gain)


func _check_victory(end_turn: bool) -> void:
	if over:
		return
	match sit:
		"B":
			var lcd := live(0)
			if lcd.is_empty():
				_win(1, "la Squadra L'Chal Dah è distrutta.", "sostanziale" if not _human_killed_civ() else "marginale")
				return
			var gen_left := false
			for c in civs:
				if c["genuine"] and not c["dead"]:
					gen_left = true
			if not gen_left:
				_win(1, "non restano civili da catturare.", "marginale")
		"P":
			if turn >= 1 and phase != "schieramento":
				var any := false
				for u in live(0):
					if u["kind"] != "base":
						any = true
				if not any:
					_patrol_end("nessuna forza Alpha resta sulla mappa")
		"R":
			var all_found := true
			var nb := 0
			for u in units.values():
				if u["kind"] == "base" and u["side"] == 1:
					nb += 1
					if not u["found"]:
						all_found = false
			if nb > 0 and all_found:
				_win(0, "tutte le basi sono state scoperte.")
				return
			if _no_alpha_soldiers():
				_win(1, "nessun soldato Alpha resta in gioco.")
		"A":
			var all_dead := true
			for u in units.values():
				if u["kind"] == "base" and u["side"] == 1 and not u["dead"]:
					all_dead = false
			if all_dead:
				_win(0, "tutte le basi sono distrutte.")
				return
			if _no_alpha_soldiers():
				_win(1, "nessuna forza Alpha resta in gioco.")
		"X":
			for s in 2:
				if soldiers(s).is_empty():
					_win(1 - s, "tutti i nemici sono eliminati.")
					return
		"D":
			var d: Dictionary = units[dink["id"]]
			if d["dead"]:
				_dink_end("il Dinkblog è morto")
			elif dink.get("left", false):
				_dink_end("il Dinkblog è fuggito")
			elif soldiers(1).is_empty():
				_dink_end("tutti gli StarSoldier sono morti")
		"Z":
			for s in 2:
				if soldiers(s).is_empty():
					_win(1 - s, "nessun avversario resta in piedi.")
					return
	# 30.33: chi causa più di cinque punti di vittime civili in più dell'avversario perde
	if over and std and sides[0]["ccp"] + sides[1]["ccp"] > 0 and sit in ["P", "R", "A"]:
		var d0: int = sides[0]["ccp"] - sides[1]["ccp"]
		if d0 > 5:
			result["winner"] = 1
			result["reason"] = "Alpha ha causato troppe vittime civili (%d contro %d)." % [sides[0]["ccp"], sides[1]["ccp"]]
			log_msg("Ma " + result["reason"] + " La partita va a Bravo.")
		elif d0 < -5:
			result["winner"] = 0
			result["reason"] = "Bravo ha causato troppe vittime civili (%d contro %d)." % [sides[1]["ccp"], sides[0]["ccp"]]
			log_msg("Ma " + result["reason"] + " La partita va ad Alpha.")


func _no_alpha_soldiers() -> bool:
	for u in live(0):
		if u["kind"] in ["ss", "hw", "an", "pl"]:
			return false
	return true


func _patrol_end(why: String) -> void:
	var a: int = sides[0]["pts"] + 2 * int(sides[1]["lost"])
	var b: int = 3 * int(sides[0]["lost"])
	result["pts"] = [a, b]
	var m := absi(a - b)
	var lvl := "marginale" if m <= 12 else ("sostanziale" if m <= 25 else "decisiva")
	if a == b:
		_win(-1, "%s; punti %d a %d." % [why, a, b])
	else:
		_win(0 if a > b else 1, "%s; punti Alpha %d, Bravo %d." % [why, a, b], lvl)


func score_text() -> String:
	match sit:
		"P":
			return "Punti: Alpha %d, Bravo %d" % [sides[0]["pts"] + 2 * int(sides[1]["lost"]), 3 * int(sides[0]["lost"])]
		"D":
			return "Punti: Dinkblog %d" % dink["pts"][0]
		"R":
			var f := 0
			var n := 0
			for u in units.values():
				if u["kind"] == "base":
					n += 1
					if u["found"]:
						f += 1
			return "Basi scoperte: %d su %d" % [f, n]
		"A":
			var k := 0
			var n2 := 0
			for u in units.values():
				if u["kind"] == "base":
					n2 += 1
					if u["dead"]:
						k += 1
			return "Basi distrutte: %d su %d" % [k, n2]
		"B":
			var found := 0
			for c in civs:
				if not c["up"] and c["genuine"] and not c["dead"]:
					found += 1
			return "Civili veri trovati: %d" % found
	return ""
