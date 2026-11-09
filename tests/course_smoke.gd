extends SceneTree
## Headless smoke test for the course state machine.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	var course = scene.get_node("Course")
	var player = scene.get_node("Player")
	var progress: Label = scene.get_node("UI/Progress")
	var start: Control = scene.get_node("UI/Start")
	print("start screen=%s player_physics=%s" % [start.visible, player.is_physics_processing()])
	scene._start_game()
	await process_frame
	print("after play screen=%s player_physics=%s" % [start.visible, player.is_physics_processing()])

	course._on_gate(player, -1)
	print("start: running=%s progress=%s" % [course.running, progress.text])

	course._on_gate(player, 1)
	print("out-of-order: progress=%s next=%d" % [progress.text, course.next_index])

	for i in range(3):
		course._on_gate(player, i)
		print("ring %d: next=%d progress=%s" % [i, course.next_index, progress.text])

	course.time = 42.3
	course._on_gate(player, -2)
	await process_frame
	print("finish: finished=%s time=%.1f best=%.1f" % [course.finished, course.time, course.best])
	print("panel=%s timer=%s" % [
		scene.get_node("UI/Finish").visible,
		scene.get_node("UI/Finish/Panel/Margin/VBox/Time").text,
	])

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://grapple_ghosts.cfg"))
	quit()
