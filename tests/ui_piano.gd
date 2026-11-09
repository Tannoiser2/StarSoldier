extends SceneTree
## Simula un giocatore che costruisce i piani dall'interfaccia (percorsi, quote, fuoco, lanci, contromisure).
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game({"scenario": 30, "sit": "P", "match": [0, 1], "seats": [{"ai": false}, {"ai": true}], "style": "reborn", "anim": 20.0, "seed": 11})
	var g = main.current
	var stages := 0
	var t0 := Time.get_ticks_msec()
	while stages < 6 and Time.get_ticks_msec() - t0 < 240000:
		await create_timer(0.3).timeout
		if g.req.get("k", "") != "piano":
			continue
		stages += 1
		for u in g.eng.live(0):
			if not u["on"] and u["entry"] == "":
				continue
			g._select(u["id"])
			g.mode = "mv"
			if not u["on"]:
				g._add_alt(u, "R")
				var e: Array = Hex.edge_hexes(u["entry"])
				g._on_hex(e[randi() % e.size()])
				g._on_hex(Hex.code(20, 30))
			else:
				var foes := []
				for f in g.eng.live(1, true):
					foes.append(f)
				if not foes.is_empty() and randf() < 0.6:
					g.mode = "df"
					g._on_hex(foes[0]["h"], foes[0]["alt"])
					g.mode = "ln:gpb"
					g._on_hex(foes[0]["h"])
				else:
					g._on_hex(Hex.code(Hex.row(u["h"]), maxi(1, Hex.col(u["h"]) - 3)))
			g._tasks(u["id"])["cm"] = 1
			g._refresh()
		print("stadio ", stages, " piano: ", g.draft["u"].size(), " unità")
		g._confirm_plot()
	print("FINE UI turno ", g.eng.turn, " fase ", g.eng.phase)
	quit()
