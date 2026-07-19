extends Node2D
## World bootstrap for M1: parallax background, flat test ground (M3 replaces
## this with deformable terrain), the walker, camera, HUD, and debug input.
## Run with `-- selftest` in user args to execute the headless M1 gate instead.

# ---------------------------------------------------------------- tunables ---
@export var ground_y := 600.0          # world y of the ground surface
@export var ground_half_width := 20000.0
@export var camera_zoom := 1.0
@export var camera_cursor_lead := 0.10 # how far the camera drifts toward the cursor
# ------------------------------------------------------------ end tunables ---

var walker: Node2D   # the player (player.gd); legacy walker.gd kept in repo
var camera: Camera2D
var hud_label: Label
var crosshair: Sprite2D
var selftest_mode := false   # true when a script (selftest/screenshot) drives input
var _shot_dir := ""
var _shot_t := 0.0
var _shots_taken := 0


func _ready() -> void:
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
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	ground.physics_material_override = mat

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ground_half_width * 2.0, 400.0)
	shape.shape = rect
	shape.position = Vector2(0, ground_y + 200.0)
	ground.add_child(shape)

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-ground_half_width, ground_y),
		Vector2(ground_half_width, ground_y),
		Vector2(ground_half_width, ground_y + 400.0),
		Vector2(-ground_half_width, ground_y + 400.0),
	])
	poly.texture = Assets.tex("res://assets/terrain/dirt.png")
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.add_child(poly)
	add_child(ground)


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
		walker.aim_point = walker.hip_position() + Vector2(650, -260)
		walker.firing = _shot_t > 2.5
		if (_shots_taken == 0 and _shot_t > 1.5) or (_shots_taken == 1 and _shot_t > 4.0):
			_shots_taken += 1
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/shot%d.png" % [_shot_dir, _shots_taken])
			print("saved shot%d" % _shots_taken)
			if _shots_taken == 2:
				get_tree().quit()
	camera.position = walker.hip_position() + Vector2(0, -120) \
			+ (walker.aim_point - walker.hip_position()) * camera_cursor_lead
	hud_label.text = "A/D move  ·  mouse aim  ·  LMB fire  ·  Q/E push  ·  R reset      torso %+5.1f°  feet down %d" % [
		rad_to_deg(walker.torso_angle()), walker.grounded_foot_count()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_push_left"):
		walker.apply_push(-1.0)
	elif event.is_action_pressed("debug_push_right"):
		walker.apply_push(1.0)
	elif event.is_action_pressed("debug_reset"):
		get_tree().reload_current_scene()
