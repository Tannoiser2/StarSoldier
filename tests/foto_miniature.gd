extends SceneTree
## Fotografa le miniature in assets/miniature in fila (serve xvfb-run).
func _init() -> void:
	root.size = Vector2i(1800, 500)
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.85, 0.8, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	w.add_child(env)
	var sun := DirectionalLight3D.new(); w.add_child(sun); sun.rotation = Vector3(-0.7, -0.6, 0)
	var cam := Camera3D.new(); w.add_child(cam); cam.position = Vector3(8, 1.6, 9); cam.look_at(Vector3(8, 0.9, 0)); cam.fov = 50
	var names := ["piattaforma_umana", "piattaforma_lchal", "piattaforma_rame", "umani_leggero", "umani_pesante", "lchal_leggero", "lchal_pesante", "rame", "xenofobi", "civili", "dinkblog", "missile"]
	var i := 0
	for n in names:
		var s: PackedScene = load("res://assets/miniature/%s.glb" % n)
		var m := s.instantiate() as Node3D
		w.add_child(m)
		m.position = Vector3(i * 2.0, 1.0, 0)
		var lb := Label3D.new(); lb.text = n; lb.font_size = 48; lb.pixel_size = 0.004; lb.position = Vector3(i * 2.0, -0.2, 0.5); lb.modulate = Color.BLACK; w.add_child(lb)
		i += 1
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png("/tmp/miniature.png")
	quit()
