extends SceneTree
## Un salvataggio (configurazione + registro delle decisioni) rigioca esattamente la stessa partita.

func _init() -> void:
	var ok := true
	for c in [[13, "B", [1, 0]], [30, "A", [0, 1]], [33, "R", [1, 2]], [38, "X", [2, 0]], [39, "D", [1, 0]], [40, "Z", [0, 1]]]:
		var cfg := {"scenario": c[0], "sit": c[1], "match": c[2], "seed": 4242, "seats": [{"ai": true}, {"ai": true}]}
		var e1 := SSEngine.new()
		e1.headless = true
		e1.anim = 0.0
		e1.setup(cfg.duplicate(true))
		root.add_child(e1)
		await e1.run()
		var saved := var_to_str(e1.rec_acts)
		var e2 := SSEngine.new()
		e2.headless = true
		e2.anim = 0.0
		e2.setup(str_to_var(var_to_str(cfg)))
		e2.preload_acts = str_to_var(saved)
		# l'IA del secondo motore non deve servire: se servisse le decisioni sarebbero diverse
		root.add_child(e2)
		await e2.run()
		var same := e1.fingerprint() == e2.fingerprint()
		print("%d %s: %s (%d decisioni) %s" % [c[0], c[1], "uguale" if same else "DIVERSA", e1.rec_acts.size(), e1.result.get("reason", "")])
		ok = ok and same
	print("ESITO ", "OK" if ok else "ERRORE")
	quit()
