extends Node

var game_phase := 1
var time_left := 0

signal update_time(tiempo)
signal update_phase(fase)
signal toggle_spawn(enabled)

var current_round := 1
var last_round_winner := "Nadie"

# Persistencia de datos por usuario: { "nombre": { "scale": 1.0, "wins": 0, "damage_mult": 1.0, "color": Color(...) } }
var player_data := {}

var hud : CanvasLayer
var lbl_timer : Label
var lbl_leaderboard : Label
var lbl_winner : Label
var lbl_last_winner : Label
var lbl_taps : Label
var lbl_announcement : Label
var total_taps := 0
var rain_active := false
var first_blood_happened := false
var target_taps := 1000
var effect_running := false
var last_thousand_triggered := 0
var last_hit_msec := 0
var black_slime_spawned := false

# Parámetros para anuncios de Kill (puedes cambiarlos aquí)
var announcement_y_pos := 250.0 # Posición vertical (más alto o más bajo)
var announcement_font_size := 50

func _ready():
	_crear_interfaz()
	# 🎵 Música de fondo en bucle
	var bgm = AudioStreamPlayer.new()
	var stream = preload("res://sounds/13_RainbowgeddonIntro.mp3")
	stream.loop = true # Activar bucle
	bgm.stream = stream
	bgm.bus = "Master"
	bgm.volume_db = -21.0 # Reducir volumen
	add_child(bgm)
	bgm.play()
	update_environment()
	restore_platforms()
	run_game_loop()

func _crear_interfaz():
	hud = CanvasLayer.new()
	add_child(hud)
	
	# Timer (Arriba Centro)
	lbl_timer = Label.new()
	lbl_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_timer.add_theme_font_size_override("font_size", 32)
	lbl_timer.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_timer.add_theme_constant_override("outline_size", 8)
	lbl_timer.size = Vector2(400, 100)
	lbl_timer.position = Vector2(get_viewport().size.x / 2 - 200, 20)
	hud.add_child(lbl_timer)
	
	# Leaderboard (Abajo Izquierda)
	lbl_leaderboard = Label.new()
	lbl_leaderboard.add_theme_font_size_override("font_size", 16)
	lbl_leaderboard.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_leaderboard.add_theme_constant_override("outline_size", 6)
	lbl_leaderboard.position = Vector2(30, get_viewport().size.y - 150)
	hud.add_child(lbl_leaderboard)
	
	# Último Ganador (Abajo Derecha)
	lbl_last_winner = Label.new()
	lbl_last_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_last_winner.add_theme_font_size_override("font_size", 18)
	lbl_last_winner.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_last_winner.add_theme_constant_override("outline_size", 10)
	lbl_last_winner.size = Vector2(500, 100)
	lbl_last_winner.position = Vector2(get_viewport().size.x - 530, get_viewport().size.y - 120)
	hud.add_child(lbl_last_winner)
	
	# Ganador (Centro)
	lbl_winner = Label.new()
	lbl_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_winner.add_theme_font_size_override("font_size", 60)
	lbl_winner.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_winner.add_theme_constant_override("outline_size", 12)
	lbl_winner.size = Vector2(800, 200)
	lbl_winner.position = Vector2(get_viewport().size.x / 2 - 400, get_viewport().size.y / 2 - 100)
	lbl_winner.visible = false
	hud.add_child(lbl_winner)
	
	# Contador de Taps (Arriba Derecha)
	lbl_taps = Label.new()
	lbl_taps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_taps.add_theme_font_size_override("font_size", 24)
	lbl_taps.add_theme_color_override("font_color", Color.WHITE)
	lbl_taps.add_theme_color_override("font_outline_color", Color.MEDIUM_VIOLET_RED)
	lbl_taps.add_theme_constant_override("outline_size", 10)
	lbl_taps.size = Vector2(400, 50)
	lbl_taps.position = Vector2(get_viewport().size.x - 430, 20)
	lbl_taps.text = "💖 0/100"
	hud.add_child(lbl_taps)
	
	# Anuncio de Kills (Centro)
	lbl_announcement = Label.new()
	lbl_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_announcement.add_theme_font_size_override("font_size", announcement_font_size)
	lbl_announcement.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_announcement.add_theme_constant_override("outline_size", 14)
	lbl_announcement.size = Vector2(1000, 150)
	lbl_announcement.position = Vector2(get_viewport().size.x / 2 - 500, announcement_y_pos)
	lbl_announcement.visible = false
	hud.add_child(lbl_announcement)

