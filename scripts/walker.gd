class_name Walker
extends Node2D
## M1: physically-simulated bipedal mech — a chain of rigid bodies (torso, hip,
## 2x upper leg, 2x lower leg, 2x foot) joined by pin joints with angular limits.
## The player commands intent (input_dir); a PD controller keeps the machine
## upright (stabilizer spring on the torso — see README for the tradeoff), drives
## a stepping gait through joint torques, and pushes the body toward the target
## speed only while at least one foot has ground contact.

# ---------------------------------------------------------------- tunables ---
@export_group("Masses & world")
@export var mass_torso := 12.0
@export var mass_hip := 6.0
@export var mass_leg_upper := 3.0
@export var mass_leg_lower := 2.0
@export var mass_foot := 2.0
@export var gravity_scale_all := 1.2       # >1 reads heavier
@export var foot_friction := 0.9
@export var body_friction := 0.7

@export_group("Balance (PD gains)")
@export var torso_kp := 7.0e6              # world-anchored upright spring on torso
@export var torso_kd := 1.1e6
@export var hip_kp := 6.0e6                # world-anchored upright spring on hip block
@export var hip_kd := 6.0e5
@export var lean_into_motion := 0.07       # rad of lean per full walk speed
@export var com_lean_gain := 0.0004        # rad of corrective lean per px of COM error
@export var max_lean := 0.16
@export var ride_height := 170.0           # px, hip center above foot center in stance
@export var suspension_kp := 1300.0        # contact-gated vertical spring holding stance
@export var suspension_kd := 500.0
@export var suspension_force_max := 7.0e4  # keep near walker weight or it hops

@export_group("Legs (joint PD gains)")
@export var leg_kp := 6.0e6                # hip joint motor stiffness
@export var leg_kd := 4.0e5
@export var knee_kp := 7.0e6
@export var knee_kd := 4.0e5
@export var foot_flat_kp := 9.0e4          # keeps feet level with the world
@export var foot_flat_kd := 7.0e3
@export var joint_torque_max := 9.0e6

@export_group("Gait & drive")
@export var walk_speed := 170.0            # px/s target ground speed
@export var stride_hz := 1.6              # gait cycles per second at full speed
@export var hip_swing_amp := 0.5          # rad of hip swing while walking
@export var knee_lift := 0.7               # rad of knee bend at mid-swing (foot clearance)
@export var stance_splay := 0.06           # rad of idle stance splay
@export var stance_knee_bend := 0.28       # rad of idle knee bend (the design never locks straight)
@export var drive_accel_max := 700.0       # px/s^2 cap on the ground drive force
@export var drive_gain := 9.0              # (px/s error) -> accel
@export var drive_coyote_time := 0.2       # s of lost foot contact before drive cuts out

@export_group("Aim & fire (M2)")
@export var aim_up_max_deg := 70.0         # pitch clamp above horizontal
@export var aim_down_max_deg := 55.0       # pitch clamp below horizontal
@export var fire_rate := 9.0               # rounds per second while held
@export var recoil_impulse := 1200.0       # per shot, opposite the barrel
@export var recoil_torso_split := 0.6      # recoil share applied at the hardpoint (rest to hip)
@export var downfire_threshold := 0.55     # barrel dir.y beyond which the boost kicks in
@export var downfire_boost := 4.0          # recoil multiplier when firing downward (jump assist);
                                           # must beat weight through the 55-deg pitch clamp to lift
@export var spread_deg := 1.2              # random per-shot spread
@export var projectile_speed := 2600.0     # px/s
@export var projectile_life := 1.2         # s

@export_group("Debug")
@export var push_impulse := 9000.0         # debug push strength (Q/E keys)
# ------------------------------------------------------------ end tunables ---

