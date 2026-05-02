extends CharacterBody2D

@export var speed := 120
var gravedad := 1600.0
@export var fuerza_salto := -480
@export var tiempo_espera := 1.0

@export var attack_range := 60
@export var attack_damage_min := 20
@export var attack_damage_max := 30
@export var max_health := 300

@export var victory_boost_scale := 1.3
@export var victory_boost_damage := 1.1
@export var victory_boost_collision := 1.3
@export var victory_boost_heal := 0.15
@export var victory_boost_max_health := 1.1

@export var champion_scale := 1.5
@export var champion_damage := 1.15
@export var champion_health_boost := 1.2
@export var champion_focus_base_probability := 0.25
@export var champion_focus_multi_win_probability := 0.4

# 🔊 Ajustes de sonido
@export var jump_sound_volume := -12.0 # Volumen del salto (-70% aprox)
@export var jump_sound_delay := 0.0   # Retraso del sonido tras el salto
@export var attack_sound_volume := -6.0 # Volumen del ataque
@export var attack_sound_delay := 0.0   # Retraso del sonido del ataque
@export_group("Configuración de Aura (Rachas)")
@export var glow_color := Color(1, 0.9, 0.2) # Color base del aura
@export var aura_energy_double := 0.8
@export var aura_scale_double := 0.5
@export var aura_energy_triple := 1.2
@export var aura_scale_triple := 0.7
@export var aura_energy_ultra := 1.6
@export var aura_scale_ultra := 0.9
@export var aura_energy_rampage := 2.0
@export var aura_scale_rampage := 1.1

var direccion := 1
var target = null
var dead := false

var can_attack := true
var can_be_hit := true
var is_attacking := false
var is_hurt := false

var attack_target = null

# 🔥 sistema de vida por fases
var health := max_health
var phase_damage := 0
var phase_threshold := 100
var phase_count := 0

# ☠️ control de aire
var tiempo_en_aire := 0.0

# 🟡 fase 3 control
var fase3_animacion_hecha := false
var phase3_result := ""

var nombre = ""
var historial_saltos = []  # Rastrear corto(0) o largo(1)
var consecutive_victories := 0
var total_wins := 0
var is_champion := false
var is_black_slime := false
var current_round_kills := 0
var last_kill_msec = 0
var glow_node : PointLight2D
var name_v_offset := 0.0
var has_black_aura := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
var lbl_nombre : Label


func _ready():
	add_to_group("slimes")
	# Randomizar estadísticas base (más moderado)
	speed = int(speed * randf_range(0.9, 1.2))
	fuerza_salto = int(fuerza_salto * randf_range(0.95, 1.05))
	tiempo_espera = tiempo_espera * randf_range(0.8, 1.2)
	health = max_health
	current_round_kills = 0
	last_kill_msec = 0
	set_meta("temporal_kills", 0)

	# Crear label con nombre si existe
	if nombre != "":
		var label = Label.new()
		label.text = nombre
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.self_modulate = Color(1, 1, 1, 1)
		
		# Posicionar relativo a la colisión
		var collision = get_node("CollisionShape2D")
		if collision and collision.shape is RectangleShape2D:
			var extents = collision.shape.extents
			label.position = collision.position + Vector2(-25, -extents.y - 25)  # Más a la izquierda y más arriba
		else:
			label.position = Vector2(-25, -60)  # Fallback
		
		add_child(label)
		lbl_nombre = label
		_actualizar_nombre_ui()
	
	_preparar_glow()
	loop_saltos()

func _actualizar_nombre_ui():
	if is_instance_valid(lbl_nombre):
		var prefix = "👑 " if total_wins > 0 else ""
		lbl_nombre.text = prefix + nombre
		
		# Reposicionar para que siempre esté arriba aunque el slime crezca
		var collision = get_node_or_null("CollisionShape2D")
		if collision and collision.shape is RectangleShape2D:
			var extents = collision.shape.extents
			lbl_nombre.position = collision.position + Vector2(-50, -extents.y - 30 - name_v_offset)
			lbl_nombre.size = Vector2(100, 30)


