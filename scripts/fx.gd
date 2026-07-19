class_name FX
## Code-driven effects (design rule: FX never load art files).

static func impact(parent: Node, pos: Vector2, normal: Vector2) -> void:
	var sparks := CPUParticles2D.new()
	sparks.position = pos
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = 14
	sparks.lifetime = 0.35
	sparks.explosiveness = 1.0
	sparks.direction = normal
	sparks.spread = 55.0
	sparks.initial_velocity_min = 180.0
	sparks.initial_velocity_max = 420.0
	sparks.gravity = Vector2(0, 1400)
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.5
	sparks.color = Color(1.0, 0.82, 0.35)
	parent.add_child(sparks)
	parent.get_tree().create_timer(0.7).timeout.connect(sparks.queue_free)

	var flash := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var r := 11.0 if i % 2 == 0 else 4.5
		pts.append(Vector2.from_angle(TAU * i / 10.0) * r)
	flash.polygon = pts
	flash.position = pos
	flash.color = Color(1.0, 0.95, 0.75)
	parent.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector2(0.2, 0.2), 0.12)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	tw.tween_callback(flash.queue_free)


static func blast(parent: Node, pos: Vector2, radius: float, tint: Color) -> void:
	# Explosion: expanding ring + fireball particles. Code only, per the FX rule.
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(Vector2.from_angle(TAU * i / 24.0))
	ring.polygon = pts
	ring.color = Color(tint.r, tint.g, tint.b, 0.85)
	ring.position = pos
	ring.scale = Vector2(radius * 0.3, radius * 0.3)
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(radius, radius) * 0.06, 0.22)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ring.queue_free)

	var boom := CPUParticles2D.new()
	boom.position = pos
	boom.one_shot = true
	boom.emitting = true
	boom.amount = 24
	boom.lifetime = 0.5
	boom.explosiveness = 1.0
	boom.spread = 180.0
	boom.initial_velocity_min = 90.0
	boom.initial_velocity_max = radius * 6.0
	boom.gravity = Vector2(0, 900)
	boom.scale_amount_min = 2.0
	boom.scale_amount_max = 5.0
	boom.color = tint
	parent.add_child(boom)
	parent.get_tree().create_timer(0.9).timeout.connect(boom.queue_free)
	var game := parent.get_tree().get_first_node_in_group("game")
	if game and game.has_method("add_shake"):
		game.add_shake(minf(radius / 60.0, 1.2))