# Geometry (px), derived from the ASSETS.md canvas sizes. Walker local origin
# is the torso/hip joint (hip top-center). +y is down.
const HIP_ATTACH_Y := 50.0     # leg pivot height inside the hip block
const LEG_X := 30.0            # lateral offset of each leg from center
const UPPER_LEN := 75.0
const LOWER_LEN := 75.0
const FOOT_H := 55.0
const FOOT_BOTTOM_Y := HIP_ATTACH_Y + UPPER_LEN + LOWER_LEN + FOOT_H  # 255

const LAYER_TERRAIN := 1
const LAYER_WALKER := 2

# Preloaded (not class_name lookups) so headless runs don't depend on the
# editor's global class cache being fresh.
const ProjectileScript := preload("res://scripts/projectile.gd")

# Aim assembly geometry (waist-pitch model — see ASSETS.md / grok-art-parts.md).
const WAIST_LOCAL := Vector2(0, 100)       # waist joint in torso-body coords
const HARDPOINT := Vector2(0, -150)        # gun mount in assembly coords (origin = waist)
const GUN_LEN := 220.0

var input_dir := 0.0           # -1..1, set by main (or the selftest driver)
var aim_point := Vector2.ZERO  # world-space cursor, set by main (or selftest)
var firing := false            # true while the trigger is held
var shots_fired := 0
var _since_grounded := 0.0
var _facing := 1.0             # +1 guns right, -1 guns rear (assembly flipped)
var _gait_dir := 1.0           # last commanded travel direction; sets knee bend side
var _fire_cooldown := 0.0
var _flash_t := 0.0

var torso: RigidBody2D
var hip: RigidBody2D
var legs := []                 # [{upper, lower, foot, phase_offset}, ...]
var aim_assembly: Node2D
var _muzzle_flash: Polygon2D
var _phase := 0.0
var _spawn_transform: Transform2D


func _ready() -> void:
	_spawn_transform = transform
	aim_point = global_position + Vector2(600, -150)
	_build_bodies()
	_build_joints()
	_build_aim_assembly()


# ------------------------------------------------------------ construction ---

func _make_part(part_name: String, tex_path: String, center: Vector2, size: Vector2,
		mass: float, friction: float, with_sprite := true) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = part_name
	body.position = center
	body.mass = mass
	body.gravity_scale = gravity_scale_all
	body.collision_layer = LAYER_WALKER
	body.collision_mask = LAYER_TERRAIN   # parts never collide with each other
	body.linear_damp = 0.1
	body.angular_damp = 2.0
	body.contact_monitor = true
	body.max_contacts_reported = 8
	var mat := PhysicsMaterial.new()
	mat.friction = friction
	mat.bounce = 0.0
	body.physics_material_override = mat

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	if with_sprite:
		var sprite := Sprite2D.new()
		sprite.texture = Assets.tex(tex_path)
		_fit_sprite_to_canvas(sprite, Assets.MANIFEST_SIZES.get(tex_path, Vector2i(size)))
		body.add_child(sprite)

	add_child(body)
	return body


static func _fit_sprite_to_canvas(sprite: Sprite2D, canvas: Vector2i) -> void:
	# The manifest contract is that art spans its canvas up to the pivot edges
	# (joint spacing == canvas size). Stretch the opaque content of whatever art
	# was delivered to fill the manifest canvas: this closes gaps from
	# transparent padding AND re-proportions art delivered at older canvas
	# sizes, so skeleton geometry changes never require an art re-cut to run.
	var img := sprite.texture.get_image()
	if img == null or img.is_empty():
		return
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	sprite.scale = Vector2(canvas) / Vector2(used.size)
	sprite.offset = Vector2(img.get_size()) / 2.0 \
			- (Vector2(used.position) + Vector2(used.size) / 2.0)


