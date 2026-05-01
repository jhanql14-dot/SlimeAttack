extends Node2D

@export var slime_scene: PackedScene
var max_slimes := 50
var spawn_enabled := false
var queued_users := []

var _ws := WebSocketPeer.new()
var _ws_url := "ws://localhost:8080"

func _ready():
	_conectar_websocket()
	Global.connect("toggle_spawn", Callable(self, "_on_toggle_spawn"))
	Global.connect("update_phase", Callable(self, "_on_update_phase"))
	spawn_enabled = Global.game_phase == 1
	if spawn_enabled:
		print("🟢 Spawn inicial habilitado porque ya estamos en fase 1")
		_spawn_queued_slimes()

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
					var usuario = data.get("usuario", "?")
					print("🎮 Nuevo jugador: ", usuario, " → intento de slime")
					_queue_or_spawn(usuario)
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
		_queue_or_spawn("")

func _on_toggle_spawn(enabled):
	spawn_enabled = enabled
	if enabled and Global.game_phase == 1:
		print("🟢 Fase 1 iniciada: spawn habilitado")
		_spawn_queued_slimes()

func _on_update_phase(fase):
	if fase == 1:
		spawn_enabled = true
		print("🟢 Fase 1: reanudando colas")
		_spawn_queued_slimes()
	else:
		spawn_enabled = false
		print("🔴 Fase ", fase, ": spawn deshabilitado")

func _queue_or_spawn(usuario):
	var slime_count = get_tree().get_nodes_in_group("slimes").size()
	if Global.game_phase == 1 and slime_count < max_slimes:
		crear_slime(usuario)
		if slime_count + 1 >= max_slimes:
			print("⚠️ Límite de ", max_slimes, " slimes alcanzado. Iniciando fase 2...")
			Global.game_phase = 2
			Global.emit_signal("toggle_spawn", false)
			print("🔴 Fase 2 activa")
	else:
		queued_users.append(usuario)
		print("⏳ Cola de espera (", queued_users.size(), "):", queued_users)

func _spawn_queued_slimes():
	var slime_count = get_tree().get_nodes_in_group("slimes").size()
	while spawn_enabled and queued_users.size() > 0 and slime_count < max_slimes:
		var usuario = queued_users.pop_front()
		print("📤 Sacando de cola y spawneando: ", usuario)
		crear_slime(usuario)
		slime_count += 1
	if queued_users.size() > 0 and slime_count >= max_slimes:
		print("⏳ Quedan en cola: ", queued_users.size())

func crear_slime(usuario = ""):
	if slime_scene == null:
		print("ERROR: asigna Slime.tscn")
		return

	var slime = slime_scene.instantiate()
	slime.global_position = Vector2(100, 0)
	
	var slime_body = slime.get_node("CharacterBody2D")
	var nombre_asignar = usuario if usuario != "" else "Jugador" + str(randi() % 1000)
	slime_body.nombre = nombre_asignar

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
