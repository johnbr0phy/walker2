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
