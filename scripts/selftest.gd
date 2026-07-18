extends Node
## Headless M1 gate: stand, walk right, take a debug push, recover.
## Run: godot --headless -- selftest
## Prints metrics and exits 0 (pass) / 1 (fail).

var walker: Walker

var _t := 0.0
var _pushed := false
var _walk_start_x := 0.0
var _walk_dist := 0.0
var _stand_max_tilt := 0.0
var _spawn_hip_y := 0.0
var _fail := []

const STAND_END := 2.0
const WALK_END := 6.0
const PUSH_AT := 6.5
const RECOVER_END := 9.5
const WALK_LEFT_END := 12.5


func _ready() -> void:
	Engine.time_scale = 5.0
	_spawn_hip_y = walker.hip_position().y
	print("[selftest] start; hip=", walker.hip_position())


var _left_start_x := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	var tilt: float = absf(walker.torso_angle())

	# Command input every physics tick for the current phase.
	if _t < STAND_END:
		walker.input_dir = 0.0
		if _t > 1.0:
			_stand_max_tilt = maxf(_stand_max_tilt, tilt)
	elif _t < WALK_END:
		if _walk_start_x == 0.0:
			_walk_start_x = walker.hip_position().x
			_check("stand: settled tilt < 0.20 rad", _stand_max_tilt < 0.20,
					"max tilt %.3f" % _stand_max_tilt)
			_check("stand: no collapse", absf(walker.hip_position().y - _spawn_hip_y) < 60.0,
					"hip dy %.1f" % (walker.hip_position().y - _spawn_hip_y))
		walker.input_dir = 1.0
	elif _t < PUSH_AT:
		if _walk_dist == 0.0:
			_walk_dist = walker.hip_position().x - _walk_start_x
			_check("walk: moved > 300 px in 4 s", _walk_dist > 300.0,
					"dist %.0f px (%.0f px/s)" % [_walk_dist, _walk_dist / 4.0])
			_check("walk: stayed upright", tilt < 0.35, "tilt %.3f" % tilt)
		walker.input_dir = 0.0
	elif not _pushed:
		_pushed = true
		walker.apply_push(-1.0)
		print("[selftest] push applied at t=%.1f" % _t)
	elif _t < RECOVER_END:
		walker.input_dir = 0.0
	elif _t < WALK_LEFT_END:
		if _left_start_x == 0.0:
			_check("push: recovered upright", tilt < 0.30, "tilt %.3f" % tilt)
			_check("push: still standing", absf(walker.hip_position().y - _spawn_hip_y) < 80.0,
					"hip dy %.1f" % (walker.hip_position().y - _spawn_hip_y))
			_left_start_x = walker.hip_position().x
		walker.input_dir = -1.0
	else:
		walker.input_dir = 0.0
		var dist := _left_start_x - walker.hip_position().x
		_check("walk left: moved > 220 px in 3 s", dist > 220.0,
				"dist %.0f px (%.0f px/s)" % [dist, dist / 3.0])
		_check("walk left: stayed upright", tilt < 0.35, "tilt %.3f" % tilt)
		_finish()


func _check(label: String, ok: bool, detail: String) -> void:
	print("[selftest] %s  %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fail.append(label)


func _finish() -> void:
	set_physics_process(false)
	if _fail.is_empty():
		print("[selftest] ALL PASS")
	else:
		print("[selftest] FAILED: ", _fail)
	get_tree().quit(0 if _fail.is_empty() else 1)
