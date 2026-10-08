extends Node2D

var travel := 0.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,640,400), Color("203c49"))
	draw_rect(Rect2(0,150,640,250), Color("2b5560"))
	draw_rect(Rect2(462 - fmod(travel * 0.05, 50),76,44,44), Color("ffda91"))
	for i in range(-1, 9):
		var x := i * 110.0 - fmod(travel * 0.16,110)
		var y := 178.0 + (i % 3) * 18
		draw_rect(Rect2(x,y,90,230), Color("356773"))
		draw_rect(Rect2(x+16,y-22,58,30), Color("356773"))
		draw_rect(Rect2(x+32,y-38,26,25), Color("356773"))
	for i in range(-1, 12):
		var x := i * 78.0 - fmod(travel * 0.32,78)
		var y := 255.0 + (i % 3) * 16
		draw_rect(Rect2(x+33,y,10,180), Color("244c53"))
		draw_rect(Rect2(x+10,y+10,58,30), Color("3c7d74"))
		draw_rect(Rect2(x+19,y-7,40,30), Color("3c7d74"))
		draw_rect(Rect2(x+28,y-19,22,20), Color("3c7d74"))
	for i in range(14):
		var x := fposmod(i * 63.0 - travel * 0.08,640)
		draw_rect(Rect2(x,90 + (i * 37) % 190,2,2), Color("83b6a2"))
