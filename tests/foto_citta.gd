extends SceneTree
## Fotografia di una zona della mappa 3D (serve un display: xvfb-run).
## godot --path . -s tests/foto_citta.gd -- x z distanza inclinazione rotazione grafica file.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game({"scenario": 30, "sit": "R", "match": [0, 1], "seats": [{"ai": true}, {"ai": true}], "style": a[5], "anim": 0.2, "ai_delay": 5.0, "seed": 3})
	await create_timer(1.0).timeout
	var g = main.current
	for p in [g.top_bar, g.left_panel, g.right_panel, g.log_panel, g.get_node_or_null("azioni")]:
		if p != null:
			p.visible = false
	var b = g.board
	b.show_labels = false
	for id in b.unit_nodes:
		b.unit_nodes[id].visible = false
	b.focus(Vector3(float(a[0]), 0, float(a[1])), float(a[2]))
	b.target = b.target_goal
	b.pitch = float(a[3])
	b.yaw = float(a[4])
	await create_timer(1.0).timeout
	for id in b.unit_nodes:
		b.unit_nodes[id].visible = false
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(a[6])
	print("SALVATO ", a[6])
	quit()
