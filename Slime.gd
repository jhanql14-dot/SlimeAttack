extends CharacterBody2D

@export var speed := 120
@export var attack_range := 60
@export var attack_damage := 10
@export var max_health := 100

var health := 100
var can_attack := true
var target = null
func _ready():
	add_to_group("slimes")
func get_target():
	var slimes = get_tree().genuevarama
	t_nodes_in_group("slimes")

	var closest = null
	var min_dist = INF

	for s in slimes:
		if s == self:
			continue

		var d = global_position.distance_to(s.global_position)

		if d < min_dist:
			min_dist = d
			closest = s

	return closest
	
func is_on_ground():
	return is_on_floor()

func _physics_process(delta):
	target = get_target()

	if target:
		var dir = (target.global_position - global_position).normalized()
		velocity.x = dir.x * speed

		# atacar si cumple condiciones
		if can_attack:
			try_attack(target)
	else:
		velocity.x = 0

	move_and_slide()
func try_attack(enemy):
	if not is_on_floor():
		return

	if not enemy.is_on_floor():
		return

	if global_position.distance_to(enemy.global_position) <= attack_range:
		attack(enemy)
func attack(enemy):
	can_attack = false

	$AnimatedSprite2D.play("Slime_Slash")

	await get_tree().create_timer(0.3).timeout  # tiempo del golpe

	if enemy:
		enemy.take_damage(attack_damage)

	await get_tree().create_timer(1.0).timeout  # cooldown
	can_attack = true
func take_damage(amount):

	# ❌ inmune si está en el aire
	if not is_on_floor():
		return

	health -= amount

	$AnimatedSprite2D.play("hit")

	if health <= 0:
		die()
func die():
	$AnimatedSprite2D.play("Slime_Die")

	await get_tree().create_timer(0.6).timeout
	queue_free()
	
