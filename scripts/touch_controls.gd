extends Control
## Mobile controls: left joystick, right-side drag look, hold-to-grapple and jump.

var player

var _font: SystemFont

var _joy_idx := -1
var _joy_origin := Vector2.ZERO
var _joy_knob := Vector2.ZERO

var _look_idx := -1
var _grapple_idx := -1
var _jump_idx := -1
var _grapple_held := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "sans-serif"
	])
	visible = OS.has_feature("mobile")
	set_process_input(true)
	set_process(true)
	player = get_tree().get_first_node_in_group("player")


func setup(p: Node) -> void:
	player = p


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_touch(event.position, event.index, event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_drag(event.position, event.index, event.relative)
		get_viewport().set_input_as_handled()


func _touch(pos: Vector2, idx: int, pressed: bool) -> void:
	if pressed:
		if pos.distance_to(_grapple_center()) <= _grapple_radius():
			_grapple_idx = idx
			_grapple_held = true
			if player:
				player.set_touch_grapple(true)
			queue_redraw()
			return
		if pos.distance_to(_jump_center()) <= _jump_radius():
			_jump_idx = idx
			if player:
				player.queue_jump()
			queue_redraw()
			return
		if _joy_idx == -1 and pos.x < size.x * 0.45 and pos.y > size.y * 0.35:
			_joy_idx = idx
			_joy_origin = pos
			_joy_knob = pos
			if player:
				player.set_touch_move(Vector2.ZERO, false)
			queue_redraw()
			return
		if _look_idx == -1:
			_look_idx = idx
	else:
		if idx == _joy_idx:
			_joy_idx = -1
			_joy_origin = Vector2.ZERO
			_joy_knob = Vector2.ZERO
			if player:
				player.set_touch_move(Vector2.ZERO, false)
		if idx == _look_idx:
			_look_idx = -1
		if idx == _grapple_idx:
			_grapple_idx = -1
			_grapple_held = false
			if player:
				player.set_touch_grapple(false)
		if idx == _jump_idx:
			_jump_idx = -1
		queue_redraw()


func _drag(pos: Vector2, idx: int, rel: Vector2) -> void:
	if idx == _joy_idx:
		var v := (pos - _joy_origin) / _joy_radius()
		v = v.limit_length(1.0)
		_joy_knob = _joy_origin + v * _joy_radius()
		if player:
			player.set_touch_move(v, v.length() > 0.82)
		queue_redraw()
	elif idx == _look_idx:
		if player:
			player.add_touch_look(rel)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


# ---------------------------------------------------------------------------
# Layout (screen-relative so it works on different phone resolutions)
# ---------------------------------------------------------------------------

func _joy_radius() -> float:
	return size.y * 0.10


func _joy_home() -> Vector2:
	return Vector2(size.x * 0.16, size.y * 0.72)


func _grapple_center() -> Vector2:
	return Vector2(size.x - size.y * 0.16, size.y - size.y * 0.20)


func _grapple_radius() -> float:
	return size.y * 0.095


func _jump_center() -> Vector2:
	return Vector2(size.x - size.y * 0.34, size.y - size.y * 0.13)


func _jump_radius() -> float:
	return size.y * 0.065


func _draw() -> void:
	var base := _joy_origin if _joy_idx >= 0 else _joy_home()
	var r := _joy_radius()
	draw_circle(base, r, Color(0.02, 0.05, 0.08, 0.18))
	draw_arc(base, r, 0.0, TAU, 48, Color(1, 1, 1, 0.28), 2.0)
	var knob := _joy_knob if _joy_idx >= 0 else base
	var kr := r * 0.42
	draw_circle(knob, kr, Color(0.8, 0.95, 1.0, 0.28 if _joy_idx >= 0 else 0.13))
	draw_arc(knob, kr, 0.0, TAU, 36, Color(1, 1, 1, 0.55), 2.0)

	var gc := _grapple_center()
	var gr := _grapple_radius()
	draw_circle(gc, gr, Color(0.10, 0.55, 0.75, 0.30 if _grapple_held else 0.18))
	draw_arc(gc, gr, 0.0, TAU, 48,
		Color(0.45, 0.95, 1.0, 0.95 if _grapple_held else 0.65), 3.0)
	_center_text(gc, "GRAPPLE", int(size.y * 0.021), Color(0.85, 0.98, 1.0, 0.95))

	var jc := _jump_center()
	var jr := _jump_radius()
	draw_circle(jc, jr, Color(0.8, 0.9, 1.0, 0.14))
	draw_arc(jc, jr, 0.0, TAU, 40, Color(1, 1, 1, 0.55), 2.0)
	_center_text(jc, "JUMP", int(size.y * 0.018), Color(1, 1, 1, 0.85))


func _center_text(c: Vector2, txt: String, fs: int, color: Color) -> void:
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, c + Vector2(-w * 0.5, fs * 0.35), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
