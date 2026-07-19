class_name Player
extends RigidBody2D
## The playable mech, rebuilt around the Grok walk harvest (the look John
## picked): the real walk frames play as a legs animation, and a torso+cannons
## plate cut from the same frames pivots at the waist for free aim — including
## rear aim. One physics body carries weight, momentum, recoil, and the
## downfire boost. The M1 motorized-ragdoll walker (walker.gd) is retired from
## the main scene but kept in the repo.
##
## Node origin = the waist pivot. Frames are torso-stabilized offline by
## tools/build_player_frames.py, which also exports a per-frame bob table so
## the torso overlay moves in lockstep with the legs.

# ---------------------------------------------------------------- tunables ---
@export_group("Body & drive")
@export var body_mass := 32.0
@export var body_gravity := 1.2            # >1 reads heavier
@export var walk_speed := 190.0            # px/s target ground speed
@export var drive_accel := 900.0           # px/s^2 toward target while grounded
@export var brake_accel := 1400.0          # px/s^2 toward zero with no input
@export var drive_coyote_time := 0.2       # s of lost ground contact before drive cuts

@export_group("Animation")
@export var anim_fps := 30.0               # legs playback rate at full speed
@export var min_anim_speed := 0.35         # never crawl slower than this while moving
@export var turn_fps := 110.0              # turn strip playback rate (73 frames ~= 0.66 s)

@export_group("Aim & fire")
@export var aim_up_max_deg := 70.0
@export var aim_down_max_deg := 50.0
@export var fire_rate := 9.0
@export var recoil_impulse := 1400.0       # per shot, opposite the barrel
@export var downfire_threshold := 0.55
@export var downfire_boost := 4.5          # recoil multiplier firing downward (jump assist)
@export var spread_deg := 1.2
@export var projectile_speed := 2600.0
@export var projectile_life := 1.2

@export_group("Health & stomp (M4)")
@export var max_hp := 100.0
@export var invuln_time := 0.4             # s of immunity after a hit
@export var stomp_min_air := 0.25          # s airborne before a landing can stomp
@export var stomp_min_fall := 500.0        # px/s peak fall speed to trigger
@export var stomp_range := 150.0
@export var stomp_crater := 26.0

@export_group("Debug")
@export var push_impulse := 9000.0
# ------------------------------------------------------------ end tunables ---

const ProjectileScript := preload("res://scripts/projectile.gd")

const FRAME_W := 378
const FRAME_H := 420
const WAIST := Vector2(214, 205)     # waist pivot in frame coords (frames.json)
const FOOT_BOTTOM_Y := 195.0         # feet sole below the waist origin
const MUZZLE_LOCAL := Vector2(158, -32)  # barrel tip relative to the waist

var input_dir := 0.0                 # -1..1, set by main (or the selftest driver)
var aim_point := Vector2.ZERO
var firing := false
var shots_fired := 0
var hp := 100.0
var dead := false
var stomps := 0
var _invuln := 0.0
var _air_time := 0.0
var _fall_peak := 0.0

var _move_facing := 1.0              # legs facing (travel direction)
var _aim_facing := 1.0               # rig-local torso facing (rear aim = -1)
var _since_grounded := 0.0
var _fire_cooldown := 0.0
var _flash_t := 0.0
var _bob: Array = []
var _turn_bob: Array = []
var _turn_count := 0
var _turning := false
var _turn_progress := 0.0

var _rig: Node2D
var _legs: AnimatedSprite2D
var _torso_pivot: Node2D
var _muzzle_flash: Polygon2D


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	mass = body_mass
	gravity_scale = body_gravity
	lock_rotation = true
	collision_layer = 2
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 4
	var mat := PhysicsMaterial.new()
	mat.friction = 0.08   # low: drive/brake forces steer; high friction pins the box
	mat.bounce = 0.0
	physics_material_override = mat
	aim_point = global_position + Vector2(600, -150)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 385)
	shape.shape = rect
	shape.position = Vector2(0, 2)   # spans -190..195 around the waist
	add_child(shape)

	_build_visuals()


