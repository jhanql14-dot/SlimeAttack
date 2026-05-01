extends CharacterBody2D

@export var speed := 120
@export var gravedad := 1600
@export var fuerza_salto := -350
@export var tiempo_espera := 1.0

@export var attack_range := 60
@export var attack_damage_min := 20
@export var attack_damage_max := 30

var direccion := 1
var target = null
var dead := false

var can_attack := true
var can_be_hit := true
var is_attacking := false
var is_hurt := false

var attack_target = null

# 🔥 sistema de vida por fases
var health := 300
var phase_damage := 0
var phase_threshold := 100
var phase_count := 0

# ☠️ control de aire
var tiempo_en_aire := 0.0

# 🟡 fase 3 control
var fase3_animacion_hecha := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready():
	add_to_group("slimes")
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
		move_and_slide()

		# 🎭 solo al tocar suelo hace animación (una vez)
		if is_on_floor() and not fase3_animacion_hecha:
			fase3_animacion_hecha = true

			if Global.is_winner(self):
				anim.play("Slime_Wiggle")
			else:
				anim.play("Slime_Die")

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
		var dir = sign(target.global_position.x - global_position.x)
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

		var d = global_position.distance_to(s.global_position)
		if d < min_dist:
			min_dist = d
			closest = s

	return closest


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

	velocity.y = fuerza_salto
	velocity.x = direccion * speed

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
