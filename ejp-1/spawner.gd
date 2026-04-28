extends Node2D

@export var slime_scene: PackedScene

func _input(event):
	if event.is_action_pressed("ui_accept"):
		crear_slime()

func crear_slime():
	if slime_scene == null:
		print("ERROR: asigna Slime.tscn")
		return

	var slime = slime_scene.instantiate()

	slime.global_position = Vector2(150, 30)

	# 🔹 Intentar asignar color sin romper el juego
	if "color_personaje" in slime:
		slime.color_personaje = Color(randf(), randf(), randf())
	else:
		print("Aviso: slime sin variable color_personaje")

	add_child(slime)