func _actualizar_interfaz():
	# Texto de Fase
	var phase_text = ""
	match game_phase:
		1: phase_text = " RONDA " + str(current_round) + " "
		2: phase_text = "¡A PELEAR!"
		3: phase_text = "RESULTADOS"
	
	lbl_timer.text = phase_text + "\n" + str(time_left) + "s"
	
	# Leaderboard (Top 5)
	var slimes = get_tree().get_nodes_in_group("slimes")
	slimes.sort_custom(func(a, b): 
		if not is_instance_valid(a) or not is_instance_valid(a.sprite): return false
		if not is_instance_valid(b) or not is_instance_valid(b.sprite): return true
		return a.sprite.scale.x > b.sprite.scale.x
	)
	
	# Actualizar Top 5 (Izquierda)
	var top_text = ""
	for i in range(min(5, slimes.size())):
		var s = slimes[i]
		var icon = ""
		match i:
			0: icon = "🥇 "
			1: icon = "🥈 "
			2: icon = "🥉 "
			_: icon = "🔹 "
		var dmg_avg = int((s.attack_damage_min + s.attack_damage_max) / 2.0)
		top_text += icon + s.nombre + " [" + str(s.consecutive_victories) + "🏆] ❤️" + str(int(s.health)) + " ⚔️" + str(dmg_avg) + "\n"
	
	lbl_leaderboard.text = top_text
	
	# Actualizar Último Ganador (Derecha)
	if last_round_winner != "Nadie":
		lbl_last_winner.text = "🏆 ULT. GANADOR\n" + last_round_winner
	else:
		lbl_last_winner.text = ""
	
	# Determinar el siguiente objetivo de taps
	if total_taps < 100: target_taps = 100
	elif total_taps < 500: target_taps = 500
	else: target_taps = 1000
	
	# Nuevos hitos de taps (Cada 1000 taps)
	var current_thousands = int(total_taps / 1000)
	if not effect_running and current_thousands > last_thousand_triggered:
		last_thousand_triggered = current_thousands
		trigger_tap_burst("stars")

	lbl_taps.text = "💖 " + str(total_taps) + "/" + str(current_thousands * 1000 + 1000)

func trigger_tap_burst(type: String):
	effect_running = true
	var burst_time := 3.0
	var timer := 0.0
	while timer < burst_time:
		_spawn_weather_particles(type)
		await get_tree().create_timer(0.5).timeout
		timer += 0.5
	
	# Esperar un poco más para permitir que los taps sigan subiendo sin repetir el efecto inmediatamente
	await get_tree().create_timer(5.0).timeout 
	effect_running = false

func add_taps(cantidad: int):
	total_taps += cantidad
	_actualizar_interfaz()

func update_environment():
	# 1. Actualizar Escenarios en AnimatedSprite2D1
	var anim_fondo = get_tree().current_scene.get_node_or_null("AnimatedSprite2D1")
	if is_instance_valid(anim_fondo):
		var anim_name = "escenario" + str(current_round)
		if anim_fondo.sprite_frames.has_animation(anim_name):
			anim_fondo.play(anim_name)
			print("🖼️ Escenario cambiado a: ", anim_name)
		else:
			# Fallback por si no están todas
			anim_fondo.play("default")
	
	# 2. Efectos de Nivel (Clima base)
	_apply_environment_periodic_effect()

func _apply_environment_periodic_effect():
	match current_round:
		2: spawn_special_weather("snow")
		3: spawn_special_weather("sand")
		4: spawn_special_weather("swamp")
		5: spawn_special_weather("metal")

