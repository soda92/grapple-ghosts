extends CharacterBody3D
## First-person grapple prototype: WASD + mouse, hold right mouse to grapple.

const SPEED := 8.0
const SPRINT := 13.0
const JUMP := 6.0
const GRAVITY := 20.0
const LOOK := 0.0024
const RANGE := 90.0
const PULL := 38.0
const AIR_CONTROL := 5.0

var pitch := 0.0
var anchor := Vector3.ZERO
var grappling := false

var mobile := OS.has_feature("mobile")
var crosshair: Label
var touch_move := Vector2.ZERO
var touch_sprint := false
var touch_jump := false
var _aim_state := false

var _rope: BoxMesh
var _line: MeshInstance3D
var _aim_q: PhysicsRayQueryParameters3D
var _aim_t := 0.0

@onready var cam: Camera3D = $Camera3D


func _ready() -> void:
	if not mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_rope = BoxMesh.new()
	_rope.size = Vector3(0.035, 0.035, 1.0)
	_line = MeshInstance3D.new()
	_line.mesh = _rope
	_line.top_level = true
	_line.visible = false
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.95, 1.0)
	_line.material_override = mat
	add_child(_line)

	_aim_q = PhysicsRayQueryParameters3D.new()
	_aim_q.collision_mask = 3
	_aim_q.exclude = [get_rid()]


func _unhandled_input(event: InputEvent) -> void:
	if mobile:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * LOOK)
		pitch = clampf(pitch - event.relative.y * LOOK, -1.45, 1.45)
		cam.rotation.x = pitch
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_try_grapple()
			else:
				_release()
		elif event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input := touch_move
	if not mobile:
		input = Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		).limit_length(1.0)
	var wish := global_transform.basis * Vector3(input.x, 0.0, input.y)

	if grappling:
		var to := anchor - global_position
		if to.length() < 2.0:
			_release()
		else:
			velocity += to.normalized() * PULL * delta
			velocity += wish * AIR_CONTROL * delta
			var flat := Vector2(velocity.x, velocity.z).limit_length(38.0)
			velocity.x = flat.x
			velocity.z = flat.y
	else:
		var sprint := touch_sprint if mobile else Input.is_key_pressed(KEY_SHIFT)
		var speed := SPRINT if sprint else SPEED
		velocity.x = wish.x * speed
		velocity.z = wish.z * speed
		var jump := touch_jump if mobile else Input.is_key_pressed(KEY_SPACE)
		if mobile:
			touch_jump = false
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif jump:
			velocity.y = JUMP

	move_and_slide()
	_draw_rope()
	_update_aim(delta)


func set_touch_move(v: Vector2, sprint: bool) -> void:
	touch_move = v.limit_length(1.0)
	touch_sprint = sprint


func add_touch_look(rel: Vector2) -> void:
	rotate_y(-rel.x * LOOK * 1.45)
	pitch = clampf(pitch - rel.y * LOOK * 1.45, -1.45, 1.45)
	cam.rotation.x = pitch


func queue_jump() -> void:
	touch_jump = true


func set_touch_grapple(on: bool) -> void:
	if on:
		if not grappling:
			_try_grapple()
	else:
		_release()


func _aim_ray() -> Dictionary:
	_aim_q.from = cam.global_position
	_aim_q.to = cam.global_position - cam.global_basis.z * RANGE
	return get_world_3d().direct_space_state.intersect_ray(_aim_q)


func _update_aim(delta: float) -> void:
	if crosshair == null:
		return
	_aim_t -= delta
	if _aim_t > 0.0:
		return
	_aim_t = 0.04
	var hit := _aim_ray()
	var aim := not hit.is_empty()
	if aim == _aim_state:
		return
	_aim_state = aim
	crosshair.add_theme_color_override(
		"font_color",
		Color(0.35, 1.0, 1.0, 1.0) if aim else Color(0.82, 0.95, 1.0, 0.9)
	)


func _try_grapple() -> void:
	var hit := _aim_ray()
	if hit.is_empty():
		return
	anchor = hit["position"]
	grappling = true


func _release() -> void:
	grappling = false
	_draw_rope()


func _draw_rope() -> void:
	if not grappling:
		_line.visible = false
		return
	var from := cam.global_position \
		+ cam.global_basis.x * 0.22 \
		- cam.global_basis.y * 0.18 \
		- cam.global_basis.z * 0.18
	var delta := anchor - from
	var length := delta.length()
	if length < 0.02:
		_line.visible = false
		return
	var dir := delta / length
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	_line.global_transform = Transform3D(
		basis.scaled(Vector3(1.0, 1.0, length)), (from + anchor) * 0.5)
	_line.visible = true
