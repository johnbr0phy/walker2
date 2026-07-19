class_name Burrower
extends Node2D
## Underground sapper: tunnels toward the player, eating terrain as it goes —
## you can't shoot it, but you can watch your footing disappear. When it gets
## under the player (or times out) it blasts a big crater and surfaces as a
## runner.

const FXScript := preload("res://scripts/fx.gd")
const RunnerScene := preload("res://scripts/runner.gd")

@export var speed := 140.0
@export var depth := 26.0
@export var chew_period := 0.12
@export var chew_radius := 16.0
@export var surface_blast_radius := 46.0
@export var surface_damage := 12.0
@export var lifetime := 12.0

var _chew_cd := 0.0
var _age := 0.0


func _ready() -> void:
	add_to_group("enemies")   # counts toward the swarm, even if unshootable


func _physics_process(delta: float) -> void:
	_age += delta
	var t: Node = get_tree().get_first_node_in_group("terrain")
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if t == null:
		queue_free()
		return
	var dx := 0.0 if p == null else p.global_position.x - global_position.x
	global_position.x += signf(dx) * speed * delta
	global_position.y = t.surface_y(global_position.x) + depth

	_chew_cd -= delta
	if _chew_cd <= 0.0:
		_chew_cd = chew_period
		t.carve(global_position, chew_radius)
		if randf() < 0.35:
			FXScript.impact(get_parent(), global_position + Vector2(0, -depth),
					Vector2.UP)

	if (p != null and absf(dx) < 26.0) or _age > lifetime:
		_surface(t, p)


func _surface(t: Node, p: Node2D) -> void:
	FXScript.blast(get_parent(), global_position, surface_blast_radius,
			Color(0.75, 0.6, 0.4))
	t.carve(global_position, surface_blast_radius)
	if p != null and p.has_method("take_damage") \
			and absf(p.global_position.x - global_position.x) < 90.0:
		p.take_damage(surface_damage, Vector2(0, -3200.0))
	var runner := RunnerScene.new()
	runner.position = global_position + Vector2(0, -60)
	get_parent().add_child(runner)
	queue_free()
