extends Node2D

@export var slime_scene: PackedScene
var max_slimes := 50
var spawn_enabled := false
var queued_users := []
var active_users := {} # { "nombre": timestamp } para saber quién sigue en el live

@export var spawn_position := Vector2(100, -450)
@export var colores_posibles: Array[Color] = [
	Color(0.2, 0.8, 0.2), # Verde
	Color(0.2, 0.2, 0.8), # Azul
	Color(0.8, 0.2, 0.2), # Rojo
	Color(0.8, 0.8, 0.2), # Amarillo
	Color(0.8, 0.2, 0.8)  # Morado
]

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
					active_users[usuario] = Time.get_ticks_msec()
					print("🎮 Nuevo jugador: ", usuario, " → intento de slime")
					_queue_or_spawn(usuario)
				elif data.get("type") == "leave":
					var usuario = data.get("usuario", "?")
					active_users.erase(usuario)
					print("🚪 Jugador salió: ", usuario)
				elif data.get("type") == "taptap":
					var cantidad = int(data.get("cantidad", 1))
					Global.add_taps(cantidad)
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
		print("🟢 Fase 1: reanudando colas y re-spawneando activos")
		_respawn_active_players()
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

func _respawn_active_players():
	# Intentar re-spawnear a los que ya tienen datos (estuvieron en la ronda anterior)
	# Solo si siguen activos en el live
	var slime_count = get_tree().get_nodes_in_group("slimes").size()
	
	for usuario in Global.player_data.keys():
		if slime_count >= max_slimes: break
		
		# Solo si el usuario está en active_users (marcado por el bridge)
		if active_users.has(usuario):
			crear_slime(usuario)
			slime_count += 1
		else:
			print("⏭️ Saltando respawn de ", usuario, " (no activo)")

func _spawn_queued_slimes():
	var slime_count = get_tree().get_nodes_in_group("slimes").size()
	while spawn_enabled and queued_users.size() > 0 and slime_count < max_slimes:
		var usuario = queued_users.pop_front()
		# Evitar duplicados si ya se re-spawnearon
		var ya_esta = false
		for s in get_tree().get_nodes_in_group("slimes"):
			if s.nombre == usuario:
				ya_esta = true
				break
		
		if not ya_esta:
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
	slime.global_position = spawn_position
	
	var slime_body = slime.get_node("CharacterBody2D")
	var nombre_asignar = usuario if usuario != "" else "Jugador" + str(randi() % 1000)
	slime_body.nombre = nombre_asignar

	# RESTAURAR PERSISTENCIA
	if Global.player_data.has(nombre_asignar):
		var data = Global.player_data[nombre_asignar]
		# Usar get_node porque @onready sprite aún no está listo
		var sprite_node = slime_body.get_node("Sprite2D")
		if sprite_node:
			sprite_node.scale = Vector2(data.scale, data.scale)
		
		slime_body.consecutive_victories = data.wins
		slime_body.total_wins = data.get("total_wins", 0)
		slime_body.attack_damage_min = data.damage_min
		slime_body.attack_damage_max = data.damage_max
		slime_body.attack_range = data.range
		
		aplicar_color_shader(slime, data.color)
		_cambiar_color_recursivo(slime, data.color)
		print("♻️ Restaurado stats de ", nombre_asignar, ": Scale ", data.scale)
	else:
		var color_final: Color
		if colores_posibles.size() > 0:
			color_final = colores_posibles.pick_random()
		else:
			color_final = Color(randf(), randf(), randf())

		aplicar_color_shader(slime, color_final)
		_cambiar_color_recursivo(slime, color_final)
	add_child(slime)
	
	# 🔊 Sonido de aparición
	var spawn_sound = AudioStreamPlayer.new()
	spawn_sound.stream = preload("res://sounds/95_CreateBubble.mp3")
	add_child(spawn_sound)
	spawn_sound.play()
	spawn_sound.finished.connect(spawn_sound.queue_free)

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
