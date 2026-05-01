extends Node2D

@export var slime_scene: PackedScene
var nombre: String = ""
# 🔤 Generador de nombres
var inicio := ["Bl", "Sl", "Kr", "Dr", "Pl"]
var medio := ["a", "o", "u", "i"]
var final := ["p", "m", "sh", "g", "x"]

func _ready() -> void:
	randomize()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		crear_slime()

func crear_slime() -> void:
	if slime_scene == null:
		push_error("ERROR: asigna Slime.tscn en el inspector")
		return

	var slime := slime_scene.instantiate()
	if slime == null:
		push_error("ERROR: no se pudo instanciar el slime")
		return

	slime.global_position = Vector2(100, 0)

	# 🎲 Color aleatorio (válido entre 0 y 1)
	var color_random := Color(randf(), randf(), randf(), 1.0)

	# 🎨 Aplicar color
	_aplicar_color(slime, color_random)

	# 🔤 Generar nombre
	var nombre := "%s %s" % [nombre_por_color(color_random), generar_nombre()]

	# ⚠️ Asignar nombre solo si existe la variable
	if slime.has_method("set"):
		slime.set("nombre", nombre)
	else:
		print("Advertencia: el slime no tiene propiedad 'nombre'")

	print("Slime creado:", nombre)

	add_child(slime)

# 🔤 Generar nombre procedural
func generar_nombre() -> String:
	return inicio.pick_random() + medio.pick_random() + final.pick_random()

# 🎨 Nombre según color dominante
func nombre_por_color(color: Color) -> String:
	if color.r > color.g and color.r > color.b:
		return "Red"
	elif color.g > color.r and color.g > color.b:
		return "Green"
	elif color.b > color.r and color.b > color.g:
		return "Blue"
	else:
		return "Gray"

# 🎨 Aplicar color (shader + modulate de forma segura)
func _aplicar_color(nodo: Node, color: Color) -> void:
	if nodo is CanvasItem:
		# Crear material único por instancia (evita bugs de compartir material)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://slime_tint.gdshader")
		mat.set_shader_parameter("tint_color", color)

		# Duplicar material si ya tenía uno (extra seguro)
		nodo.material = mat

		# También aplicar modulate como fallback
		nodo.modulate = color

	for hijo in nodo.get_children():
		_aplicar_color(hijo, color)
