extends Node3D
## Wires the course, UI and platform-specific hints.

func _ready() -> void:
	if OS.has_feature("mobile"):
		Engine.max_fps = 60
	var touch := $UI/TouchControls
	touch.setup($Player)
	$Player.crosshair = $UI/Cross
	$Course.setup($Player, $UI)
	$UI/Reset.pressed.connect(_retry)
	$UI/Finish/Panel/Margin/VBox/Retry.pressed.connect(_retry)
	if OS.has_feature("mobile"):
		$UI/Hint.text = "Left stick move · drag right to look · hold GRAPPLE to swing · JUMP"


func _retry() -> void:
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_R:
		_retry()