func _physics_process(delta):
	if dead:
		return

	# gravedad siempre activa
	if not is_on_floor():
		velocity.y += gravedad * delta

	# ☠️ regla GLOBAL de 2 segundos en aire
	if not is_on_floor():
		tiempo_en_aire += delta
	else:
		tiempo_en_aire = 0

	if tiempo_en_aire >= 2.0:
		die()
		return

	# 🟡 FASE 3 (sin control manual, salvo ganador)
	if Global.game_phase == 3:
		if phase3_result == "win":
			# El ganador se mueve al centro
			var center_x = 0 # En Main.tscn la cámara suele estar en 0 o centrada
			var dx = center_x - global_position.x
			if abs(dx) > 30:
				velocity.x = sign(dx) * speed
			else:
				velocity.x = 0
		else:
			velocity.x = 0

		if is_on_floor() and not fase3_animacion_hecha:
			fase3_animacion_hecha = true
			if phase3_result == "win":
				anim.play("Slime_Wiggle")
				lanzar_confeti()
			else:
				anim.play("Slime_Die")

		_handle_wall_bounce()
		move_and_slide()
		return

	# 👀 detectar enemigos solo fase 2
	if Global.game_phase == 2:
		target = get_target()
	else:
		target = null

	# evitar deslizamiento
	if is_on_floor() and velocity.y == 0:
		velocity.x = 0

	# mirar enemigo
	if target:
		var dx = target.global_position.x - global_position.x
		var dir = sign(dx)

		# Si el objetivo está por debajo y la caída es de tiempo típico, moverse solo horizontalmente
		if target.global_position.y > global_position.y and _target_has_common_fall_time(target) and is_on_floor():
			if dir == 0:
				dir = [-1, 1].pick_random()
			velocity.x = dir * speed
			sprite.flip_h = dir > 0
			move_and_slide()
			actualizar_animacion()
			return

		sprite.flip_h = dir > 0

		if can_attack and not is_attacking and not is_hurt:
			try_attack(target)

	_prevent_name_overlap()
	_handle_wall_bounce()
	move_and_slide()
	actualizar_animacion()

func _handle_wall_bounce():
	if is_on_wall():
		var collision = get_last_slide_collision()
		if collision:
			var collider = collision.get_collider()
			if collider and (collider.name == "pared1" or collider.name == "pared2"):
				# Rebotar hacia el centro (x=0)
				direccion = 1 if global_position.x < 0 else -1
				velocity.x = direccion * speed * 1.5
				if is_instance_valid(sprite):
					sprite.flip_h = direccion > 0


# 👀 detectar enemigo
func get_target():
	var slimes = get_tree().get_nodes_in_group("slimes")

	var closest = null
	var min_dist = INF

	for s in slimes:
		if s == self:
			continue

		if not s.can_be_hit or s.dead:
			continue

		# Probabilidad de enfocarse en campeones
		var target_champion = false
		if s.is_champion:
			var focus_prob = champion_focus_base_probability
			if s.consecutive_victories >= 2:
				focus_prob = champion_focus_multi_win_probability
			if randf() < focus_prob:
				target_champion = true

		if target_champion:
			return s

		var d = global_position.distance_to(s.global_position)
		if d < min_dist:
			min_dist = d
			closest = s

	return closest

func _target_has_common_fall_time(target):
	var dy = target.global_position.y - global_position.y
	if dy <= 0:
		return false

	var fall_time = sqrt(2.0 * dy / gravedad)
	return abs(fall_time - 0.6) <= 0.1


# ⚔️ ataque
func try_attack(enemy):
	if not is_on_floor():
		return

	if not enemy.is_on_floor():
		return

	if enemy.attack_target != null and enemy.attack_target != self:
		return

	if global_position.distance_to(enemy.global_position) <= attack_range:
		attack(enemy)


