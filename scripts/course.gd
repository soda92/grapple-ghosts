extends Node3D
## Grapple course: start gate, ordered rings, medal targets, splits,
## best-time ghost replay and a finish panel.

const START_POS := Vector3(0.0, 2.6, 8.0)
const RINGS := [
	{"pos": Vector3(-22.0, 13.2, -18.0), "yaw": 0.0, "label": "1"},
	{"pos": Vector3(24.0, 17.0, -34.0), "yaw": PI * 0.5, "label": "2"},
	{"pos": Vector3(12.0, 12.4, -20.0), "yaw": PI * 0.5, "label": "3"},
]
const FINISH_POS := Vector3(-2.0, 23.2, -38.0)
const CONFIG_PATH := "user://grapple_ghosts.cfg"

const GOLD_TIME := 35.0
const SILVER_TIME := 45.0
const BRONZE_TIME := 60.0
const GHOST_HZ := 20.0

var player: Node3D
var ui: CanvasLayer
var timer_label: Label
var best_label: Label
var progress_label: Label
var split_label: Label
var finish_panel: Control
var finish_time: Label
var finish_best: Label
var finish_new: Label
var finish_medal: Label
var ghost_toggle: Button
var touch_controls: Control

var rings: Array[Area3D] = []
var ring_mats: Array[StandardMaterial3D] = []
var ring_labels: Array[Label3D] = []
var ring_orbs: Array[StandardMaterial3D] = []

var next_index := 0
var running := false
var finished := false
var time := 0.0
var best := 0.0
var _timer_t := 0.0

var splits: Array[float] = []
var best_splits: Array[float] = []
var ghost_enabled := true

var _rec_accum := 0.0
var rec_points: Array[Vector3] = []
var rec_times: Array[float] = []
var rec_yaws: Array[float] = []
var best_points: Array[Vector3] = []
var best_times: Array[float] = []
var best_yaws: Array[float] = []

var ghost_visual: Node3D
var _ghost_i := 0


func _ready() -> void:
	_load_best()
	_build_course()
	_build_ghost()


func setup(p: Node3D, u: CanvasLayer) -> void:
	player = p
	ui = u
	timer_label = ui.get_node("Timer")
	best_label = ui.get_node("Best")
	progress_label = ui.get_node("Progress")
	split_label = ui.get_node_or_null("Split")
	finish_panel = ui.get_node("Finish")
	finish_time = finish_panel.get_node("Panel/Margin/VBox/Time")
	finish_best = finish_panel.get_node("Panel/Margin/VBox/Best")
	finish_new = finish_panel.get_node("Panel/Margin/VBox/New")
	finish_medal = finish_panel.get_node_or_null("Panel/Margin/VBox/Medal")
	touch_controls = ui.get_node("TouchControls")
	ghost_toggle = ui.get_node_or_null("Start/Panel/Margin/VBox/Ghost")
	if ghost_toggle != null:
		ghost_toggle.pressed.connect(_toggle_ghost)
	var target_label: Label = ui.get_node_or_null("Start/Panel/Margin/VBox/Targets")
	if target_label != null:
		target_label.text = targets_text()
	timer_label.text = _fmt(0.0)
	progress_label.text = "CROSS THE START GATE"
	_update_best_label()
	_refresh_rings()
	_refresh_ghost_toggle()


func _process(delta: float) -> void:
	if not running or finished:
		return
	time += delta
	_rec_accum += delta
	while _rec_accum >= 1.0 / GHOST_HZ:
		_rec_accum -= 1.0 / GHOST_HZ
		_record_sample(time)
	_update_ghost()
	_timer_t += delta
	if _timer_t >= 0.05:
		_timer_t = 0.0
		if timer_label != null:
			timer_label.text = _fmt(time)


func _build_course() -> void:
	_make_gate(START_POS, 0.0, "START", Color(0.70, 0.95, 1.0), -1)
	for i in range(RINGS.size()):
		var d: Dictionary = RINGS[i]
		_make_gate(d["pos"], d["yaw"], d["label"], Color(0.45, 0.95, 1.0), i)
	_make_gate(FINISH_POS, PI * 0.5, "FINISH", Color(1.0, 0.80, 0.30), -2)


