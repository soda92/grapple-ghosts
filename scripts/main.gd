extends Node3D
## Wires the mobile controls and swaps the hint text per platform.

func _ready() -> void:
	var touch := $UI/TouchControls
	touch.setup($Player)
	if OS.has_feature("mobile"):
		$UI/Hint.text = "Left stick move · drag right to look · hold GRAPPLE to swing · JUMP"
