extends SceneTree
## Tutte le partite IA contro IA con il registro completo (per controllare che ogni regola entri in gioco).
func _init() -> void:
	var out := FileAccess.open("/tmp/registro_tutto.txt", FileAccess.WRITE)
	var n := 0
	for s in SSScenari.list():
		for sit in s["situazioni"]:
			for m in s["scontri"]:
				for r in 2:
					var e := SSEngine.new()
					e.headless = true
					e.anim = 0.0
					e.setup({"scenario": s["id"], "sit": sit, "match": m, "seed": 77 + n, "seats": [{"ai": true}, {"ai": true}]})
					root.add_child(e)
					await e.run()
					out.store_string("=== %d %s %s\n" % [s["id"], sit, str(m)])
					out.store_string("\n".join(e.log_lines) + "\n")
					n += 1
					e.queue_free()
	out.close()
	print("partite ", n)
	quit()