func _build_ghost() -> void:
	ghost_visual = Node3D.new()
	ghost_visual.name = "BestGhost"
	ghost_visual.visible = false
	add_child(ghost_visual)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.30, 0.92, 1.0, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.45
	capsule.radial_segments = 8
	capsule.rings = 4
	body.mesh = capsule
	body.material_override = mat
	body.position.y = 0.85
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_visual.add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.27
	sphere.height = 0.54
	sphere.radial_segments = 8
	sphere.rings = 4
	head.mesh = sphere
	head.material_override = mat
	head.position.y = 1.72
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_visual.add_child(head)


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

	var anchor := StaticBody3D.new()
	anchor.collision_layer = 2
	anchor.collision_mask = 0
	var anchor_col := CollisionShape3D.new()
	var anchor_sphere := SphereShape3D.new()
	anchor_sphere.radius = 0.9
	anchor_col.shape = anchor_sphere
	anchor.add_child(anchor_col)
	area.add_child(anchor)

	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.22
	orb_mesh.height = 0.44
	orb_mesh.radial_segments = 16
	orb_mesh.rings = 8
	orb.mesh = orb_mesh
	var orb_mat := StandardMaterial3D.new()
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_mat.albedo_color = color
	orb_mat.emission_enabled = true
	orb_mat.emission = color
	orb_mat.emission_energy_multiplier = 3.0
	orb.material_override = orb_mat
	area.add_child(orb)

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
		ring_orbs.append(orb_mat)


func _on_gate(body: Node, index: int) -> void:
	if player == null or body != player:
		return

	if index == -1:
		if running or finished:
			return
		running = true
		time = 0.0
		_timer_t = 0.0
		next_index = 0
		_begin_run()
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
		splits.append(time)
		next_index += 1
		_update_split(index)
		if next_index >= rings.size():
			progress_label.text = "REACH THE FINISH"
		else:
			progress_label.text = "RING %d / %d" % [next_index + 1, rings.size()]
		_refresh_rings()


func _begin_run() -> void:
	splits.clear()
	rec_points.clear()
	rec_times.clear()
	rec_yaws.clear()
	_rec_accum = 0.0
	_ghost_i = 0
	_record_sample(0.0)
	if split_label != null:
		split_label.visible = false
	_update_ghost()


