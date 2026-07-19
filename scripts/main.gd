extends Node2D
## World bootstrap for M1: parallax background, flat test ground (M3 replaces
## this with deformable terrain), the walker, camera, HUD, and debug input.
## Run with `-- selftest` in user args to execute the headless M1 gate instead.

# ---------------------------------------------------------------- tunables ---
@export var ground_y := 600.0          # world y of the ground surface
@export var ground_half_width := 20000.0
@export var camera_zoom := 1.0
@export var camera_cursor_lead := 0.10 # how far the camera drifts toward the cursor
@export var arena_half_width := 2048.0 # deformable-terrain span; bedrock beyond
@export var runner_interval := 6.0     # s between runner spawns (escalates down)
@export var runner_interval_min := 2.5
@export var runner_escalation := 0.96  # interval multiplier per spawn
@export var paratrooper_interval := 11.0
@export var burrower_interval := 17.0
# ------------------------------------------------------------ end tunables ---

const RunnerScript := preload("res://scripts/runner.gd")
const ParatrooperScript := preload("res://scripts/paratrooper.gd")
const BurrowerScript := preload("res://scripts/burrower.gd")

var walker: Node2D   # the player (player.gd); legacy walker.gd kept in repo
var camera: Camera2D
var hud_label: Label
var death_label: Label
var crosshair: Sprite2D
var terrain: Terrain
var kills := 0
var _shake := 0.0
var _next_runner := 0.0
var _next_paratrooper := 0.0
var _next_burrower := 0.0
var selftest_mode := false   # true when a script (selftest/screenshot) drives input
var _shot_dir := ""
var _shot_t := 0.0
var _shots_taken := 0
var _shot_spawned := false


func _ready() -> void:
	add_to_group("game")
	_next_runner = 2.5
	_next_paratrooper = paratrooper_interval
	_next_burrower = burrower_interval
	_build_background()
	_build_ground()
	_build_walker()
	_build_camera()
	_build_hud()
	if "selftest" in OS.get_cmdline_user_args():
		selftest_mode = true
		var selftest := preload("res://scripts/selftest.gd").new()
		selftest.walker = walker
		add_child(selftest)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("screenshot="):   # debug: capture stand + walk frames
			selftest_mode = true
			_shot_dir = arg.trim_prefix("screenshot=")


func _build_background() -> void:
	# Sky: screen-space, always fills the viewport, behind everything.
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -200
	var sky := TextureRect.new()
	sky.texture = Assets.tex("res://assets/bg/sky.png")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_layer.add_child(sky)
	add_child(sky_layer)

	# Silhouette layers: horizontal parallax only, bottoms sitting on the
	# ground line so the skyline reads as terrain in the distance.
	var bg := ParallaxBackground.new()
	add_child(bg)
	var layers := [
		["res://assets/bg/parallax_far.png", 0.2, 0.0],
		["res://assets/bg/parallax_near.png", 0.5, 60.0],
	]
	for entry in layers:
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(entry[1], 1.0)
		layer.motion_mirroring = Vector2(1920, 0)
		var sprite := Sprite2D.new()
		sprite.texture = Assets.tex(entry[0])
		sprite.centered = false
		sprite.position = Vector2(-960, ground_y + entry[2] - 1080)
		layer.add_child(sprite)
		bg.add_child(layer)


func _build_ground() -> void:
	# Deformable arena (M3): material grid centered on spawn.
	terrain = Terrain.new()
	terrain.position = Vector2(-arena_half_width, ground_y)
	add_child(terrain)

	# Bedrock beyond and below the arena: indestructible flat ground.
	var depth: float = terrain.rows * terrain.cell
	for def in [
		[Vector2(-ground_half_width, ground_y), Vector2(-arena_half_width, ground_y + 400.0)],
		[Vector2(arena_half_width, ground_y), Vector2(ground_half_width, ground_y + 400.0)],
		[Vector2(-arena_half_width, ground_y + depth), Vector2(arena_half_width, ground_y + depth + 80.0)],
	]:
		var a: Vector2 = def[0]
		var b: Vector2 = def[1]
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var mat := PhysicsMaterial.new()
		mat.friction = 1.0
		body.physics_material_override = mat
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = b - a
		shape.shape = rect
		shape.position = (a + b) / 2.0
		body.add_child(shape)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
		poly.texture = Assets.tex("res://assets/terrain/rock.png")
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		body.add_child(poly)
		add_child(body)


