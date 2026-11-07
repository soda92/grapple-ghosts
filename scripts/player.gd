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

var _rope: ImmediateMesh
var _line: MeshInstance3D

@onready var cam: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_rope = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _rope
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.95, 1.0)
	_line.material_override = mat
	add_child(_line)


func _unhandled_input(event: InputEvent) -> void:
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
	var input := Vector2(
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
		var speed := SPRINT if Input.is_key_pressed(KEY_SHIFT) else SPEED
		velocity.x = wish.x * speed
		velocity.z = wish.z * speed
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif Input.is_key_pressed(KEY_SPACE):
			velocity.y = JUMP

	move_and_slide()
	_draw_rope()


func _try_grapple() -> void:
	var from := cam.global_position
	var to := from - cam.global_basis.z * RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	anchor = hit["position"]
	grappling = true


func _release() -> void:
	grappling = false
	_draw_rope()


func _draw_rope() -> void:
	_rope.clear_surfaces()
	if not grappling:
		return
	var from := cam.global_position \
		+ cam.global_basis.x * 0.22 \
		- cam.global_basis.y * 0.18 \
		- cam.global_basis.z * 0.18
	_rope.surface_begin(Mesh.PRIMITIVE_LINES)
	_rope.surface_add_vertex(from)
	_rope.surface_add_vertex(anchor)
	_rope.surface_end()
