extends Node2D

@export var slime_scene: PackedScene

var _ws := WebSocketPeer.new()
var _ws_url := "ws://localhost:8080"

func _ready():
	_conectar_websocket()

func _process(_delta):
	_ws.poll()
	var state = _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			var raw = _ws.get_packet()
			var texto = raw.get_string_from_utf8()
			var json = JSON.new()
			var err = json.parse(texto)
			if err == OK:
				var data = json.get_data()
				if data.get("type") == "join":
					print("🎮 Nuevo jugador: ", data.get("usuario", "?"), " → spawneando slime")
					crear_slime()
	elif state == WebSocketPeer.STATE_CLOSED:
		# Reintentar conexión cada vez que se cierre
		_conectar_websocket()

func _conectar_websocket():
	var err = _ws.connect_to_url(_ws_url)
	if err != OK:
		print("⚠️ No se pudo conectar al WebSocket: ", err)
	else:
		print("🔌 Intentando conectar al bridge de TikTok...")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		crear_slime()

func crear_slime():
	if slime_scene == null:
		print("ERROR: asigna Slime.tscn")
		return

	var slime = slime_scene.instantiate()
	slime.global_position = Vector2(100, 0)

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
