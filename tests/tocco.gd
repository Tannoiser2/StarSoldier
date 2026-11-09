extends SceneTree
## Simula il tocco su iPad sulla mappa: un dito trascina, due dita pizzicano e ruotano, un tocco seleziona.
func _touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)

func _drag(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)

func _init() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game({"scenario": 30, "sit": "P", "match": [0, 1], "seats": [{"ai": false}, {"ai": true}], "style": "originale", "anim": 5.0, "seed": 3})
	await create_timer(2.0).timeout
	var b = main.current.board
	var t0: Vector3 = b.target_goal
	var c := Vector2(800, 450)
	# un dito: trascina
	_touch(0, c, true)
	for k in 10:
		await process_frame
		_drag(0, c + Vector2(20 * (k + 1), 10 * (k + 1)), Vector2(20, 10))
	_touch(0, c + Vector2(200, 100), false)
	await process_frame
	print("pan: ", t0, " -> ", b.target_goal, " ", "OK" if b.target_goal.distance_to(t0) > 1.0 else "NO")
	# due dita: pizzico e rotazione
	var d0: float = b.dist
	var y0: float = b.yaw
	_touch(0, c - Vector2(100, 0), true)
	_touch(1, c + Vector2(100, 0), true)
	await process_frame
	var p1 := c + Vector2(100, 0)
	for k in 10:
		var np := c + Vector2(100 + 15 * (k + 1), 8 * (k + 1))
		_drag(1, np, np - p1)
		p1 = np
		await process_frame
	_touch(1, p1, false)
	_touch(0, c - Vector2(100, 0), false)
	await process_frame
	print("zoom: ", d0, " -> ", b.dist, " ", "OK" if b.dist < d0 - 1.0 else "NO")
	print("rotazione: ", y0, " -> ", b.yaw, " ", "OK" if absf(b.yaw - y0) > 0.1 else "NO")
	# un tocco breve su un pannello non deve muovere la mappa
	var tg: Vector3 = b.target_goal
	_touch(0, Vector2(100, 400), true)
	_drag(0, Vector2(130, 430), Vector2(30, 30))
	_touch(0, Vector2(130, 430), false)
	await process_frame
	print("sopra il pannello: ", "OK" if b.target_goal == tg else "NO")
	# mouse: rotella e trascinamento
	var d1: float = b.dist
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	w.pressed = true
	w.position = c
	Input.parse_input_event(w)
	await process_frame
	var tg2: Vector3 = b.target_goal
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = c
	Input.parse_input_event(mb)
	for k in 5:
		var mm := InputEventMouseMotion.new()
		mm.position = c + Vector2(10 * (k + 1), 0)
		mm.relative = Vector2(10, 0)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mm)
		await process_frame
	print("mouse: zoom ", "OK" if b.dist < d1 else "NO", ", trascina ", "OK" if b.target_goal != tg2 else "NO")
	quit()
