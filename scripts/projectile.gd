class_name Projectile
extends Node2D
## Ray-stepped tracer round: no physics body, just a segment cast per tick
## against terrain (layer 1) and enemies (layer 8). Terrain hits carve craters
## (M3). Visuals are drawn in code (design rule: no art files for FX).

const HIT_MASK := 1 | 8
const CARVE_RADIUS := 26.0
const FXScript := preload("res://scripts/fx.gd")

var velocity := Vector2.ZERO
var life := 1.2


static func spawn(parent: Node, pos: Vector2, vel: Vector2, lifetime: float) -> Projectile:
	var p := Projectile.new()
	p.position = pos
	p.velocity = vel
	p.life = lifetime
	p.rotation = vel.angle()
	parent.add_child(p)
	return p


func _physics_process(delta: float) -> void:
	var next := position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(position, next, HIT_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		var collider: Object = hit.collider
		if collider != null and collider.has_method("take_hit"):
			collider.take_hit(1)
			FXScript.impact(get_parent(), hit.position, hit.normal)
		else:
			var t := get_tree().get_first_node_in_group("terrain")
			if t:
				t.carve(hit.position, CARVE_RADIUS)
			FXScript.impact(get_parent(), hit.position, hit.normal)
		queue_free()
		return
	position = next
	life -= delta
	if life <= 0.0:
		queue_free()


func _draw() -> void:
	draw_line(Vector2(-16, 0), Vector2(10, 0), Color(1.0, 0.85, 0.4, 0.85), 3.0)
	draw_line(Vector2(-4, 0), Vector2(10, 0), Color(1.0, 1.0, 0.88), 1.5)
