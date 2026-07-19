class_name EnemyBase
extends CharacterBody2D
## Shared enemy plumbing: HP, hit flash, death FX, kill accounting.
## Enemies live on collision layer 8 and collide with terrain (layer 1).

const FXScript := preload("res://scripts/fx.gd")

@export var max_hp := 2
@export var gravity := 1400.0

var hp: int
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	hp = max_hp


func setup_body(tex_path: String, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Assets.tex(tex_path)
	var used := _sprite.texture.get_size()
	if used.x > 0 and used.y > 0:
		_sprite.scale = size * 1.25 / used   # art slightly larger than the hitbox
	add_child(_sprite)


func player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func take_hit(dmg: int) -> void:
	hp -= dmg
	if hp <= 0:
		die(true)
		return
	if _sprite:
		_sprite.modulate = Color(3, 3, 3)
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


func die(counts_as_kill: bool) -> void:
	FXScript.blast(get_parent(), global_position, 34.0, Color(1.0, 0.6, 0.25))
	if counts_as_kill:
		var game := get_tree().get_first_node_in_group("game")
		if game:
			game.enemy_killed()
	queue_free()


func fall(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
