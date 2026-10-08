class_name OrchardArt
extends RefCounted

static func animation(path: String, cell: Vector2i, fps: float = 16.0) -> AnimatedSprite2D:
	var texture := load("res://assets/" + path) as Texture2D
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	for i in range(texture.get_width() / cell.x):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * cell.x, 0, cell.x, cell.y)
		frames.add_frame("default", atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play()
	return sprite

static func texture(path: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/" + path)
	return sprite