func spawn_special_weather(type: String):
	var emoji_map = {
		"hearts": "❤️",
		"stars": "⭐",
		"snow": "❄️",
		"sand": "🔸",
		"swamp": "🍃",
		"metal": "◽"
	}
	var emoji = emoji_map.get(type, "✨")
	var count = 15
	var color = Color.WHITE
	
	if type == "sand": color = Color(0.85, 0.65, 0.13) # Dorado/Arena
	if type == "swamp": color = Color(0.5, 1.0, 0.0)    # Verde pantano
	if type == "metal": color = Color(0.44, 0.5, 0.56)  # Gris metálico
	
	for i in range(count):
		var p = Label.new()
		p.text = emoji
		p.modulate = color
		p.add_theme_font_size_override("font_size", randi_range(20, 35))
		hud.add_child(p)
		
		var start_pos = Vector2(randf_range(0, get_viewport().size.x), -50)
		var end_pos = start_pos + Vector2(randf_range(-200, 200), get_viewport().size.y + 100)
		
		if type == "sand": # Viento lateral
			start_pos = Vector2(-50, randf_range(0, get_viewport().size.y))
			end_pos = Vector2(get_viewport().size.x + 100, start_pos.y + randf_range(-100, 100))
			
		p.position = start_pos
		var tween = get_tree().create_tween()
		var duration = randf_range(2.0, 4.0)
		if type == "sand": duration = 1.0
		
		tween.tween_property(p, "position", end_pos, duration)
		tween.finished.connect(p.queue_free)

func _spawn_weather_particles(type: String):
	# Alias para mantener compatibilidad con llamadas de taps
	spawn_special_weather(type)


func announce_kill(type: String, player_name: String, color: Color):
	var text = ""
	var sound = ""
	
	match type:
		"first_blood":
			text = "¡PRIMERA\n SANGRE!\n" + player_name
			sound = "res://sounds/dota/announcer_1stblood_01.mp3"
		"double":
			text = "¡DOUBLE KILL!\n" + player_name
			sound = "res://sounds/dota/announcer_kill_double_01.mp3"
		"triple":
			text = "¡TRIPLE KILL!\n" + player_name
			sound = "res://sounds/dota/announcer_kill_triple_01.mp3"
		"ultra":
			text = "¡ULTRA KILL!\n" + player_name
			sound = "res://sounds/dota/announcer_kill_ultra_01.mp3"
		"rampage":
			text = "¡RAMPAGE!\n" + player_name
			sound = "res://sounds/dota/announcer_kill_rampage_01.mp3"
			
	if text != "":
		print("🎙️ Anunciando: ", type, " por ", player_name)
		_play_sfx(sound)
		lbl_announcement.text = text
		lbl_announcement.modulate = color
		lbl_announcement.visible = true
		
		# Animación de escala para el anuncio
		lbl_announcement.scale = Vector2(0.5, 0.5)
		lbl_announcement.pivot_offset = lbl_announcement.size / 2
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(lbl_announcement, "scale", Vector2(1.2, 1.2), 0.5)
		tween.parallel().tween_property(lbl_announcement, "modulate:a", 1.0, 0.1)
		
		await get_tree().create_timer(2.5).timeout
		
		if is_instance_valid(lbl_announcement):
			var tween_out = get_tree().create_tween()
			tween_out.tween_property(lbl_announcement, "modulate:a", 0.0, 0.5)
			await tween_out.finished
			lbl_announcement.visible = false


