extends SceneTree
## Fotografa menu e partita a una certa risoluzione (serve xvfb-run).
## godot --path . -s tests/foto_ui.gd -- larghezza altezza prefisso [scenario situazione]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0])
	var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(a[2] + "_menu.png")
	# il menu con uno scenario ricco di scelte
	main.menu_state = {"scen": int(a[3]) if a.size() > 3 else 30, "sit": a[4] if a.size() > 4 else "R"}
	main.show_menu()
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png(a[2] + "_menu2.png")
	var scn := int(a[3]) if a.size() > 3 else 30
	var hum := int(a[5]) if a.size() > 5 else 0
	var s := SSScenari.get_scn(scn)
	main.start_game({"scenario": scn, "sit": a[4] if a.size() > 4 else "R", "match": s["scontri"][0], "seats": [{"ai": hum != 0}, {"ai": hum != 1}], "style": "reborn", "anim": 3.0, "ai_delay": 0.05, "seed": 7})
	await create_timer(3.0).timeout
	var g = main.current
	for k in 30:
		if g.req.get("k", "") == "schiera":
			g._confirm_deploy()
		elif g.req.get("k", "") == "piano":
			break
		await create_timer(0.3).timeout
	g._auto_plan()
	# un soldato già sulla mappa per vedere tutte le sezioni del piano (fuoco, armi lanciate)
	for u in g.eng.live(hum, false):
		if not u["on"] and u["kind"] == "ss":
			u["on"] = true
			u["h"] = 1810
			u["entry"] = ""
			break
	for u in g.eng.live(hum, false):
		if u["on"]:
			g._select(u["id"], true)
			break
	# qualche unità eliminata per vedere il pannello
	var n := 0
	for id in g.eng.order:
		var u: Dictionary = g.eng.units[id]
		if u["side"] == 0 and n < 2 and u["kind"] == "ss" and u["id"] != g.sel:
			u["dead"] = true
			n += 1
	g._update_left()
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(a[2] + "_gioco.png")
	print("SALVATO")
	quit()
