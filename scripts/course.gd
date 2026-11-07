extends Node3D
## 60-second course: cross the start gate, touch three rings in order, finish on the tower.

const START_POS := Vector3(0.0, 2.6, 8.0)
const RINGS := [
	{"pos": Vector3(-22.0, 13.2, -18.0), "yaw": 0.0, "label": "1"},
	{"pos": Vector3(24.0, 17.0, -34.0), "yaw": PI * 0.5, "label": "2"},
	{"pos": Vector3(12.0, 12.4, -20.0), "yaw": PI * 0.5, "label": "3"},
]
const FINISH_POS := Vector3(-2.0, 23.2, -38.0)
const CONFIG_PATH := "user://grapple_ghosts.cfg"

var player: Node3D
var ui: CanvasLayer
var timer_label: Label
var best_label: Label
var progress_label: Label
var finish_panel: Control
var finish_time: Label
var finish_best: Label
var finish_new: Label
var touch_controls: Control

var rings: Array[Area3D] = []
var ring_mats: Array[StandardMaterial3D] = []
var ring_labels: Array[Label3D] = []

var next_index := 0
var running := false
var finished := false
var time := 0.0
var best := 0.0


func _ready() -> void:
	_load_best()
	_build_course()


func setup(p: Node3D, u: CanvasLayer) -> void:
	player = p
	ui = u
	timer_label = ui.get_node("Timer")
	best_label = ui.get_node("Best")
	progress_label = ui.get_node("Progress")
	finish_panel = ui.get_node("Finish")
	finish_time = finish_panel.get_node("Panel/Margin/VBox/Time")
	finish_best = finish_panel.get_node("Panel/Margin/VBox/Best")
	finish_new = finish_panel.get_node("Panel/Margin/VBox/New")
	touch_controls = ui.get_node("TouchControls")
	timer_label.text = _fmt(0.0)
	progress_label.text = "CROSS THE START GATE"
	_update_best_label()
	_refresh_rings()


func _process(delta: float) -> void:
	if running and not finished:
		time += delta
		if timer_label != null:
			timer_label.text = _fmt(time)


func _build_course() -> void:
	_make_gate(START_POS, 0.0, "START", Color(0.70, 0.95, 1.0), -1)
	for i in range(RINGS.size()):
		var d: Dictionary = RINGS[i]
		_make_gate(d["pos"], d["yaw"], d["label"], Color(0.45, 0.95, 1.0), i)
	_make_gate(FINISH_POS, PI * 0.5, "FINISH", Color(1.0, 0.80, 0.30), -2)


func _make_gate(pos: Vector3, yaw: float, txt: String, color: Color, index: int) -> void:
	var area := Area3D.new()
	area.position = pos
	area.rotation.y = yaw
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	add_child(area)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.6
	shape.shape = sphere
	area.add_child(shape)

	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.65
	torus.outer_radius = 2.25
	torus.rings = 32
	torus.ring_segments = 16
	mesh.mesh = torus
	mesh.rotation.x = PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	area.add_child(mesh)

	var label := Label3D.new()
	label.text = txt
	label.position = Vector3(0.0, 3.0, 0.0)
	label.font_size = 72
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	area.add_child(label)

	area.body_entered.connect(_on_gate.bind(index))

	if index >= 0:
		rings.append(area)
		ring_mats.append(mat)
		ring_labels.append(label)


func _on_gate(body: Node, index: int) -> void:
	if player == null or body != player:
		return

	if index == -1:
		if running or finished:
			return
		running = true
		time = 0.0
		next_index = 0
		progress_label.text = "RING 1 / %d" % rings.size()
		_refresh_rings()
	elif index == -2:
		if not running or finished:
			return
		if next_index < rings.size():
			progress_label.text = "RING %d FIRST" % (next_index + 1)
			return
		_finish()
	else:
		if not running or finished:
			return
		if index < next_index:
			return
		if index > next_index:
			progress_label.text = "RING %d FIRST" % (next_index + 1)
			return
		next_index += 1
		if next_index >= rings.size():
			progress_label.text = "REACH THE FINISH"
		else:
			progress_label.text = "RING %d / %d" % [next_index + 1, rings.size()]
		_refresh_rings()


func _refresh_rings() -> void:
	for i in range(rings.size()):
		var c: Color
		if i < next_index:
			c = Color(0.35, 1.0, 0.55)
		elif i == next_index:
			c = Color(0.45, 0.95, 1.0)
		else:
			c = Color(0.55, 0.62, 0.70)
		ring_mats[i].albedo_color = c
		ring_mats[i].emission = c
		ring_labels[i].modulate = c


func _finish() -> void:
	finished = true
	running = false
	timer_label.text = _fmt(time)

	var new_best := best <= 0.0 or time < best
	if new_best:
		best = time
		_save_best()
		_update_best_label()
	finish_new.visible = new_best

	finish_time.text = "TIME   " + _fmt(time)
	finish_best.text = "BEST   " + _fmt(best)
	progress_label.text = "FINISH"
	finish_panel.visible = true

	if player != null:
		player.set_physics_process(false)
	if touch_controls != null:
		touch_controls.visible = false
		touch_controls.set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _update_best_label() -> void:
	if best_label == null:
		return
	best_label.text = "BEST  " + (_fmt(best) if best > 0.0 else "--:--")


func _fmt(t: float) -> String:
	var m := int(t) / 60
	var s := t - m * 60.0
	return "%02d:%04.1f" % [m, s]


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		best = float(cfg.get_value("course", "best", 0.0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("course", "best", best)
	cfg.save(CONFIG_PATH)
