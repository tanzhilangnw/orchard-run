extends Area2D

var left_edge := 0.0
var right_edge := 100.0
var direction := 1.0
var speed := 32.0
var hero: CharacterBody2D
var game: Node
var dead := false
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(22,18)
	shape.shape = box
	shape.position.y = -9
	add_child(shape)
	sprite = OrchardArt.animation("Enemies/Mushroom/Run (32x32).png", Vector2i(32,32), 12)
	sprite.position.y = -16
	add_child(sprite)
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if dead:
		return
	position.x += speed * direction * delta
	if position.x >= right_edge:
		direction = -1
	elif position.x <= left_edge:
		direction = 1
	sprite.flip_h = direction > 0
	for body in get_overlapping_bodies():
		if body == hero and hero.respawn_timer <= 0:
			if hero.velocity.y > 0 and hero.previous_feet.y <= global_position.y - 10:
				dead = true
				hero.stomp()
				game.burst(global_position - Vector2(0,12), Color("ffda91"), 10)
				game.sound("stomp")
				queue_free()
			else:
				hero.take_hit()

