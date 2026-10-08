extends Node2D

const PLAYER = preload("res://player.gd")
const ENEMY = preload("res://enemy.gd")
const BACKDROP = preload("res://background.gd")
const TERRAIN = preload("res://assets/Terrain/Terrain (16x16).png")
const PLATFORMS := [
	Rect2(0,336,416,112), Rect2(464,320,304,128), Rect2(784,304,304,144),
	Rect2(1152,320,256,128), Rect2(1472,288,320,160), Rect2(1824,320,256,128),
	Rect2(2144,304,240,144), Rect2(2448,272,256,176), Rect2(2768,304,496,144)
]

var hero: CharacterBody2D
var world: Node2D
var camera: Camera2D
var backdrop: Node2D
var ui: Control
var modal: Control
var count_label: Label
var time_label: Label
var stage_label: Label
var hint_label: Label
var progress: ProgressBar
var font: SystemFont
var state := "title"
var checkpoint := Vector2(80,336)
var checkpoint_index := 0
var fruit_count := 0
var total_fruit := 0
var deaths := 0
var elapsed := 0.0
var checkpoint_flags: Array[AnimatedSprite2D] = []
var sound_players: Array[AudioStreamPlayer] = []
var sound_cursor := 0
var muted := false
var level_info: Dictionary
var campaign_complete := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_info = GameState.LEVELS[GameState.current_level]
	_setup_input()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	var back_layer := CanvasLayer.new()
	back_layer.layer = -10
	add_child(back_layer)
	backdrop = Node2D.new()
	backdrop.set_script(BACKDROP)
	back_layer.add_child(backdrop)
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	_build_world()
	hero = CharacterBody2D.new()
	hero.set_script(PLAYER)
	hero.name = "Runner"
	hero.position = checkpoint
	hero.z_index = 10
	world.add_child(hero)
	hero.hurt.connect(_on_hurt)
	hero.jumped.connect(func(): sound("jump"))
	camera = Camera2D.new()
	camera.position = Vector2(320,200)
	camera.position_smoothing_enabled = false
	world.add_child(camera)
	_build_enemies()
	for i in 6:
		var channel := AudioStreamPlayer.new()
		channel.volume_db = -14
		add_child(channel)
		sound_players.append(channel)
	_build_ui()
	get_tree().paused = true
	_show_card("奶龙大冒险", "MILK DRAGON RUN   /   " + level_info.name, level_info.brief + "\n\n水果影响评分，抵达终点即可进入下一关。", "开始第 %d 关" % (GameState.current_level + 1), _start_run)