func _build_bodies() -> void:
	# Sprites are centered on each body; bodies are placed so the manifest pivot
	# (top-center of hips/legs/feet) lands exactly on its joint anchor.
	# The torso's visuals live on the aim assembly (built after the joints), so
	# the upper body can pitch toward the cursor while physics stays upright.
	torso = _make_part("Torso", "res://assets/walker/torso.png",
			Vector2(0, -100), Vector2(200, 180), mass_torso, body_friction, false)
	hip = _make_part("Hip", "res://assets/walker/hip.png",
			Vector2(0, 40), Vector2(120, 68), mass_hip, body_friction)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var x := side * LEG_X
		var upper := _make_part("UpperLeg%d" % i, "res://assets/walker/leg_upper.png",
				Vector2(x, HIP_ATTACH_Y + UPPER_LEN * 0.5), Vector2(64, 68),
				mass_leg_upper, body_friction)
		var lower := _make_part("LowerLeg%d" % i, "res://assets/walker/leg_lower.png",
				Vector2(x, HIP_ATTACH_Y + UPPER_LEN + LOWER_LEN * 0.5), Vector2(56, 68),
				mass_leg_lower, body_friction)
		var foot := _make_part("Foot%d" % i, "res://assets/walker/foot.png",
				Vector2(x, HIP_ATTACH_Y + UPPER_LEN + LOWER_LEN + FOOT_H * 0.5),
				Vector2(118, 46), mass_foot, foot_friction)
		legs.append({
			"upper": upper, "lower": lower, "foot": foot,
			"phase_offset": PI * i,   # legs run half a cycle apart
		})
	# Draw order: far leg behind torso, near leg in front.
	move_child(torso, -1)
	move_child(legs[1]["upper"], -1)
	move_child(legs[1]["lower"], -1)
	move_child(legs[1]["foot"], -1)


func _pin(a: RigidBody2D, b: RigidBody2D, local_point: Vector2, limit_deg: float) -> void:
	var joint := PinJoint2D.new()
	joint.position = local_point
	joint.node_a = a.get_path()
	joint.node_b = b.get_path()
	joint.angular_limit_enabled = true
	joint.angular_limit_lower = deg_to_rad(-limit_deg)
	joint.angular_limit_upper = deg_to_rad(limit_deg)
	add_child(joint)


func _build_joints() -> void:
	_pin(torso, hip, Vector2(0, 0), 14.0)
	for leg in legs:
		var x: float = leg["upper"].position.x
		_pin(hip, leg["upper"], Vector2(x, HIP_ATTACH_Y), 55.0)
		_pin(leg["upper"], leg["lower"], Vector2(x, HIP_ATTACH_Y + UPPER_LEN), 75.0)
		_pin(leg["lower"], leg["foot"], Vector2(x, HIP_ATTACH_Y + UPPER_LEN + LOWER_LEN), 30.0)


func _build_aim_assembly() -> void:
	# The whole upper assembly (torso art + gun) pivots at the waist toward the
	# cursor — instant and non-physical per the design pillars, while the physics
	# torso underneath keeps balancing and takes the recoil. Rear aim flips the
	# assembly so the guns point backward over the legs, Amiga-Walker style.
	aim_assembly = Node2D.new()
	aim_assembly.name = "AimAssembly"
	aim_assembly.position = WAIST_LOCAL
	aim_assembly.z_index = 1   # gun/torso read above the legs when pitched down
	torso.add_child(aim_assembly)

	var torso_sprite := Sprite2D.new()
	torso_sprite.texture = Assets.tex("res://assets/walker/torso.png")
	_fit_sprite_to_canvas(torso_sprite, Vector2i(240, 200))
	torso_sprite.position = Vector2(0, -100)   # canvas center relative to waist
	aim_assembly.add_child(torso_sprite)

	var gun_sprite := Sprite2D.new()
	gun_sprite.texture = Assets.tex("res://assets/walker/gun.png")
	_fit_sprite_to_canvas(gun_sprite, Vector2i(220, 70))
	gun_sprite.position = HARDPOINT + Vector2(GUN_LEN * 0.5, 0)  # left-center pivot on the mount
	aim_assembly.add_child(gun_sprite)

	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.polygon = PackedVector2Array([
		Vector2(0, -7), Vector2(16, -2), Vector2(34, 0), Vector2(16, 2),
		Vector2(0, 7), Vector2(5, 0),
	])
	_muzzle_flash.color = Color(1.0, 0.93, 0.6)
	_muzzle_flash.position = HARDPOINT + Vector2(GUN_LEN - 6.0, 0)
	_muzzle_flash.visible = false
	aim_assembly.add_child(_muzzle_flash)


