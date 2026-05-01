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
var is_champion := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready():
	add_to_group("slimes")
	health = max_health

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
	
	loop_saltos()


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

	# 🟡 FASE 3 (sin control manual)
	if Global.game_phase == 3:
		velocity.x = 0

		if is_on_floor() and not fase3_animacion_hecha:
			fase3_animacion_hecha = true
			if phase3_result == "win":
				anim.play("Slime_Wiggle")
			else:
				anim.play("Slime_Die")

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

	move_and_slide()
	actualizar_animacion()


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

	anim.play("Slime_Slash")

	await get_tree().create_timer(0.4).timeout

	if not is_attacking or dead or not enemy.can_be_hit:
		reset_attack()
		return

	if enemy and enemy.attack_target == self:
		var damage = randi_range(attack_damage_min, attack_damage_max)
		enemy.take_damage(damage)
		if enemy.dead:
			apply_victory_boost()

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

	await get_tree().create_timer(1.0).timeout
	queue_free()

func apply_victory_boost():
	# Ajustes fáciles de configurar mediante variables exportadas
	sprite.scale *= victory_boost_scale
	attack_range *= victory_boost_collision
	attack_damage_min = int(ceil(attack_damage_min * victory_boost_damage))
	attack_damage_max = int(ceil(attack_damage_max * victory_boost_damage))

	var collision = get_node("CollisionShape2D")
	if collision and collision.shape is RectangleShape2D:
		# Asegurar que cada instancia tenga su propio recurso de forma
		collision.shape = collision.shape.duplicate(true)
		collision.shape.extents *= victory_boost_collision

	print("🏆 ", nombre, " ha derrotado a un enemigo y su sprite crece ", int((victory_boost_scale - 1.0) * 100), "%")


# 🔁 saltos
func loop_saltos():
	while not dead:
		await get_tree().create_timer(tiempo_espera).timeout

		if is_on_floor() and not is_attacking and not is_hurt:
			saltar()


func saltar():
	if Global.game_phase == 2 and target:
		direccion = sign(target.global_position.x - global_position.x)
	else:
		direccion = [-1, 1].pick_random()

	# Variar la altura del salto (k entre 1 y 2)
	var k = randf_range(1.0, 2.0)
	gravedad = 1600.0 * k
	var fuerza_salto_actual = -480.0 * k
	velocity.y = fuerza_salto_actual
	
	# Determinar si es salto corto o largo con alternancia
	var jump_speed
	if historial_saltos.size() >= 3:
		var ultimos_tres = historial_saltos.slice(-3)
		if ultimos_tres[0] == ultimos_tres[1] and ultimos_tres[1] == ultimos_tres[2]:
			# Si los últimos 3 son iguales, forzar lo contrario
			var tipo_forzado = 1 - ultimos_tres[0]
			jump_speed = speed * (2.0 if tipo_forzado == 1 else 1.0)
			historial_saltos.append(tipo_forzado)
		else:
			# Aleatorio normal
			var tipo_aleatorio = randi() % 2
			jump_speed = speed * (2.0 if tipo_aleatorio == 1 else 1.0)
			historial_saltos.append(tipo_aleatorio)
	else:
		# Comenzar con aleatorio
		var tipo_aleatorio = randi() % 2
		jump_speed = speed * (2.0 if tipo_aleatorio == 1 else 1.0)
		historial_saltos.append(tipo_aleatorio)
	
	velocity.x = direccion * jump_speed

	sprite.flip_h = direccion > 0


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
		anim.play("Slime_Run")
	else:
		anim.play("Slime_Idle")
