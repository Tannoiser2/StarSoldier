extends SceneTree
## Primo piano delle miniature di uno scenario (serve xvfb-run).
## godot --path . -s tests/foto_unita.gd -- scenario situazione file.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1400, 700)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var s := SSScenari.get_scn(int(a[0]))
	main.start_game({"scenario": int(a[0]), "sit": a[1], "match": s["scontri"][0], "seats": [{"ai": false}, {"ai": false}], "style": "reborn", "anim": 1.0, "seed": 3})
	await create_timer(1.0).timeout
	var g = main.current
	for p in [g.top_bar, g.left_panel, g.right_panel, g.log_panel, g.get_node_or_null("azioni"), g.curtain]:
		if p != null and is_instance_valid(p):
			p.visible = false
	var e = g.eng
	var b = g.board
	b.viewer = -1
	var col := 15
	for sd in 2:
		var kinds := {}
		for id in e.order:
			var u: Dictionary = e.units[id]
			if u["side"] != sd or u["dead"]:
				continue
			var k: String = u["race"] + u["kind"]
			if kinds.has(k):
				continue
			kinds[k] = true
			u["on"] = true
			u["hidden"] = false
			u["found"] = true
			u["alt"] = 0
			u["h"] = (19 + sd) * 100 + col
			col += 1
	for c in e.civs:
		c["h"] = 1814
		c["dead"] = false
	if not e.missiles.is_empty():
		e.missiles[0]["h"] = 1815
	b.refresh()
	b.focus(Hex.world(1917), float(a[3]) if a.size() > 3 else 6.0)
	b.target = b.target_goal
	b.pitch = -0.45
	b.yaw = 0.0
	await create_timer(1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(a[2])
	print("SALVATO")
	quit()