func _setup_input() -> void:
	var bindings := {"left":[KEY_A,KEY_LEFT], "right":[KEY_D,KEY_RIGHT], "jump":[KEY_SPACE,KEY_W,KEY_UP], "pause":[KEY_ESCAPE], "restart":[KEY_R], "fullscreen":[KEY_F11], "mute":[KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action,event):
				InputMap.action_add_event(action,event)

func _process(delta: float) -> void:
	if state == "play":
		elapsed += delta
		camera.position.x = clampf(hero.position.x + 65,320,2944)
		backdrop.travel = camera.position.x - 320
		time_label.text = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
		progress.value = hero.position.x / 3150.0 * 100.0
		var section := 0 if hero.position.x < 1120 else (1 if hero.position.x < 2120 else 2)
		stage_label.text = level_info.name + "  ·  路段 %d / 3" % (section + 1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("mute"):
		muted = not muted
		hint_label.text = "音效已静音 · M 恢复" if muted else "音效已开启"
	elif event.is_action_pressed("pause"):
		if state == "play":
			state = "pause"
			get_tree().paused = true
			_show_card("休息一下", "TAKE A BREATH", "路上的旗帜会记录复活位置。\n轻点空格短跳，按住空格跳得更高。", "继续前进", _resume)
		elif state == "pause":
			_resume()
	elif event.is_action_pressed("restart") and state != "title":
		_restart()

func _build_world() -> void:
	# A continuous orchard trail guarantees that every screen has a safe route;
	# raised platforms are optional routes for fruit and faster movement.
	var level_skin := int(level_info.skin)
	_platform(Rect2(0,336,3264,112), level_skin, true)
	for i in PLATFORMS.size():
		_platform(PLATFORMS[i], (i / 3 + level_skin) % 3, false)
		var rect: Rect2 = PLATFORMS[i]
		for j in 3:
			_fruit(Vector2(rect.position.x + 90 + j * 48, rect.position.y - 40), (i + j + level_skin) % 3)
		_decor(rect, (i / 3 + level_skin) % 3)
	for rect in [Rect2(240,256,96,16), Rect2(928,224,96,16), Rect2(1568,208,96,16), Rect2(2528,192,96,16)]:
		_platform(rect, 0 if rect.position.x < 1120 else (1 if rect.position.x < 2120 else 2), true)
		_fruit(rect.position + Vector2(28,-26), 2)
		_fruit(rect.position + Vector2(68,-26), 2)
	_spikes(928,304,32)
	_spikes(1272,320,32)
	_spikes(1936,320,32)
	_spikes(2560,272,32)
	_add_checkpoint(Vector2(824,320), 1)
	_add_checkpoint(Vector2(1200,320), 2)
	_add_checkpoint(Vector2(2192,320), 3)
	var start := OrchardArt.texture("Items/Checkpoints/Start/Start (Idle).png")
	start.position = Vector2(80,312)
	world.add_child(start)
	var end := OrchardArt.animation("Items/Checkpoints/End/End (Pressed) (64x64).png",Vector2i(64,64),12)
	end.position = Vector2(3150,280)
	world.add_child(end)
	var goal := _area(Vector2(3150,312),Vector2(44,48))
	goal.body_entered.connect(func(body):
		if body == hero and state == "play":
			_finish())
	_sign("A / D 或方向键移动", Vector2(94,290))
	_sign("空格跳跃 · 按住跳得更高", Vector2(292,208))
	_sign("踩蘑菇头顶可以弹起", Vector2(510,246))
	_sign(level_info.name, Vector2(32,106),22)
	_sign(["果香云海", "蜂蜜暮色", "糖山月光"][GameState.current_level], Vector2(1160,106),22)
	_sign("终点奖杯", Vector2(2160,106),22)
	_sign("最后一程  →", Vector2(2940,226),16)

func _platform(rect: Rect2, skin: int, ledge: bool) -> void:
	var body := StaticBody2D.new()
	body.name = "Ground_%d" % int(rect.position.x)
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	shape.one_way_collision = true
	body.add_child(shape)
	world.add_child(body)
	body.set_meta("rect",rect)
	body.add_to_group("ground")
	for y in range(int(rect.size.y / 16)):
		for x in range(int(rect.size.x / 16)):
			var tile := Sprite2D.new()
			var atlas := AtlasTexture.new()
			atlas.atlas = TERRAIN
			var column := 0 if x == 0 else (2 if x == int(rect.size.x / 16) - 1 else 1)
			atlas.region = Rect2(96 + column * 16, skin * 64 + (0 if y == 0 else 16),16,16)
			tile.texture = atlas
			tile.position = rect.position + Vector2(x*16+8,y*16+8)
			world.add_child(tile)

func _decor(rect: Rect2, skin: int) -> void:
	for i in range(2, int(rect.size.x / 32), 3):
		var grass := Polygon2D.new()
		grass.position = Vector2(rect.position.x+i*32,rect.position.y)
		grass.polygon = PackedVector2Array([Vector2(-5,0),Vector2(-7,-7),Vector2(-1,-3),Vector2(1,-10),Vector2(4,-3),Vector2(9,-6),Vector2(6,0)])
		grass.color = [Color("92c461"),Color("e6ad66"),Color("c99ccc")][skin]
		world.add_child(grass)

func _area(point: Vector2, size: Vector2) -> Area2D:
	var area := Area2D.new()
	area.position = point
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	collision.shape = rect
	area.add_child(collision)
	world.add_child(area)
	return area

func _fruit(point: Vector2, kind: int) -> void:
	total_fruit += 1
	var area := _area(point, Vector2(18,18))
	area.add_to_group("fruit")
	var sprite := OrchardArt.animation("Items/Fruits/" + ["Apple", "Orange", "Cherries"][kind] + ".png", Vector2i(32,32))
	area.add_child(sprite)
	area.body_entered.connect(func(body):
		if body != hero or area.get_meta("collected",false):
			return
		area.set_meta("collected",true)
		fruit_count += 1
		count_label.text = "%02d / %02d" % [fruit_count,total_fruit]
		burst(point, Color("ffd788"),6)
		sound("collect")
		area.queue_free())

func _spikes(x: float, y: float, width: float) -> void:
	var area := _area(Vector2(x+width/2,y-4),Vector2(width-6,8))
	# Spikes decorate the elevated side routes. The main orchard trail below stays safe.
	area.collision_mask = 0
	for i in int(width/16):
		var sprite := OrchardArt.texture("Traps/Spikes/Idle.png")
		sprite.position = Vector2(-width/2+i*16+8,-4)
		area.add_child(sprite)

func _add_checkpoint(point: Vector2, index: int) -> void:
	var flag := OrchardArt.animation("Items/Checkpoints/Checkpoint/Checkpoint (Flag Idle)(64x64).png",Vector2i(64,64),12)
	flag.position = point + Vector2(0,-24)
	flag.modulate = Color("b3c1b8")
	world.add_child(flag)
	checkpoint_flags.append(flag)
	var area := _area(point+Vector2(0,-16),Vector2(24,32))
	area.body_entered.connect(func(body):
		if body == hero and index > checkpoint_index:
			checkpoint_index = index
			checkpoint = point
			flag.modulate = Color.WHITE
			hint_label.text = "旗帜已点亮 · 失误后从这里继续"
			burst(point+Vector2(0,-35),Color("93e0b3"),12)
			sound("checkpoint"))

func _build_enemies() -> void:
	for spec in [Vector4(640,272,620,660),Vector4(1632,272,1616,1664),Vector4(2910,272,2870,2990)]:
		var enemy := Area2D.new()
		enemy.set_script(ENEMY)
		enemy.position = Vector2(spec.x,spec.y)
		enemy.left_edge = spec.z
		enemy.right_edge = spec.w
		enemy.hero = hero
		enemy.game = self
		world.add_child(enemy)

func _sign(text: String, point: Vector2, size: int = 11) -> void:
	var label := _label(text,size,Color("e4e4c5"))
	label.position = point
	label.z_index = 2
	world.add_child(label)

func _label(text: String, size: int, color: Color = Color("faf0d7")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color("18343e"))
	label.add_theme_constant_override("shadow_offset_y",1)
	return label

func _style(color: Color, border: Color = Color("63847b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var bar := Panel.new()
	bar.position = Vector2(12,10)
	bar.size = Vector2(616,48)
	bar.add_theme_stylebox_override("panel",_style(Color("19333fea")))
	ui.add_child(bar)
	var title := _label("奶龙大冒险",17)
	title.position = Vector2(12,4)
	bar.add_child(title)
	stage_label = _label(level_info.name,10,Color("a9cdb6"))
	stage_label.position = Vector2(12,28)
	bar.add_child(stage_label)
	var fruit_icon := OrchardArt.animation("Items/Fruits/Apple.png",Vector2i(32,32))
	fruit_icon.position = Vector2(440,24)
	bar.add_child(fruit_icon)
	count_label = _label("00 / %02d" % total_fruit,16,Color("ffe1a0"))
	count_label.position = Vector2(456,13)
	bar.add_child(count_label)
	time_label = _label("00:00",14)
	time_label.position = Vector2(550,14)
	bar.add_child(time_label)
	progress = ProgressBar.new()
	progress.position = Vector2(150,23)
	progress.size = Vector2(250,5)
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background",_style(Color("284f58"),Color("284f58")))
	progress.add_theme_stylebox_override("fill",_style(Color("98cb8d"),Color("98cb8d")))
	bar.add_child(progress)
	hint_label = _label("A/D 移动    空格跳跃    Esc 暂停    R 重开    M 静音",11,Color("e3deba"))
	hint_label.position = Vector2(20,376)
	ui.add_child(hint_label)

func _show_card(title: String, kicker: String, text: String, button_text: String, callback: Callable) -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035,0.08,0.11,0.76)
	modal.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(84,67)
	panel.size = Vector2(472,286)
	panel.add_theme_stylebox_override("panel",_style(Color("183b46"),Color("9bbda0")))
	modal.add_child(panel)
	var accent := ColorRect.new()
	accent.color = Color("b7d793")
	accent.position = Vector2(0,0)
	accent.size = Vector2(472,4)
	panel.add_child(accent)
	var small := _label(kicker,11,Color("9ccaaa"))
	small.position = Vector2(28,20)
	panel.add_child(small)
	var heading := _label(title,36,Color("ffe0a0"))
	heading.position = Vector2(26,41)
	panel.add_child(heading)
	var copy := _label(text,14)
	copy.position = Vector2(28,104)
	copy.size = Vector2(416,105)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(copy)
	var button := Button.new()
	button.position = Vector2(28,226)
	button.size = Vector2(270,38)
	button.text = button_text + "  →"
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",Color("203b40"))
	button.add_theme_stylebox_override("normal",_style(Color("bcd993")))
	button.add_theme_stylebox_override("hover",_style(Color("e1edb1")))
	button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),Color("fff1c1")))
	button.pressed.connect(callback)
	panel.add_child(button)
	button.grab_focus()
	var quit_button := Button.new()
	quit_button.position = Vector2(322,226)
	quit_button.size = Vector2(122,38)
	quit_button.text = "退出游戏"
	quit_button.add_theme_font_override("font",font)
	quit_button.add_theme_stylebox_override("normal",_style(Color("294f58")))
	quit_button.pressed.connect(func(): get_tree().quit())
	panel.add_child(quit_button)