func attack(enemy):
	can_attack = false
	is_attacking = true
	attack_target = enemy

	enemy.attack_target = self

	# 🔊 Sonido de ataque
	_reproducir_sonido_ataque_con_retraso()

	anim.play("Slime_Slash")

	await get_tree().create_timer(0.4).timeout

	if not is_attacking or dead or not enemy.can_be_hit:
		reset_attack()
		return

	if enemy and enemy.attack_target == self:
		var damage = randi_range(attack_damage_min, attack_damage_max)
		enemy.take_damage(damage)
		if enemy.dead:
			_on_enemy_killed(enemy)
			apply_victory_boost()
			_actualizar_glow()

	await get_tree().create_timer(1.0).timeout

	reset_attack()


func reset_attack():
	if attack_target:
		attack_target.attack_target = null

	attack_target = null
	is_attacking = false
	can_attack = true


# 🩸 daño
func take_damage(amount):
	if dead or not can_be_hit:
		return

	health -= amount
	phase_damage += amount
	Global.last_hit_msec = Time.get_ticks_msec()

	if phase_damage >= phase_threshold:
		phase_damage -= phase_threshold
		phase_count += 1

		if is_attacking:
			reset_attack()

		if phase_count >= 3:
			die()
			return

		hit_reaction()


func hit_reaction():
	can_be_hit = false
	is_hurt = true

	anim.play("Slime_Hit")

	await get_tree().create_timer(0.45).timeout

	is_hurt = false
	can_be_hit = true


func die():
	if dead:
		return

	dead = true
	can_attack = false
	can_be_hit = false

	anim.play("Slime_Die")

	# 🔊 Sonido de muerte
	var death_sound = AudioStreamPlayer.new()
	if is_black_slime:
		death_sound.stream = preload("res://sounds/82_EnemyDie.mp3")
	else:
		death_sound.stream = preload("res://sounds/14_PlayerHitAndLosePowerUp.mp3")
	get_parent().add_child(death_sound)
	death_sound.play()
	death_sound.finished.connect(death_sound.queue_free)

	await get_tree().create_timer(1.0).timeout
	queue_free()

func apply_victory_boost():
	# Si ya creció mucho, no lo hacemos crecer más (evita acumulación infinita)
	if sprite.scale.x > 2.5: 
		return

	# Ajustes fáciles de configurar mediante variables exportadas
	sprite.scale *= victory_boost_scale
	attack_range *= victory_boost_collision
	attack_damage_min = int(ceil(attack_damage_min * victory_boost_damage))
	attack_damage_max = int(ceil(attack_damage_max * victory_boost_damage))

	var collision = get_node_or_null("CollisionShape2D")
	if collision and collision.shape is RectangleShape2D:
		# Asegurar que cada instancia tenga su propio recurso de forma
		collision.shape = collision.shape.duplicate(true)
		collision.shape.extents *= victory_boost_collision
	
	_actualizar_nombre_ui() # Actualizar posición del nombre tras crecer
	print("🏆 ", nombre, " ha derrotado a un enemigo y su sprite crece ", int((victory_boost_scale - 1.0) * 100), "%")


# 🔁 saltos
func loop_saltos():
	while not dead:
		await get_tree().create_timer(tiempo_espera).timeout

		if is_on_floor() and not is_attacking and not is_hurt:
			# Permitir saltar en fase 3 solo si es ganador
			if Global.game_phase == 3:
				if phase3_result == "win":
					saltar()
			else:
				saltar()


func saltar():
	# 🔊 Reproducir sonido con el retraso configurado
	_reproducir_sonido_salto_con_retraso()

	if Global.game_phase == 2 and target:
		var dx = target.global_position.x - global_position.x
		direccion = sign(dx)
		
		# Si el objetivo está muy lejos horizontalmente, aumentar probabilidad de salto largo
		if abs(dx) > 200:
			historial_saltos.append(1) # Forzar o sugerir largo
		
		# Si estamos muy cerca horizontalmente pero en diferente altura, intentar saltar al azar
		if abs(dx) < 30 and abs(target.global_position.y - global_position.y) > 50:
			direccion = [-1, 1].pick_random()
	else:
		direccion = [-1, 1].pick_random()

	# Variar la altura del salto (k entre 1.0 y 1.4 para que no sea tan alto)
	var k = randf_range(1.0, 1.4)
	var fuerza_salto_actual = fuerza_salto * k
	velocity.y = fuerza_salto_actual
	
	# Velocidad horizontal aleatoria basada en la base
	var random_speed_mult = randf_range(0.7, 1.8)
	
	# AGRESIVIDAD: Si el objetivo está abajo, saltar más fuerte horizontalmente para caer de la plataforma
	if target and target.global_position.y > global_position.y + 100:
		random_speed_mult *= 2.0
		
	var jump_speed = speed * random_speed_mult
	
	velocity.x = direccion * jump_speed
	sprite.flip_h = direccion > 0


