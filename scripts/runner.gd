class_name Runner
extends EnemyBase
## Ground charger: sprints at the player and detonates on contact, cratering
## the terrain. Dies to 2 hits.

@export var speed := 170.0
@export var hop_velocity := -420.0
@export var explode_range := 70.0
@export var explode_damage := 18.0
@export var crater_radius := 30.0


func _ready() -> void:
	super()
	max_hp = 2
	hp = 2
	setup_body("res://assets/enemies/runner.png", Vector2(70, 70))


func _physics_process(delta: float) -> void:
	fall(delta)
	var p := player()
	if p:
		var dx := p.global_position.x - global_position.x
		velocity.x = signf(dx) * speed
		if _sprite:
			_sprite.flip_h = dx < 0
		if absf(dx) < explode_range and absf(p.global_position.y - global_position.y) < 160.0:
			_explode(p)
			return
	move_and_slide()
	if is_on_floor() and is_on_wall():
		velocity.y = hop_velocity   # scramble over crater rims


func _explode(p: Node2D) -> void:
	FXScript.blast(get_parent(), global_position, 60.0, Color(1.0, 0.5, 0.2))
	var t := get_tree().get_first_node_in_group("terrain")
	if t:
		t.carve(global_position, crater_radius)
	if p.has_method("take_damage"):
		var away := signf(p.global_position.x - global_position.x)
		p.take_damage(explode_damage, Vector2(away * 4200.0, -2600.0))
	die(false)