func _start_run() -> void:
	state = "play"
	get_tree().paused = false
	modal.queue_free()
	modal = null

func _resume() -> void:
	_start_run()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_hurt() -> void:
	deaths += 1
	burst(hero.position-Vector2(0,12),Color("ff987c"),14)
	sound("hurt")
	hero.respawn(checkpoint)
	hint_label.text = "回到最近旗帜 · 水果收集进度保留"

func _finish() -> void:
	state = "win"
	get_tree().paused = true
	sound("win")
	var rank := "果园探路者"
	if fruit_count >= total_fruit * 0.85:
		rank = "金果大师"
	elif fruit_count >= total_fruit * 0.55:
		rank = "熟练采果人"
	var has_next := GameState.advance()
	campaign_complete = not has_next
	var next_text := "进入第 %d 关" % (GameState.current_level + 1) if has_next else "重新开始冒险"
	var finish_copy := "水果  %d / %d      用时  %02d:%02d\n失误  %d 次\n\n" % [fruit_count,total_fruit,int(elapsed)/60,int(elapsed)%60,deaths]
	finish_copy += "下一关已开启：" + GameState.LEVELS[GameState.current_level].name if has_next else "三张地图已经全部通过，奶龙带着水果回家了。"
	_show_card("关卡完成！", "DELIVERY COMPLETE   /   " + rank, finish_copy, next_text, _advance_or_restart)

func _advance_or_restart() -> void:
	if campaign_complete:
		GameState.restart_campaign()
	get_tree().paused = false
	get_tree().reload_current_scene()

func burst(point: Vector2, color: Color, count: int) -> void:
	for i in count:
		var particle := Polygon2D.new()
		particle.polygon = PackedVector2Array([Vector2(-1,-1),Vector2(2,-1),Vector2(2,2),Vector2(-1,2)])
		particle.color = color
		particle.position = point
		particle.z_index = 20
		world.add_child(particle)
		var tween := particle.create_tween().set_parallel(true)
		tween.tween_property(particle,"position",point+Vector2(randf_range(-26,26),randf_range(-30,10)),0.38)
		tween.tween_property(particle,"modulate:a",0.0,0.38)
		tween.chain().tween_callback(particle.queue_free)

func sound(kind: String) -> void:
	if muted or sound_players.is_empty():
		return
	var channel := sound_players[sound_cursor % sound_players.size()]
	sound_cursor += 1
	channel.stream = load("res://audio/" + kind + ".wav")
	channel.play()