func _reproducir_sonido_salto_con_retraso():
	if jump_sound_delay > 0:
		await get_tree().create_timer(jump_sound_delay).timeout
	
	var jump_sound = AudioStreamPlayer.new()
	jump_sound.stream = preload("res://sounds/5_TakePill.mp3")
	jump_sound.volume_db = jump_sound_volume
	add_child(jump_sound)
	jump_sound.play()
	jump_sound.finished.connect(jump_sound.queue_free)


func _reproducir_sonido_ataque_con_retraso():
	if attack_sound_delay > 0:
		await get_tree().create_timer(attack_sound_delay).timeout
	
	var atk_sound = AudioStreamPlayer.new()
	atk_sound.stream = preload("res://sounds/89_DropTail.mp3")
	atk_sound.volume_db = attack_sound_volume
	add_child(atk_sound)
	atk_sound.play()
	atk_sound.finished.connect(atk_sound.queue_free)


# 🎞 animaciones
func actualizar_animacion():
	if dead:
		return

	if Global.game_phase == 3:
		return

	if is_hurt or is_attacking:
		return

	if not is_on_floor():
		anim.play("Slime_Jump")
	elif target:
		if anim.has_animation("Slime_Run"):
			anim.play("Slime_Run")
		elif anim.has_animation("Slime_Wiggle"):
			anim.play("Slime_Wiggle")
		else:
			anim.play("Slime_Idle")

func lanzar_confeti():
	var particles = CPUParticles2D.new()
	particles.amount = 50
	particles.explosiveness = 0.8
	particles.spread = 180.0
	particles.gravity = Vector2(0, 500)
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 400.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	particles.color_ramp = Gradient.new()
	particles.color_ramp.add_point(0.0, Color(1, 0, 0))
	particles.color_ramp.add_point(0.2, Color(0, 1, 0))
	particles.color_ramp.add_point(0.4, Color(0, 0, 1))
	particles.color_ramp.add_point(0.6, Color(1, 1, 0))
	particles.color_ramp.add_point(0.8, Color(1, 0, 1))
	particles.color_ramp.add_point(1.0, Color(0, 1, 1))
	
	# Hacer que los colores sean variados desde el inicio
	particles.hue_variation_min = -1.0
	particles.hue_variation_max = 1.0
	
	add_child(particles)
	particles.emitting = true
	particles.one_shot = true
	
	# 🔊 Sonido de victoria (opcional si ya existe uno, pero el usuario pidió mejor animación)
	var win_sound = AudioStreamPlayer.new()
	win_sound.stream = preload("res://sounds/72_Finish.mp3") # Sonido de éxito
	add_child(win_sound)
	win_sound.play()
	
	await get_tree().create_timer(3.0).timeout
	particles.queue_free()
	win_sound.queue_free()

