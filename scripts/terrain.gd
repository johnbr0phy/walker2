class_name Terrain
extends Node2D
## M3 deformable ground: a material grid (dirt over rock) with carve-anywhere
## craters. Visuals are chunked images built by blitting the tiling material
## textures per solid cell; collision is an invisible TileMapLayer that erases
## cells as they're carved. Debris chunks are code-drawn rigid bodies (FX rule:
## no art files). Beyond the deformable arena, main.gd lays static bedrock.

# ---------------------------------------------------------------- tunables ---
@export var cell := 8                     # px per grid cell
@export var cols := 512                   # arena width = cols*cell (4096)
@export var rows := 40                    # depth = rows*cell (320)
@export var dirt_rows := 14               # top rows are dirt, the rest rock
@export var rock_hardness := 0.6          # rock only carves within r*this
@export var debris_per_crater := 4
@export var debris_lifetime := 2.2
@export var max_debris := 36
# ------------------------------------------------------------ end tunables ---

const CHUNK := 64                         # cells per chunk side (512 px)
const EMPTY := 0
const DIRT := 1
const ROCK := 2

var origin := Vector2.ZERO                # top-left of the grid in world space
var _grid: PackedByteArray
var _tiles: TileMapLayer
var _chunk_sprites := {}                  # Vector2i chunk coords -> Sprite2D
var _dirty := {}                          # chunk coords set
var _mat_imgs := {}
var craters_carved := 0


func _ready() -> void:
	add_to_group("terrain")
	origin = position
	position = Vector2.ZERO   # grid math uses `origin`; children live in world space
	_grid = PackedByteArray()
	_grid.resize(cols * rows)
	for cy in rows:
		for cx in cols:
			_grid[cy * cols + cx] = DIRT if cy < dirt_rows else ROCK
	_mat_imgs[DIRT] = _material_image("res://assets/terrain/dirt.png")
	_mat_imgs[ROCK] = _material_image("res://assets/terrain/rock.png")
	_build_collision()
	for cy in ceili(float(rows) / CHUNK):
		for cx in ceili(float(cols) / CHUNK):
			_dirty[Vector2i(cx, cy)] = true
	_flush_dirty()


func _material_image(path: String) -> Image:
	var img := Assets.tex(path).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _build_collision() -> void:
	var white := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(white)
	src.texture_region_size = Vector2i(cell, cell)
	src.create_tile(Vector2i.ZERO)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cell, cell)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.add_source(src, 0)
	var h := cell / 2.0
	var td := src.get_tile_data(Vector2i.ZERO, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))

	_tiles = TileMapLayer.new()
	_tiles.tile_set = ts
	_tiles.visible = false
	_tiles.position = origin
	add_child(_tiles)
	for cy in rows:
		for cx in cols:
			_tiles.set_cell(Vector2i(cx, cy), 0, Vector2i.ZERO)


# ------------------------------------------------------------------- carve ---

func carve(world_pos: Vector2, radius: float) -> void:
	var local := world_pos - origin
	var min_cx := maxi(0, int((local.x - radius) / cell))
	var max_cx := mini(cols - 1, int((local.x + radius) / cell))
	var min_cy := maxi(0, int((local.y - radius) / cell))
	var max_cy := mini(rows - 1, int((local.y + radius) / cell))
	if min_cx > max_cx or min_cy > max_cy:
		return
	var removed := 0
	var removed_pos := Vector2.ZERO
	for cy in range(min_cy, max_cy + 1):
		for cx in range(min_cx, max_cx + 1):
			var mat := _grid[cy * cols + cx]
			if mat == EMPTY:
				continue
			var center := Vector2((cx + 0.5) * cell, (cy + 0.5) * cell)
			var reach := radius * (rock_hardness if mat == ROCK else 1.0)
			if center.distance_to(local) <= reach:
				_grid[cy * cols + cx] = EMPTY
				_tiles.erase_cell(Vector2i(cx, cy))
				_dirty[Vector2i(cx / CHUNK, cy / CHUNK)] = true
				removed += 1
				removed_pos = origin + center
	if removed > 0:
		craters_carved += 1
		_spawn_debris(world_pos, removed_pos)


func surface_y(world_x: float) -> float:
	var cx := int((world_x - origin.x) / cell)
	if cx < 0 or cx >= cols:
		return origin.y
	for cy in rows:
		if _grid[cy * cols + cx] != EMPTY:
			return origin.y + cy * cell
	return origin.y + rows * cell


func _process(_delta: float) -> void:
	_flush_dirty()


func _flush_dirty() -> void:
	var budget := 3
	for key in _dirty.keys():
		_rebuild_chunk(key)
		_dirty.erase(key)
		budget -= 1
		if budget <= 0:
			break


func _rebuild_chunk(cc: Vector2i) -> void:
	var img := Image.create(CHUNK * cell, CHUNK * cell, false, Image.FORMAT_RGBA8)
	for ly in CHUNK:
		var cy: int = cc.y * CHUNK + ly
		if cy >= rows:
			break
		for lx in CHUNK:
			var cx: int = cc.x * CHUNK + lx
			if cx >= cols:
				break
			var mat := _grid[cy * cols + cx]
			if mat == EMPTY:
				continue
			var src_img: Image = _mat_imgs[mat]
			var sx := (cx * cell) % src_img.get_width()
			var sy := (cy * cell) % src_img.get_height()
			img.blit_rect(src_img, Rect2i(sx, sy, cell, cell),
					Vector2i(lx * cell, ly * cell))
	var sprite: Sprite2D = _chunk_sprites.get(cc)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = origin + Vector2(cc) * (CHUNK * cell)
		add_child(sprite)
		_chunk_sprites[cc] = sprite
	sprite.texture = ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ debris ---

func _spawn_debris(at: Vector2, alt: Vector2) -> void:
	if get_tree().get_nodes_in_group("debris").size() > max_debris:
		return
	for i in debris_per_crater:
		var body := RigidBody2D.new()
		body.add_to_group("debris")
		body.collision_layer = 4
		body.collision_mask = 1
		body.mass = 0.5
		body.position = at.lerp(alt, randf()) + Vector2(randf_range(-8, 8), randf_range(-14, -2))
		body.linear_velocity = Vector2(randf_range(-160, 160), randf_range(-380, -120))
		body.angular_velocity = randf_range(-9.0, 9.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(6, 6)
		shape.shape = rect
		body.add_child(shape)
		var poly := Polygon2D.new()
		var s := randf_range(2.5, 4.5)
		poly.polygon = PackedVector2Array([
			Vector2(-s, -s), Vector2(s, -s * 0.7), Vector2(s * 0.8, s), Vector2(-s * 0.6, s)])
		poly.color = Color(0.42, 0.34, 0.24) if randf() < 0.7 else Color(0.35, 0.35, 0.36)
		body.add_child(poly)
		add_child(body)
		get_tree().create_timer(debris_lifetime + randf() * 0.8).timeout.connect(body.queue_free)