func run_game_loop():
	while true:
		# 🟢 FASE 1 (1 min)
		# 🟢 FASE 1 (1 min)
		game_phase = 1
		# time_left = 60 # Original
		time_left = 10 # Para pruebas rápidas (puedes volver a 60)
		emit_signal("update_phase", game_phase)
		emit_signal("toggle_spawn", true)
		lbl_winner.visible = false 
		first_blood_happened = false
		black_slime_spawned = false
		_actualizar_interfaz()
		
		var elapsed := 0
		while true:
			var slimes = get_tree().get_nodes_in_group("slimes")
			if slimes.size() > 1:
				_actualizar_interfaz()
				emit_signal("update_time", time_left)
				await get_tree().create_timer(1).timeout
				time_left -= 1
				elapsed += 1
				if time_left <= 0:
					break
			else:
				# Solo hay 1 jugador o ninguno, esperamos
				lbl_timer.text = "ESPERANDO JUGADORES...\n(" + str(slimes.size()) + "/2)"
				await get_tree().create_timer(1).timeout
			
			if game_phase != 1:
				break

		# 🏁 SECUENCIA DE INICIO DE PELEA (Nivel -> Listos -> Ya)
		lbl_winner.visible = true
		lbl_winner.modulate = Color.WHITE
		
		# 1. Nivel
		var level_sound = "res://sounds/67_Level1Sound.mp3"
		match current_round:
			1: level_sound = "res://sounds/67_Level1Sound.mp3"
			2: level_sound = "res://sounds/56_Level2Sound.mp3"
			3: level_sound = "res://sounds/45_Level3Sound.mp3"
			4: level_sound = "res://sounds/34_Level4Sound.mp3"
			5: level_sound = "res://sounds/32_Level5Sound.mp3"
		
		_play_sfx(level_sound)
		lbl_winner.text = "RONDA " + str(current_round)
		await get_tree().create_timer(1.2).timeout
		
		# 2. Listos
		_play_sfx("res://sounds/71_GetSet.mp3")
		lbl_winner.text = "¡PREPARADOS!"
		await get_tree().create_timer(1.2).timeout
		
		# 3. Ya
		_play_sfx("res://sounds/70_Go.mp3")
		lbl_winner.text = "¡A PELEAR!"
		await get_tree().create_timer(0.8).timeout
		lbl_winner.visible = false

		# 🔴 FASE 2 (2 min)
		game_phase = 2
		time_left = 120
		_actualizar_interfaz()
		emit_signal("update_phase", game_phase)
		emit_signal("toggle_spawn", false)

		# Registrar tiempo inicial para detectar inactividad
		last_hit_msec = Time.get_ticks_msec()
		
		var p2_elapsed := 0
		while time_left > 0:
			_actualizar_interfaz()
			emit_signal("update_time", time_left)
			await get_tree().create_timer(1).timeout
			time_left -= 1
			p2_elapsed += 1
			
			if current_round == 5 and p2_elapsed == 10 and not black_slime_spawned:
				_trigger_black_slime_event()
				
			# Detectar si no ha habido golpes en los últimos 10 segundos
			var time_since_hit = (Time.get_ticks_msec() - last_hit_msec) / 1000.0
			if time_since_hit >= 10.0:
				collapse_platforms()

			var slimes = get_tree().get_nodes_in_group("slimes")
			if slimes.size() <= 1:
				break

		var winners = check_winner()
		if winners.size() > 0:
			last_round_winner = winners[0].nombre

		# 🟡 FASE 3 (resultado)
		game_phase = 3
		time_left = 10
		_actualizar_interfaz()
		emit_signal("update_phase", game_phase)
		emit_signal("toggle_spawn", false)

		show_results(winners)

		while time_left > 0:
			_actualizar_interfaz()
			emit_signal("update_time", time_left)
			await get_tree().create_timer(1).timeout
			time_left -= 1

		# Siguiente ronda o reset
		current_round += 1
		if current_round > 5:
			current_round = 1
			print("🔄 Ciclo de 5 rondas completado. Reiniciando...")

		lbl_timer.text = "REINICIANDO..."
		# Cambio simultáneo e instantáneo de Escenario y Plataformas
		update_environment()
		restore_platforms()
		clear_all()
		await get_tree().create_timer(2).timeout

func collapse_platforms():
	print("🚨 ¡LA PLATAFORMA ", current_round, " COLAPSA!")
	announce_kill("", "¡PLATAFORMA FUERA!", Color.ORANGE)
	
	var target_name = "plataforma" + str(current_round)
	var body = get_tree().current_scene.get_node_or_null(target_name)
	if is_instance_valid(body):
		body.process_mode = PROCESS_MODE_DISABLED
		body.visible = false

func restore_platforms():
	# Ocultar todas y mostrar solo la de la ronda actual
	for i in range(1, 6):
		var target_name = "plataforma" + str(i)
		var body = get_tree().current_scene.get_node_or_null(target_name)
		if is_instance_valid(body):
			if i == current_round:
				body.process_mode = PROCESS_MODE_INHERIT
				body.visible = true
			else:
				body.process_mode = PROCESS_MODE_DISABLED
				body.visible = false


