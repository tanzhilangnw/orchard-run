extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_run()
	game.muted = true
	var hero = game.hero
	Input.action_press("right")
	var held := 0
	var last_segment := -1
	var furthest := 0.0
	var stalled := 0
	for frame in 8000:
		await physics_frame
		if game.state == "win":
			print("ROUTE_PASS x=",hero.position.x," deaths=",game.deaths," checkpoints=",game.checkpoint_index," fruit=",game.fruit_count," frames=",frame)
			Input.action_release("right")
			Input.action_release("jump")
			quit(0 if game.deaths == 0 and game.checkpoint_index == 3 else 2)
			return
		if hero.position.x > furthest + 1:
			furthest = hero.position.x
			stalled = 0
		else:
			stalled += 1
		if stalled > 500 or game.deaths > 0:
			print("ROUTE_FAIL x=",hero.position.x," y=",hero.position.y," velocity=",hero.velocity," deaths=",game.deaths," furthest=",furthest)
			quit(2)
			return
		if held > 0:
			held -= 1
			if held == 0:
				Input.action_release("jump")
		if not hero.is_on_floor() or held > 0:
			continue
		var jump := false
		for i in game.PLATFORMS.size():
			var rect: Rect2 = game.PLATFORMS[i]
			if hero.position.x >= rect.position.x - 2 and hero.position.x <= rect.end.x + 2 and absf(hero.position.y - rect.position.y) < 3:
				if i != last_segment:
					print("SEGMENT ",i," x=",hero.position.x," y=",hero.position.y)
					last_segment = i
				# Start before the edge so the real player physics has horizontal airtime.
				if i < game.PLATFORMS.size()-1 and rect.end.x - hero.position.x < 105:
					jump = true
		for hazard in get_nodes_in_group("hazards"):
			var distance: float = hazard.get_meta("left") - hero.position.x
			if distance > -20 and distance < 58 and absf(hazard.position.y + 4 - hero.position.y) < 8:
				jump = true
		for enemy in get_nodes_in_group("enemies"):
			var distance: float = enemy.position.x - hero.position.x
			if distance > -15 and distance < 64 and absf(enemy.position.y - hero.position.y) < 8:
				jump = true
		if jump:
			# Exercise the same jump velocity and subsequent CharacterBody2D physics.
			hero.velocity.y = hero.JUMP
			hero.coyote = 0
	print("ROUTE_TIMEOUT ",hero.position)
	quit(2)
