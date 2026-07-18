class_name Assets
extends RefCounted
## Loads textures by fixed manifest path (see ASSETS.md) with a generated
## placeholder fallback, so the game never crashes when art is missing/broken.
## Real art dropped onto the same path hot-swaps in with zero code changes.

const MANIFEST_SIZES := {
	"res://assets/walker/torso.png": Vector2i(160, 200),
	"res://assets/walker/hip.png": Vector2i(120, 90),
	"res://assets/walker/leg_upper.png": Vector2i(60, 100),
	"res://assets/walker/leg_lower.png": Vector2i(50, 95),
	"res://assets/walker/foot.png": Vector2i(90, 50),
	"res://assets/walker/gun.png": Vector2i(220, 70),
	"res://assets/enemies/runner.png": Vector2i(120, 120),
	"res://assets/enemies/paratrooper.png": Vector2i(90, 120),
	"res://assets/enemies/parachute.png": Vector2i(200, 140),
	"res://assets/enemies/burrower.png": Vector2i(140, 100),
	"res://assets/terrain/dirt.png": Vector2i(256, 256),
	"res://assets/terrain/rock.png": Vector2i(256, 256),
	"res://assets/terrain/metal.png": Vector2i(256, 256),
	"res://assets/bg/sky.png": Vector2i(1920, 1080),
	"res://assets/bg/parallax_far.png": Vector2i(1920, 1080),
	"res://assets/bg/parallax_near.png": Vector2i(1920, 1080),
	"res://assets/ui/crosshair.png": Vector2i(96, 96),
}


static func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			return t
	# Not imported (e.g. art dropped in while running from CLI): load raw file.
	var global := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global):
		var img := Image.load_from_file(global)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	push_warning("Missing asset, using placeholder: %s" % path)
	return _placeholder(path)


static func _placeholder(path: String) -> Texture2D:
	var size: Vector2i = MANIFEST_SIZES.get(path, Vector2i(64, 64))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.0, 1.0, 0.85))
	for x in size.x:
		for b in 2:
			img.set_pixel(x, b, Color.WHITE)
			img.set_pixel(x, size.y - 1 - b, Color.WHITE)
	for y in size.y:
		for b in 2:
			img.set_pixel(b, y, Color.WHITE)
			img.set_pixel(size.x - 1 - b, y, Color.WHITE)
	return ImageTexture.create_from_image(img)
