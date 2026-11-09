extends SceneTree
## Partite automatiche IA contro IA: tutti gli scenari e tutte le situazioni.
## godot --headless --path . -s tests/autoplay.gd [-- <scenario> <situazione> <ripetizioni>]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var only := int(args[0]) if args.size() > 0 else 0
	var only_sit := args[1] if args.size() > 1 else ""
	var reps := int(args[2]) if args.size() > 2 else 1
	var t0 := Time.get_ticks_msec()
	var n := 0
	for s in SSScenari.list():
		if only > 0 and int(s["id"]) != only:
			continue
		for sit in s["situazioni"]:
			if only_sit != "" and sit != only_sit:
				continue
			for m in s["scontri"]:
				for r in reps:
					var e := SSEngine.new()
					e.headless = true
					e.anim = 0.0
					e.setup({"scenario": s["id"], "sit": sit, "match": m, "seed": 1000 + r * 7 + n, "seats": [{"ai": true}, {"ai": true}]})
					root.add_child(e)
					var tt := Time.get_ticks_msec()
					await e.run()
					n += 1
					print("%d %s %s seme %d: turno %d, %s [%d ms] %s" % [s["id"], sit, str(m), 1000 + r * 7 + n - 1, e.turn, str(e.result.get("reason", "?")), Time.get_ticks_msec() - tt, e.score_text()])
					e.queue_free()
	print("Partite: %d in %d ms" % [n, Time.get_ticks_msec() - t0])
	quit()