func _trigger_black_slime_event():
	black_slime_spawned = true
	var spawner = get_tree().current_scene.get_node_or_null("Spawner")
	if is_instance_valid(spawner) and spawner.has_method("spawn_black_slime"):
		spawner.spawn_black_slime()
	
	# Sonido de Alerta (Bucle por 10 segundos)
	var alert = AudioStreamPlayer.new()
	alert.stream = preload("res://sounds/105_AlertSound.mp3")
	hud.add_child(alert)
	alert.play()
	
	# Simular bucle por 10 segundos (si el sonido es corto)
	var start_t = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_t < 10000:
		if not alert.playing: alert.play()
		await get_tree().create_timer(0.1).timeout
	
	alert.stop()
	alert.queue_free()

func _play_sfx(path):
	var sfx = AudioStreamPlayer.new()
	sfx.stream = load(path)
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func check_winner():
	var slimes = get_tree().get_nodes_in_group("slimes")

	if slimes.size() <= 1:
		return slimes

	var max_hp = -1
	for s in slimes:
		if s.health > max_hp:
			max_hp = s.health

	var winners = []
	for s in slimes:
		if s.health == max_hp:
			winners.append(s)

	return winners


func show_results(winners):
	var slimes = get_tree().get_nodes_in_group("slimes")

	if winners.size() > 0:
		var w = winners[0]
		lbl_winner.text = "¡GANADOR!\n" + w.nombre
		lbl_winner.modulate = w.modulate # Usar el color del slime
		lbl_winner.visible = true
	else:
		lbl_winner.text = "SIN GANADOR"
		lbl_winner.visible = true

	for s in slimes:
		s.velocity.x = 0
		s.phase3_result = "win" if s in winners else "lose"
		s.fase3_animacion_hecha = false
		
		if s in winners:
			s.is_champion = true
			s.consecutive_victories += 1
			s.total_wins += 1
			s._actualizar_nombre_ui() # Mostrar corona
			print("🏆 ", s.nombre, " gana con ", s.consecutive_victories, " victoria(s) consecutiva(s)")
		else:
			# El usuario dijo: "en caso siga en el live tendra una coronita al lado de su nombre por haver ganado al menor uan vez"
			# Así que no reseteamos el historial visual de victorias si ya ganó alguna vez.
			# Pero consecutive_victories se usa para el tamaño, así que solo actualizamos la UI.
			s.consecutive_victories = 0
			s._actualizar_nombre_ui()


func clear_all():
	var slimes = get_tree().get_nodes_in_group("slimes")

	for s in slimes:
		if is_instance_valid(s):
			# Guardar datos persistentes antes de borrar o mover
			var data = {
				"scale": s.sprite.scale.x,
				"wins": s.consecutive_victories,
				"total_wins": s.total_wins,
				"damage_min": s.attack_damage_min,
				"damage_max": s.attack_damage_max,
				"color": s.sprite.modulate,
				"range": s.attack_range
			}
			player_data[s.nombre] = data
			
			# Borrar a todos para respawnear (excepto si queremos mantenerlos vivos)
			# Para evitar errores de colisión y posiciones, es mejor respawnearlos con los datos guardados
			s.queue_free()

func apply_champion_bonuses(champion):
	print("👑 ", champion.nombre, " regresa como campeón a fase 1")
	
	# Reset de estado pero mantener victorias
	champion.dead = false
	champion.can_attack = true
	champion.can_be_hit = true
	champion.is_attacking = false
	champion.is_hurt = false
	champion.attack_target = null
	champion.health = int(300 * 0.2)  # 20% de vida máxima de un slime inicial
	champion.max_health = int(300 * champion.champion_health_boost)
	champion.health = champion.max_health
	
	# Aplicar bonificaciones de campeón
	champion.sprite.scale *= champion.champion_scale
	champion.attack_damage_min = int(champion.attack_damage_min * champion.champion_damage)
	champion.attack_damage_max = int(champion.attack_damage_max * champion.champion_damage)
	champion.attack_range *= champion.champion_scale
	
	# Duplicar y ajustar colisión
	var collision = champion.get_node("CollisionShape2D")
	if collision and collision.shape is RectangleShape2D:
		collision.shape = collision.shape.duplicate(true)
		collision.shape.extents *= champion.champion_scale
	
	print("👑 ", champion.nombre, " bonificaciones aplicadas: +50% tamaño, +15% daño, vida recuperada al 100%")
