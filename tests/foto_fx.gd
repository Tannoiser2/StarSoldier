extends SceneTree
## Fotografa gli effetti 3D: jetpack in volo, colpi traccianti, granata, esplosione (serve xvfb-run).
## godot --path . -s tests/foto_fx.gd -- grafica prefisso_file
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var st := a[0] if a.size() > 0 else "reborn"
	var out := a[1] if a.size() > 1 else "/tmp/fx"
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game({"scenario": 30, "sit": "R", "match": [0, 1], "seats": [{"ai": false}, {"ai": false}], "style": st, "anim": 1.0, "seed": 3})
	await create_timer(1.0).timeout
	var g = main.current
	for p in [g.top_bar, g.left_panel, g.right_panel, g.log_panel, g.get_node_or_null("azioni"), g.curtain]:
		if p != null and is_instance_valid(p):
			p.visible = false
	var e = g.eng
	var b = g.board
	b.viewer = -1
	# tre soldati di Alpha in volo, due di Bravo a terra
	var hs := [2018, 2118, 1918, 2120, 2021]
	var i := 0
	for s in 2:
		var n := 0
		for u in e.live(s, false):
			if n >= (3 if s == 0 else 2):
				break
			u["on"] = true
			u["hidden"] = false
			u["h"] = hs[i]
			u["alt"] = (1 if i % 2 == 0 else 2) if s == 0 else 0
			i += 1
			n += 1
	b.refresh()
	b.focus(Hex.world(2019), 9.0)
	b.target = b.target_goal
	b.pitch = -0.55
	b.yaw = 0.35
	await create_timer(1.2).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "_volo.png")
	b.play_fx("fire", {"from": 2018, "falt": 1, "to": 2021, "talt": 0, "side": 0, "res": 2}, 0.4)
	b.play_fx("fire", {"from": 2120, "falt": 0, "to": 1918, "talt": 1, "side": 1, "res": 0}, 0.4)
	b.play_fx("launch", {"from": 2118, "falt": 2, "to": 2222, "w": "gpb", "side": 0}, 0.4)
	await create_timer(0.35).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "_spari.png")
	b.play_fx("blast", {"h": 2220, "high": false, "kind": "gpb", "hexes": {2220: 0, 2219: 1, 2221: 1}}, 1.0)
	await create_timer(0.25).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "_bomba.png")
	await create_timer(0.9).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "_fumo.png")
	print("SALVATO")
	quit()