func _build_visuals() -> void:
	_rig = Node2D.new()
	_rig.name = "Rig"
	add_child(_rig)

	# Legs: the masked walk harvest. Frame count + bob come from frames.json;
	# missing files fall back to the Assets placeholder so the game never dies.
	var meta := _load_meta()
	_bob = meta.get("bob", [0])
	_turn_bob = meta.get("turn_bob", [0])
	_turn_count = int(meta.get("turn_count", 0))
	var count: int = meta.get("frame_count", 1)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", anim_fps)
	for i in count:
		sf.add_frame("walk", Assets.tex("res://assets/player/legs/legs_%03d.png" % i))
	sf.add_animation("turn")
	sf.set_animation_loop("turn", false)
	sf.set_animation_speed("turn", turn_fps)
	for i in _turn_count:
		sf.add_frame("turn", Assets.tex("res://assets/player/turn/turn_%03d.png" % i))
	_legs = AnimatedSprite2D.new()
	_legs.sprite_frames = sf
	_legs.animation = "walk"
	_legs.position = Vector2(FRAME_W / 2.0, FRAME_H / 2.0) - WAIST
	_rig.add_child(_legs)

	_torso_pivot = Node2D.new()
	_torso_pivot.name = "TorsoPivot"
	_rig.add_child(_torso_pivot)

	var torso := Sprite2D.new()
	torso.texture = Assets.tex("res://assets/player/torso.png")
	var tsize := torso.texture.get_size()
	torso.position = Vector2(tsize.x / 2.0, tsize.y / 2.0) - WAIST
	_torso_pivot.add_child(torso)

	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(18, -3), Vector2(38, 0), Vector2(18, 3),
		Vector2(0, 8), Vector2(6, 0),
	])
	_muzzle_flash.color = Color(1.0, 0.93, 0.6)
	_muzzle_flash.position = MUZZLE_LOCAL
	_muzzle_flash.visible = false
	_torso_pivot.add_child(_muzzle_flash)


func _load_meta() -> Dictionary:
	var path := "res://assets/player/frames.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	return {}


# -------------------------------------------------------------- controller ---

func _physics_process(delta: float) -> void:
	var dir := clampf(input_dir, -1.0, 1.0) if not dead else 0.0
	if dead:
		firing = false
	var grounded := get_contact_count() > 0
	_invuln -= delta
	if grounded:
		if _air_time > stomp_min_air and _fall_peak > stomp_min_fall:
			_stomp()
		_air_time = 0.0
		_fall_peak = 0.0
	else:
		_air_time += delta
		_fall_peak = maxf(_fall_peak, linear_velocity.y)
	_since_grounded = 0.0 if grounded else _since_grounded + delta
	var driveable := _since_grounded < drive_coyote_time

	# --- facing: reversing on the ground plays the turn strip; airborne
	# (boost hover) there are no planted feet, so the flip is free ---
	var want_dir := signf(dir) if absf(dir) > 0.05 else 0.0
	if not _turning and want_dir != 0.0 and want_dir != _move_facing:
		if grounded and _turn_count > 1:
			_turning = true
			_turn_progress = 0.0
		else:
			_move_facing = want_dir

	# --- drive: momentum-first, no instant velocity writes ---
	if driveable:
		if absf(dir) > 0.05 and not _turning:
			var accel := clampf((dir * walk_speed - linear_velocity.x) * 8.0,
					-drive_accel, drive_accel)
			apply_central_force(Vector2(accel * mass, 0))
		else:
			var brake := clampf(-linear_velocity.x * 10.0, -brake_accel, brake_accel)
			apply_central_force(Vector2(brake * mass, 0))

	# --- legs animation ---
	if _turning:
		# Commanding the old direction again unwinds the turn from where it is.
		var fwd := -1.0 if want_dir == _move_facing else 1.0
		_turn_progress += turn_fps * delta * fwd
		if _turn_progress >= float(_turn_count - 1):
			_move_facing = -_move_facing
			_turning = false
		elif _turn_progress <= 0.0:
			_turning = false
		else:
			_legs.stop()
			_legs.animation = "turn"
			_legs.frame = int(_turn_progress)
			_torso_pivot.position.y = float(_turn_bob[_legs.frame]) \
					if _legs.frame < _turn_bob.size() else 0.0
	if not _turning:
		if _legs.animation != "walk":
			_legs.animation = "walk"
			_legs.frame = 0
		var speed_frac := absf(linear_velocity.x) / walk_speed
		if speed_frac > 0.06:
			_legs.speed_scale = maxf(speed_frac, min_anim_speed) \
					* signf(linear_velocity.x) * _move_facing
			if not _legs.is_playing():
				_legs.play("walk")
		else:
			_legs.stop()
			_legs.frame = 0
		_torso_pivot.position.y = float(_bob[_legs.frame]) if _legs.frame < _bob.size() else 0.0
	_rig.scale.x = _move_facing

	# --- aim & fire ---
	_update_aim()
	_fire_cooldown -= delta
	if firing and _fire_cooldown <= 0.0:
		_fire_cooldown = 1.0 / fire_rate
		_fire_one_shot()
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_muzzle_flash.visible = false