# -------------------------------------------------------------- controller ---

func _physics_process(delta: float) -> void:
	var dir := clampf(input_dir, -1.0, 1.0)
	var grounded := grounded_foot_count() > 0
	_since_grounded = 0.0 if grounded else _since_grounded + delta
	var driveable := _since_grounded < drive_coyote_time

	# Gait phase only advances while commanding movement. The knee bend
	# direction mirrors with travel so both directions walk identically
	# (a fixed bend direction makes one direction dramatically slower).
	if absf(dir) > 0.05:
		_phase = wrapf(_phase + TAU * stride_hz * delta, 0.0, TAU)
		_gait_dir = signf(dir)

	# --- torso & hip upright springs (world-anchored) ---
	var target_lean := clampf(dir * lean_into_motion - _com_error_x() * com_lean_gain,
			-max_lean, max_lean)
	_world_pd(torso, target_lean, torso_kp, torso_kd)
	_world_pd(hip, target_lean * 0.5, hip_kp, hip_kd)

	# --- leg joint motors ---
	for leg in legs:
		var hip_target := stance_splay * signf(leg["upper"].position.x - hip.position.x)
		var knee_target := _gait_dir * stance_knee_bend
		if absf(dir) > 0.05:
			var ph: float = _phase + leg["phase_offset"]
			hip_target = dir * hip_swing_amp * sin(ph)
			# Swing window: this leg is returning to the front while the hip
			# angle is increasing. Knee bend must peak mid-swing (not track the
			# hip angle, which crosses zero there) or the foot scuffs the ground.
			# The lift deepens the bend in the gait direction, never through
			# straight — crossing zero mid-swing scuffs the foot.
			var swing: float = maxf(0.0, dir * cos(ph))
			knee_target = _gait_dir * (stance_knee_bend + knee_lift * swing)
		# Upper legs track world-frame targets: anchoring them to the hip body
		# lets leg reaction torques twist the gait's own reference frame.
		_world_pd(leg["upper"], hip_target, leg_kp, leg_kd)
		_joint_pd(leg["upper"], leg["lower"], knee_target, knee_kp, knee_kd)
		_world_pd(leg["foot"], 0.0, foot_flat_kp, foot_flat_kd)

	# --- ground drive: horizontal force toward target speed, feet-gated ---
	if driveable:
		var v_target := dir * walk_speed
		var accel := clampf((v_target - hip.linear_velocity.x) * drive_gain,
				-drive_accel_max, drive_accel_max)
		var force := accel * total_mass()
		hip.apply_central_force(Vector2(force * 0.55, 0))
		torso.apply_central_force(Vector2(force * 0.45, 0))

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

	# --- ride-height suspension: keeps stance legs from buckling under load.
	# Contact-gated so it never hovers; a tradeoff noted in the README. ---
	if grounded:
		var foot_y := 0.0
		var n := 0
		for leg in legs:
			if leg["foot"].get_contact_count() > 0:
				foot_y += leg["foot"].global_position.y
				n += 1
		var target_hip_y := foot_y / n - ride_height
		var lift := suspension_kp * (target_hip_y - hip.global_position.y) \
				- suspension_kd * hip.linear_velocity.y
		lift = clampf(lift, -suspension_force_max, suspension_force_max)
		hip.apply_central_force(Vector2(0, lift * 0.4))
		torso.apply_central_force(Vector2(0, lift * 0.6))


