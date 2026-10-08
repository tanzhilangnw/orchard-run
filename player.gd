extends CharacterBody2D

signal hurt
signal jumped
const SPEED := 190.0
const JUMP := -480.0
const GRAVITY := 1250.0
var sprite: AnimatedSprite2D
var frames := SpriteFrames.new()
var coyote := 0.0
var buffer := 0.0
var grace := 0.0
var respawn_timer := 0.0
var respawn_point := Vector2.ZERO
var previous_feet := Vector2.ZERO
var enabled := true

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	floor_snap_length = 5.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(14, 24)
	shape.shape = box
	shape.position.y = -12
	add_child(shape)
	frames.remove_animation("default")
	var hero_sheet := load("res://assets/milk_dragon_hero.png") as Texture2D
	var poses := {"Idle": 0, "Run": 1, "Jump": 2, "Fall": 3, "Hit": 0}
	for name in poses:
		frames.add_animation(name)
		frames.set_animation_speed(name, 8)
		var atlas := AtlasTexture.new()
		atlas.atlas = hero_sheet
		atlas.region = Rect2(poses[name] * 543, 0, 543, 724)
		frames.add_frame(name, atlas)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.position = Vector2(0, -23)
	sprite.scale = Vector2(0.052, 0.052)
	add_child(sprite)
	sprite.play("Idle")

func _physics_process(delta: float) -> void:
	previous_feet = global_position
	grace = maxf(0, grace - delta)
	if respawn_timer > 0:
		respawn_timer -= delta
		if respawn_timer <= 0:
			global_position = respawn_point
			velocity = Vector2.ZERO
			coyote = 0
			buffer = 0
			visible = true
			grace = 1.0
		return
	if not enabled:
		return
	sprite.modulate.a = 0.45 if grace > 0 and int(grace * 16) % 2 == 0 else 1.0
	coyote = 0.12 if is_on_floor() else maxf(0, coyote - delta)
	buffer = 0.14 if Input.is_action_just_pressed("jump") else maxf(0, buffer - delta)
	var direction := Input.get_axis("left", "right")
	velocity.x = move_toward(velocity.x, direction * SPEED, (1500.0 if direction == 0 else 1300.0) * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, 650)
	if buffer > 0 and coyote > 0:
		velocity.y = JUMP
		buffer = 0
		coyote = 0
		jumped.emit()
	elif Input.is_action_just_released("jump") and velocity.y < -160:
		velocity.y *= 0.55
	move_and_slide()
	if direction != 0:
		sprite.flip_h = direction < 0
	sprite.play("Jump" if velocity.y < -20 else ("Fall" if not is_on_floor() else ("Run" if absf(velocity.x) > 10 else "Idle")))
	if position.y > 465:
		take_hit()

func take_hit() -> void:
	if grace <= 0 and respawn_timer <= 0 and enabled:
		hurt.emit()

func respawn(point: Vector2) -> void:
	respawn_point = point
	respawn_timer = 0.2
	velocity = Vector2.ZERO
	visible = false

func stomp() -> void:
	velocity.y = -330
	grace = 0.12