func _record_sample(t: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	rec_points.append(player.global_position)
	rec_times.append(t)
	rec_yaws.append(player.rotation.y)


func _update_ghost() -> void:
	if ghost_visual == null:
		return
	if not ghost_enabled or not running or finished \
			or best_points.size() < 2 or best_times.size() != best_points.size() \
			or best_yaws.size() != best_points.size():
		ghost_visual.visible = false
		return
	ghost_visual.visible = true
	var t := time
	var i := _ghost_i
	while i < best_times.size() - 2 and best_times[i + 1] <= t:
		i += 1
	_ghost_i = i
	var t0 := best_times[i]
	var t1 := best_times[i + 1]
	var a := clampf((t - t0) / maxf(0.001, t1 - t0), 0.0, 1.0)
	ghost_visual.global_position = best_points[i].lerp(best_points[i + 1], a)
	ghost_visual.rotation.y = lerp_angle(best_yaws[i], best_yaws[i + 1], a)


func _update_split(index: int) -> void:
	if split_label == null:
		return
	var line := "RING %d   %s" % [index + 1, _fmt(time)]
	var col := Color(0.55, 0.95, 1.0)
	if best_splits.size() > index:
		var d := time - best_splits[index]
		line += "   %s%.2f" % ["-" if d < 0.0 else "+", absf(d)]
		col = Color(0.55, 1.0, 0.65) if d < 0.0 else Color(1.0, 0.55, 0.45)
	split_label.text = line
	split_label.add_theme_color_override("font_color", col)
	split_label.visible = true


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
		ring_orbs[i].albedo_color = c
		ring_orbs[i].emission = c


func _finish() -> void:
	finished = true
	running = false
	timer_label.text = _fmt(time)
	_record_sample(time)
	if ghost_visual != null:
		ghost_visual.visible = false

	var new_best := best <= 0.0 or time < best
	if new_best:
		best = time
		best_splits.clear()
		for s in splits:
			best_splits.append(s)
		best_points.clear()
		best_points.append_array(rec_points)
		best_times.clear()
		best_times.append_array(rec_times)
		best_yaws.clear()
		best_yaws.append_array(rec_yaws)
		_save_best()
		_update_best_label()
	finish_new.visible = new_best

	var medal := _medal_for(time)
	if finish_medal != null:
		finish_medal.text = medal["label"]
		finish_medal.add_theme_color_override("font_color", medal["color"])

	finish_time.text = "TIME   " + _fmt(time)
	finish_best.text = "BEST   " + _fmt(best)
	progress_label.text = "FINISH"
	if split_label != null:
		split_label.visible = false
	finish_panel.visible = true

	if player != null:
		player.set_physics_process(false)
	if touch_controls != null:
		touch_controls.visible = false
		touch_controls.set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _medal_for(t: float) -> Dictionary:
	if t <= GOLD_TIME:
		return {"label": "GOLD MEDAL", "color": Color(1.0, 0.82, 0.30)}
	if t <= SILVER_TIME:
		return {"label": "SILVER MEDAL", "color": Color(0.82, 0.90, 1.0)}
	if t <= BRONZE_TIME:
		return {"label": "BRONZE MEDAL", "color": Color(0.86, 0.55, 0.34)}
	return {"label": "NO MEDAL", "color": Color(0.65, 0.70, 0.76)}


func targets_text() -> String:
	return "GOLD %s   ·   SILVER %s   ·   BRONZE %s" % [
		_fmt(GOLD_TIME), _fmt(SILVER_TIME), _fmt(BRONZE_TIME)]


func _update_best_label() -> void:
	if best_label == null:
		return
	best_label.text = "BEST  " + (_fmt(best) if best > 0.0 else "--:--")


func format_time(t: float) -> String:
	return _fmt(t)


func _fmt(t: float) -> String:
	var m := int(t) / 60
	var s := t - m * 60.0
	return "%02d:%04.1f" % [m, s]


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	best = float(cfg.get_value("course", "best", 0.0))
	ghost_enabled = bool(cfg.get_value("course", "ghost_enabled", true))
	var pts = cfg.get_value("course", "best_points", [])
	var ts = cfg.get_value("course", "best_times", [])
	var ys = cfg.get_value("course", "best_yaws", [])
	if pts is Array and ts is Array and ys is Array:
		for p in pts:
			if p is Vector3:
				best_points.append(p)
		for t in ts:
			best_times.append(float(t))
		for y in ys:
			best_yaws.append(float(y))
	if best_points.size() != best_times.size() or best_points.size() != best_yaws.size():
		best_points.clear()
		best_times.clear()
		best_yaws.clear()
	var ss = cfg.get_value("course", "best_splits", [])
	if ss is Array:
		for s in ss:
			best_splits.append(float(s))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("course", "best", best)
	cfg.set_value("course", "ghost_enabled", ghost_enabled)
	cfg.set_value("course", "best_points", best_points)
	cfg.set_value("course", "best_times", best_times)
	cfg.set_value("course", "best_yaws", best_yaws)
	cfg.set_value("course", "best_splits", best_splits)
	cfg.save(CONFIG_PATH)


func _toggle_ghost() -> void:
	ghost_enabled = not ghost_enabled
	_save_best()
	_refresh_ghost_toggle()


func _refresh_ghost_toggle() -> void:
	if ghost_toggle == null:
		return
	ghost_toggle.disabled = best_points.size() < 2
	ghost_toggle.text = "GHOST  ON" if ghost_enabled else "GHOST  OFF"
	if best_points.size() < 2:
		ghost_toggle.text = "GHOST  --"
