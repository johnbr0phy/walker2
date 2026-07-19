class_name Paratrooper
extends EnemyBase
## Drops from the sky under a chute (one shot pops it), then walks at the
## player and chews with melee hits.

@export var fall_speed := 90.0
@export var drift_speed := 45.0
@export var walk_speed := 70.0
@export var melee_range := 75.0
@export var melee_damage := 8.0
@export var melee_period := 0.7

var _chute: Sprite2D
var _landed := false
var _melee_cd := 0.0


func _ready() -> void:
	super()
	max_hp = 1
	hp = 1
	setup_body("res://assets/enemies/paratrooper.png", Vector2(50, 80))
	_chute = Sprite2D.new()
	_chute.texture = Assets.tex("res://assets/enemies/parachute.png")
	_chute.position = Vector2(0, -110)
	var used := _chute.texture.get_size()
	if used.x > 0:
		_chute.scale = Vector2(140, 100) / used
	add_child(_chute)


func _physics_process(delta: float) -> void:
	var p := player()
	if not _landed:
		velocity.y = fall_speed
		velocity.x = 0.0 if p == null else signf(p.global_position.x - global_position.x) * drift_speed
		move_and_slide()
		if is_on_floor():
			_landed = true
			_chute.queue_free()
		return
	fall(delta)
	_melee_cd -= delta
	if p:
		var dx := p.global_position.x - global_position.x
		if _sprite:
			_sprite.flip_h = dx < 0
		if absf(dx) > melee_range * 0.6:
			velocity.x = signf(dx) * walk_speed
		else:
			velocity.x = 0.0
		if global_position.distance_to(p.global_position) < melee_range + 100.0 \
				and absf(dx) < melee_range and _melee_cd <= 0.0 and p.has_method("take_damage"):
			_melee_cd = melee_period
			p.take_damage(melee_damage, Vector2(signf(dx) * 1200.0, -400.0))
	move_and_slide()