func _update_aim() -> void:
	var to_aim := aim_point - global_position
	if to_aim.length_squared() < 1.0:
		return
	# Work in rig-local space (the rig mirrors with travel direction).
	var lx := to_aim.x * _move_facing
	if absf(to_aim.x) > 8.0:
		_aim_facing = 1.0 if lx > 0.0 else -1.0
	var pitch := clampf(atan2(to_aim.y, absf(to_aim.x)),
			-deg_to_rad(aim_up_max_deg), deg_to_rad(aim_down_max_deg))
	_torso_pivot.scale.x = _aim_facing
	_torso_pivot.rotation = _aim_facing * pitch


func barrel_direction() -> Vector2:
	return _torso_pivot.global_transform.x.normalized()


func muzzle_position() -> Vector2:
	return _torso_pivot.to_global(MUZZLE_LOCAL)


func _fire_one_shot() -> void:
	shots_fired += 1
	var dir := barrel_direction().rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	ProjectileScript.spawn(get_parent(), muzzle_position(), dir * projectile_speed,
			projectile_life)
	var impulse := -dir * recoil_impulse
	if dir.y > downfire_threshold:
		impulse *= downfire_boost
	apply_central_impulse(impulse)
	_muzzle_flash.visible = true
	_muzzle_flash.scale = Vector2(randf_range(0.85, 1.3), randf_range(0.85, 1.3))
	_flash_t = 0.055


# ------------------------------------------- selftest / HUD compatibility ---

func take_damage(amount: float, knockback: Vector2) -> void:
	if dead or _invuln > 0.0:
		return
	_invuln = invuln_time
	hp -= amount
	apply_central_impulse(knockback)
	_rig.modulate = Color(3, 1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(_rig, "modulate", Color.WHITE, 0.18)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		firing = false
		_rig.modulate = Color(0.45, 0.42, 0.4)


func _stomp() -> void:
	stomps += 1
	var FXS := preload("res://scripts/fx.gd")
	var feet := global_position + Vector2(0, FOOT_BOTTOM_Y - 10.0)
	FXS.blast(get_parent(), feet, 56.0, Color(0.85, 0.8, 0.6))
	var t := get_tree().get_first_node_in_group("terrain")
	if t:
		t.carve(feet, stomp_crater)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.global_position.distance_to(feet) < stomp_range \
				and e.has_method("take_hit"):
			e.take_hit(3)


func hip_position() -> Vector2:
	return global_position


func torso_angle() -> float:
	return rotation   # locked -> 0; the visual pitch is aim, not balance


func grounded_foot_count() -> int:
	return 2 if get_contact_count() > 0 else 0


func apply_push(direction: float) -> void:
	apply_central_impulse(Vector2(direction * push_impulse, 0))
