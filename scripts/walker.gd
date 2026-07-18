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
@export var ride_height := 330.0           # px, hip center above foot center in stance
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
@export var stride_hz := 1.15              # gait cycles per second at full speed
@export var hip_swing_amp := 0.42          # rad of hip swing while walking
@export var knee_lift := 0.7               # rad of knee bend at mid-swing (foot clearance)
@export var stance_splay := 0.06           # rad of idle stance splay
@export var drive_accel_max := 700.0       # px/s^2 cap on the ground drive force
@export var drive_gain := 9.0              # (px/s error) -> accel
@export var drive_coyote_time := 0.2       # s of lost foot contact before drive cuts out

@export_group("Debug")
@export var push_impulse := 9000.0         # debug push strength (Q/E keys)
# ------------------------------------------------------------ end tunables ---

# Geometry (px), derived from the ASSETS.md canvas sizes. Walker local origin
# is the torso/hip joint (hip top-center). +y is down.
const HIP_ATTACH_Y := 75.0     # leg pivot height inside the hip block
const LEG_X := 25.0            # lateral offset of each leg from center
const UPPER_LEN := 140.0
const LOWER_LEN := 140.0
const FOOT_H := 50.0
const FOOT_BOTTOM_Y := HIP_ATTACH_Y + UPPER_LEN + LOWER_LEN + FOOT_H  # 405

const LAYER_TERRAIN := 1
const LAYER_WALKER := 2

var input_dir := 0.0           # -1..1, set by main (or the selftest driver)
var _since_grounded := 0.0

var torso: RigidBody2D
var hip: RigidBody2D
var legs := []                 # [{upper, lower, foot, phase_offset}, ...]
var _phase := 0.0
var _spawn_transform: Transform2D


func _ready() -> void:
	_spawn_transform = transform
	_build_bodies()
	_build_joints()


# ------------------------------------------------------------ construction ---

func _make_part(part_name: String, tex_path: String, center: Vector2, size: Vector2,
		mass: float, friction: float) -> RigidBody2D:
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

	var sprite := Sprite2D.new()
	sprite.texture = Assets.tex(tex_path)
	_fit_sprite_to_canvas(sprite)
	body.add_child(sprite)

	add_child(body)
	return body


static func _fit_sprite_to_canvas(sprite: Sprite2D) -> void:
	# The manifest contract is that art spans its canvas up to the pivot edges
	# (joint spacing == canvas size). Delivered art often has transparent
	# padding, which draws as gaps at the joints — stretch the opaque content
	# to fill the canvas so the parts visually connect. No-op for full-bleed art.
	var img := sprite.texture.get_image()
	if img == null or img.is_empty():
		return
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var full := img.get_size()
	if used.size.x <= 0 or used.size.y <= 0 or used.size == full:
		return
	sprite.scale = Vector2(float(full.x) / used.size.x, float(full.y) / used.size.y)
	sprite.offset = Vector2(full) / 2.0 - (Vector2(used.position) + Vector2(used.size) / 2.0)


func _build_bodies() -> void:
	# Sprites are centered on each body; bodies are placed so the manifest pivot
	# (top-center of hips/legs/feet) lands exactly on its joint anchor.
	torso = _make_part("Torso", "res://assets/walker/torso.png",
			Vector2(0, -100), Vector2(140, 180), mass_torso, body_friction)
	hip = _make_part("Hip", "res://assets/walker/hip.png",
			Vector2(0, 45), Vector2(100, 78), mass_hip, body_friction)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var x := side * LEG_X
		var upper := _make_part("UpperLeg%d" % i, "res://assets/walker/leg_upper.png",
				Vector2(x, HIP_ATTACH_Y + UPPER_LEN * 0.5), Vector2(42, 130),
				mass_leg_upper, body_friction)
		var lower := _make_part("LowerLeg%d" % i, "res://assets/walker/leg_lower.png",
				Vector2(x, HIP_ATTACH_Y + UPPER_LEN + LOWER_LEN * 0.5), Vector2(36, 130),
				mass_leg_lower, body_friction)
		var foot := _make_part("Foot%d" % i, "res://assets/walker/foot.png",
				Vector2(x, HIP_ATTACH_Y + UPPER_LEN + LOWER_LEN + FOOT_H * 0.5),
				Vector2(82, 42), mass_foot, foot_friction)
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


# -------------------------------------------------------------- controller ---

func _physics_process(delta: float) -> void:
	var dir := clampf(input_dir, -1.0, 1.0)
	var grounded := grounded_foot_count() > 0
	_since_grounded = 0.0 if grounded else _since_grounded + delta
	var driveable := _since_grounded < drive_coyote_time

	# Gait phase only advances while commanding movement.
	if absf(dir) > 0.05:
		_phase = wrapf(_phase + TAU * stride_hz * delta, 0.0, TAU)

	# --- torso & hip upright springs (world-anchored) ---
	var target_lean := clampf(dir * lean_into_motion - _com_error_x() * com_lean_gain,
			-max_lean, max_lean)
	_world_pd(torso, target_lean, torso_kp, torso_kd)
	_world_pd(hip, target_lean * 0.5, hip_kp, hip_kd)

	# --- leg joint motors ---
	for leg in legs:
		var hip_target := stance_splay * signf(leg["upper"].position.x - hip.position.x)
		var knee_target := 0.04
		if absf(dir) > 0.05:
			var ph: float = _phase + leg["phase_offset"]
			hip_target = dir * hip_swing_amp * sin(ph)
			# Swing window: this leg is returning to the front while the hip
			# angle is increasing. Knee bend must peak mid-swing (not track the
			# hip angle, which crosses zero there) or the foot scuffs the ground.
			var swing: float = maxf(0.0, dir * cos(ph))
			knee_target = dir * knee_lift * swing + 0.04
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
