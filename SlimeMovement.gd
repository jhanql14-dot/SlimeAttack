extends CharacterBody2D

@export var speed := 120
@export var gravedad := 1600   # antes 800 → ahora el doble
@export var fuerza_salto := -350  # antes -350 → ahora el doble
@export var tiempo_espera := 1.0

@export var color_personaje: Color = Color(1,1,1)



	
var direccion := 1

func _ready():
	
	randomize()
	loop_saltos()
	$Sprite2D.modulate = color_personaje

func _physics_process(delta):
	# 🔹 Aplicar gravedad SIEMPRE
	velocity.y += gravedad * delta

	# 🔹 Movimiento horizontal solo en el aire
	if not is_on_floor():
		velocity.x = direccion * speed
	else:
		velocity.x = 0

	move_and_slide()

	actualizar_animacion()

# 🔹 Loop de saltos
func loop_saltos():
	while true:
		await get_tree().create_timer(tiempo_espera).timeout

		if is_on_floor():
			saltar()

# 🔹 Salto real
func saltar():
	direccion = [-1, 1].pick_random()

	velocity.y = fuerza_salto

	# girar sprite
	$Sprite2D.flip_h = direccion > 0

# 🔹 Animaciones
func actualizar_animacion():
	if not is_on_floor():
		$AnimationPlayer.play("Slime_Jump")
	else:
		$AnimationPlayer.play("Slime_Idle")