func _update_aim() -> void:
	var waist := torso.to_global(WAIST_LOCAL)
	var to_aim := aim_point - waist
	if to_aim.length_squared() < 1.0:
		return
	if absf(to_aim.x) > 8.0:   # hysteresis so the assembly doesn't flicker overhead
		_facing = 1.0 if to_aim.x > 0.0 else -1.0
	# Pitch measured as if facing right; the flip mirrors it for rear aim.
	var pitch := clampf(atan2(to_aim.y, to_aim.x * _facing),
			-deg_to_rad(aim_up_max_deg), deg_to_rad(aim_down_max_deg))
	aim_assembly.scale = Vector2(_facing, 1.0)
	# With scale.x = -1 the flipped barrel's world angle is PI - rotation, so
	# facing folds into a sign; subtracting torso rotation keeps aim world-true.
	aim_assembly.rotation = _facing * pitch - torso.rotation


func barrel_direction() -> Vector2:
	return aim_assembly.global_transform.x.normalized()


func muzzle_position() -> Vector2:
	return aim_assembly.to_global(HARDPOINT + Vector2(GUN_LEN - 6.0, 0))


func _fire_one_shot() -> void:
	shots_fired += 1
	var dir := barrel_direction().rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	ProjectileScript.spawn(get_parent(), muzzle_position(), dir * projectile_speed, projectile_life)

	# Recoil is real physics: shove the body opposite the barrel. Firing at the
	# ground multiplies it into a jump assist (the M2 "downward-fire boost").
	var impulse := -dir * recoil_impulse
	if dir.y > downfire_threshold:
		impulse *= downfire_boost
	var hard_world := aim_assembly.to_global(HARDPOINT)
	torso.apply_impulse(impulse * recoil_torso_split, hard_world - torso.global_position)
	hip.apply_central_impulse(impulse * (1.0 - recoil_torso_split))

	_muzzle_flash.visible = true
	_muzzle_flash.scale = Vector2(randf_range(0.8, 1.3), randf_range(0.8, 1.3))
	_flash_t = 0.055


func _world_pd(body: RigidBody2D, target_rot: float, kp: float, kd: float) -> void:
	var torque := kp * (target_rot - body.rotation) - kd * body.angular_velocity
	body.apply_torque(clampf(torque, -joint_torque_max, joint_torque_max))


func _joint_pd(parent: RigidBody2D, child: RigidBody2D, target_rel: float,
		kp: float, kd: float) -> void:
	var rel := child.rotation - parent.rotation
	var torque := kp * (target_rel - rel) - kd * (child.angular_velocity - parent.angular_velocity)
	torque = clampf(torque, -joint_torque_max, joint_torque_max)
	child.apply_torque(torque)
	parent.apply_torque(-torque)


# ------------------------------------------------------------------ helpers ---

func total_mass() -> float:
	return mass_torso + mass_hip + 2.0 * (mass_leg_upper + mass_leg_lower + mass_foot)


func center_of_mass_x() -> float:
	var m := 0.0
	var mx := 0.0
	for body in [torso, hip]:
		m += body.mass
		mx += body.mass * body.global_position.x
	for leg in legs:
		for key in ["upper", "lower", "foot"]:
			var body: RigidBody2D = leg[key]
			m += body.mass
			mx += body.mass * body.global_position.x
	return mx / m


func _com_error_x() -> float:
	var support: float = (legs[0]["foot"].global_position.x + legs[1]["foot"].global_position.x) * 0.5
	return center_of_mass_x() - support


func grounded_foot_count() -> int:
	var n := 0
	for leg in legs:
		if leg["foot"].get_contact_count() > 0:
			n += 1
	return n


func hip_position() -> Vector2:
	return hip.global_position


func torso_angle() -> float:
	return torso.rotation


func apply_push(direction: float) -> void:
	# Debug shove at the torso top: tests push recovery (M1 gate).
	torso.apply_impulse(Vector2(direction * push_impulse, 0), Vector2(0, -70))