func _on_enemy_killed(killed_enemy):
	var now = Time.get_ticks_msec()
	var time_since_last = (now - last_kill_msec) / 1000.0
	
	current_round_kills += 1
	
	# RECOMPENSA DARK: Si mató al Slime Negro, obtiene Aura Negra
	if killed_enemy and killed_enemy.is_black_slime:
		has_black_aura = true
		print("🌑 ¡", nombre, " HA OBTENIDO EL AURA NEGRA!")
	
	# FIRST BLOOD
	if not Global.first_blood_happened:
		Global.first_blood_happened = true
		Global.announce_kill("first_blood", nombre, sprite.modulate)
	
	# MULTI-KILLS (Tolerancia 10s)
	if last_kill_msec > 0 and time_since_last <= 10.0:
		# Continuar racha
		pass
	else:
		# Reset racha de tiempo pero no de muertes si es muy lento?
		# Usualmente multi-kill es X muertes seguidas con poco tiempo entre ellas.
		# Si pasa más de 10s, la racha de "Double/Triple" se resetea.
		# Pero el usuario pidió "Double kill" si mata a dos en menos de 10s.
		# Así que usaremos un contador de racha temporal.
		# Re-usaremos current_round_kills para simplificar o uno específico.
		pass
	
	# Lógica de racha temporal
	if last_kill_msec == 0 or time_since_last > 10.0:
		# Reiniciar racha temporal a 1 (esta muerte)
		# Pero no queremos perder First Blood
		# Vamos a usar una variable local para la racha de tiempo
		set_meta("temporal_kills", 1)
	else:
		var tk = get_meta("temporal_kills", 1) + 1
		set_meta("temporal_kills", tk)
		
		match tk:
			2: Global.announce_kill("double", nombre, sprite.modulate)
			3: Global.announce_kill("triple", nombre, sprite.modulate)
			4: Global.announce_kill("ultra", nombre, sprite.modulate)
			5, _: Global.announce_kill("rampage", nombre, sprite.modulate)

	last_kill_msec = now

func _on_round_start():
	current_round_kills = 0
	has_black_aura = false # Perder aura negra al terminar ronda
	_actualizar_glow()

func _preparar_glow():
	glow_node = PointLight2D.new()
	glow_node.enabled = false
	glow_node.color = Color(1, 0.9, 0.2) # Amarillo brillante
	glow_node.energy = 0.0
	glow_node.blend_mode = PointLight2D.BLEND_MODE_ADD
	
	# Crear textura radial circular suave por código
	var gradient = Gradient.new()
	gradient.offsets = [0.0, 0.7, 1.0]
	gradient.colors = [Color.WHITE, Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)]
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.8, 0.5) # Asegura que se desvanezca antes del borde
	tex.width = 256 # Más resolución para suavidad
	tex.height = 256
	glow_node.texture = tex
	
	add_child(glow_node)

func _actualizar_glow():
	if not is_instance_valid(glow_node): return
	
	# El Aura Negra es permanente durante la ronda si se obtiene
	if current_round_kills < 2 and not has_black_aura:
		glow_node.enabled = false
		return
	
	glow_node.enabled = true
	glow_node.color = Color.BLACK if has_black_aura else glow_color
	var intensity = 0.0
	var g_scale = 1.0
	
	# Si tiene aura negra, forzar valores mínimos llamativos
	if has_black_aura:
		intensity = 3.0
		g_scale = 2.0

	# Pero si además tiene racha, usar el mayor de los dos
	match current_round_kills:
		2: # Double
			intensity = aura_energy_double
			g_scale = aura_scale_double
		3: # Triple
			intensity = aura_energy_triple
			g_scale = aura_scale_triple
		4: # Ultra
			intensity = aura_energy_ultra
			g_scale = aura_scale_ultra
		_: # Rampage o más
			intensity = aura_energy_rampage
			g_scale = aura_scale_rampage
			
	var tween = get_tree().create_tween()
	tween.tween_property(glow_node, "energy", intensity, 0.5)
	tween.parallel().tween_property(glow_node, "texture_scale", g_scale, 0.5)

func _prevent_name_overlap():
	var slimes = get_tree().get_nodes_in_group("slimes")
	var new_offset = 0.0
	for s in slimes:
		if s == self or s.dead: continue
		var dist_x = abs(global_position.x - s.global_position.x)
		var dist_y = abs(global_position.y - s.global_position.y)
		
		if dist_x < 80 and dist_y < 40:
			# Si estamos muy cerca, uno de los dos sube su nombre
			if global_position.x > s.global_position.x:
				new_offset = 40.0 # Subir el nombre 40px
				break
	
	if new_offset != name_v_offset:
		name_v_offset = new_offset
		_actualizar_nombre_ui()