func _build_walker() -> void:
	walker = preload("res://scenes/player.tscn").instantiate()
	# Local origin is the waist; feet soles sit at +FOOT_BOTTOM_Y.
	walker.position = Vector2(0, ground_y - Player.FOOT_BOTTOM_Y - 4.0)
	add_child(walker)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	add_child(camera)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	hud_label = Label.new()
	hud_label.position = Vector2(24, 20)
	hud_label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(hud_label)
	crosshair = Sprite2D.new()
	crosshair.texture = Assets.tex("res://assets/ui/crosshair.png")
	canvas.add_child(crosshair)
	death_label = Label.new()
	death_label.text = "WRECKED  —  press R"
	death_label.add_theme_font_size_override("font_size", 64)
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.visible = false
	canvas.add_child(death_label)
	add_child(canvas)
	if not selftest_mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(delta: float) -> void:
	if not selftest_mode:
		walker.input_dir = Input.get_axis("move_left", "move_right")
		walker.aim_point = get_global_mouse_position()
		walker.firing = Input.is_action_pressed("fire")
		crosshair.position = get_viewport().get_mouse_position()
	if _shot_dir != "":
		_shot_t += delta
		walker.input_dir = 0.0 if _shot_t < 2.0 else (1.0 if _shot_t < 3.72 else -1.0)
		walker.aim_point = walker.hip_position() + Vector2(430, 230)   # rake the dirt ahead
		walker.firing = _shot_t > 2.5
		if not _shot_spawned and _shot_t > 2.2:
			_shot_spawned = true
			var r := RunnerScript.new()
			r.position = walker.hip_position() + Vector2(780, -300)
			add_child(r)
		if (_shots_taken == 0 and _shot_t > 1.5) or (_shots_taken == 1 and _shot_t > 4.0):
			_shots_taken += 1
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/shot%d.png" % [_shot_dir, _shots_taken])
			print("saved shot%d" % _shots_taken)
			if _shots_taken == 2:
				get_tree().quit()
	if not selftest_mode:
		_run_spawner(delta)
	camera.position = walker.hip_position() + Vector2(0, -120) \
			+ (walker.aim_point - walker.hip_position()) * camera_cursor_lead
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 3.0, 0.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0
	else:
		camera.offset = Vector2.ZERO
	death_label.visible = walker.dead
	hud_label.text = "A/D move  ·  aim  ·  LMB fire  ·  R reset      HP %d   kills %d" % [
		int(walker.hp), kills]


func _run_spawner(delta: float) -> void:
	if walker.dead:
		return
	_next_runner -= delta
	_next_paratrooper -= delta
	_next_burrower -= delta
	if _next_runner <= 0.0:
		runner_interval = maxf(runner_interval * runner_escalation, runner_interval_min)
		_next_runner = runner_interval
		var r := RunnerScript.new()
		var side := 1.0 if randf() < 0.5 else -1.0
		r.position = walker.hip_position() + Vector2(side * randf_range(850, 1150), -400)
		add_child(r)
	if _next_paratrooper <= 0.0:
		_next_paratrooper = paratrooper_interval
		var p := ParatrooperScript.new()
		p.position = walker.hip_position() + Vector2(randf_range(-500, 500), -950)
		add_child(p)
	if _next_burrower <= 0.0:
		_next_burrower = burrower_interval
		var b := BurrowerScript.new()
		var bside := 1.0 if randf() < 0.5 else -1.0
		b.position = walker.hip_position() + Vector2(bside * 1100, 0)
		add_child(b)


func enemy_killed() -> void:
	kills += 1


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_push_left"):
		walker.apply_push(-1.0)
	elif event.is_action_pressed("debug_push_right"):
		walker.apply_push(1.0)
	elif event.is_action_pressed("debug_reset"):
		get_tree().reload_current_scene()
