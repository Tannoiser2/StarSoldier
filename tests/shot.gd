extends SceneTree
## Screenshot (serve un display: xvfb-run).
## godot --path . -s tests/shot.gd -- scenario situazione grafica secondi file.png [umano 0/1/2] [menu|regole|tabelle] [vista]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scn := int(a[0]) if a.size() > 0 else 13
	var sit := a[1] if a.size() > 1 else "B"
	var st := a[2] if a.size() > 2 else "originale"
	var secs := float(a[3]) if a.size() > 3 else 6.0
	var out := a[4] if a.size() > 4 else "/tmp/shot.png"
	var human := int(a[5]) if a.size() > 5 else -1
	var extra := a[6] if a.size() > 6 else ""
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if extra == "regole" or extra == "tabelle":
		main.show_rules(extra)
	elif extra != "menu":
		var s := SSScenari.get_scn(scn)
		main.start_game({"scenario": scn, "sit": sit, "match": s["scontri"][0], "seats": [{"ai": human != 0}, {"ai": human != 1}], "style": st, "anim": 3.0, "ai_delay": 0.05, "seed": 7})
	await create_timer(secs).timeout
	if extra.begins_with("auto") and main.current != null:
		var g = main.current
		for k in 40:
			if g.req.get("k", "") == "schiera":
				g._confirm_deploy()
			elif g.req.get("k", "") == "piano":
				break
			await create_timer(0.5).timeout
		g._auto_plan()
		var mine: Array = g.eng.live(human, false)
		for u in mine:
			if u["on"] or u["entry"] != "":
				g._select(u["id"], true)
				break
		g.board.dist = 22.0
		await create_timer(1.5).timeout
	if extra.begins_with("zoom") and main.current != null:
		var g = main.current
		var b = g.board
		var f: Array = g.eng.live(maxi(human, 0), true)
		if not f.is_empty():
			b.focus_hex(f[0]["h"])
		b.dist = 12.0
		b.pitch = -0.75
		await create_timer(1.5).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SALVATO ", out)
	quit()
