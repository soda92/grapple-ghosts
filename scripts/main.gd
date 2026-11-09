extends Node3D
## Wires the course, UI and platform-specific hints.

var start_ui: Control
var _started := false


func _ready() -> void:
	if OS.has_feature("mobile"):
		Engine.max_fps = 60
	var touch := $UI/TouchControls
	touch.setup($Player)
	$Player.crosshair = $UI/Cross
	$Course.setup($Player, $UI)
	$UI/Reset.pressed.connect(_retry)
	$UI/Finish/Panel/Margin/VBox/Retry.pressed.connect(_retry)

	start_ui = $UI/Start
	start_ui.get_node("Panel/Margin/VBox/Play").pressed.connect(_start_game)
	var controls: Label = start_ui.get_node("Panel/Margin/VBox/Controls")
	controls.text = "LEFT STICK move  ·  DRAG look  ·  HOLD GRAPPLE  ·  JUMP" \
		if OS.has_feature("mobile") else \
		"WASD move  ·  SHIFT sprint  ·  SPACE jump  ·  HOLD RMB to grapple"
	var course = $Course
	var best_text: String = course.format_time(course.best) if course.best > 0.0 else "--:--"
	start_ui.get_node("Panel/Margin/VBox/Best").text = "BEST  " + best_text

	_set_hud_visible(false)
	$Player.set_physics_process(false)
	$Player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.has_feature("mobile"):
		$UI/Hint.text = "Left stick move · drag right to look · hold GRAPPLE to swing · JUMP"


func _start_game() -> void:
	if _started:
		return
	_started = true
	start_ui.visible = false
	_set_hud_visible(true)
	$Player.set_physics_process(true)
	$Player.set_process_unhandled_input(true)
	if OS.has_feature("mobile"):
		$UI/TouchControls.visible = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_hud_visible(on: bool) -> void:
	for path in ["Title", "Timer", "Best", "Progress", "Hint", "Reset"]:
		var n := $UI.get_node(path)
		if n != null:
			n.visible = on
	$UI/Cross.visible = on
	$UI/TouchControls.visible = on and OS.has_feature("mobile")


func _retry() -> void:
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if start_ui != null and start_ui.visible:
		if event is InputEventKey and event.pressed and not event.echo \
				and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			_start_game()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_R:
		_retry()
