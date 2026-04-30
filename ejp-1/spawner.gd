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
	slime.global_position = Vector2(100,  0)

	var color_random = Color(randf(), randf(), randf())
	
	aplicar_color_shader(slime, color_random)
	
	_cambiar_color_recursivo(slime, color_random)
	add_child(slime)
	
func _cambiar_color_recursivo(nodo, color):
	if nodo is CanvasItem:
		nodo.modulate = color
	
	for hijo in nodo.get_children():
		_cambiar_color_recursivo(hijo, color)
	# 🔹 Intentar asignar color sin romper el juego
func aplicar_color_shader(nodo, color):
	if nodo is CanvasItem:
		var mat = ShaderMaterial.new()
		mat.shader = preload("res://slime_tint.gdshader")
		mat.set_shader_parameter("tint_color", color)
		nodo.material = mat

	for hijo in nodo.get_children():
		aplicar_color_shader(hijo, color)
