extends SceneTree
## Gioca una partita IA contro IA, poi avvia il replay e controlla che i momenti siano contemporanei.
## xvfb-run godot --path . -s tests/replay.gd -- scenario situazione [file.png]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var s := SSScenari.get_scn(int(a[0]))
	main.start_game({"scenario": int(a[0]), "sit": a[1], "match": s["scontri"][0], "seats": [{"ai": true}, {"ai": true}], "style": "reborn", "anim": 30.0, "ai_delay": 0.02, "seed": 5})
	var g = main.current
	var t := 0.0
	while g.eng.result.is_empty() and t < 30.0:
		await create_timer(0.5).timeout
		t += 0.5
		if int(t * 2) % 10 == 0:
			print("t ", t, " eventi ", g.eng.history.size(), " fase ", g.eng.phase)
	print("fine partita dopo ", t, " s, eventi ", g.eng.history.size())
	g._start_replay()
	var gr: Array = g._replay_g
	var mv := 0
	var units_in_mv := 0
	for x in gr:
		if x[2] == "mv":
			mv += 1
			units_in_mv += x[1] - x[0] + 1
	print("momenti ", gr.size(), ", di movimento ", mv, ", passi per momento ", "%.1f" % (float(units_in_mv) / maxf(mv, 1)))
	await create_timer(6.0).timeout
	print("momento attuale ", g.replay_i)
	if a.size() > 2:
		root.get_viewport().get_texture().get_image().save_png(a[2])
	print("ESITO OK" if gr.size() > 0 and g.replay_i > 3 else "ESITO NO")
	quit()
