extends Node

var game_phase := 1
var time_left := 0

signal update_time(tiempo)
signal update_phase(fase)
signal toggle_spawn(enabled)

func _ready():
	run_game_loop()


func run_game_loop():
	while true:
		# 🟢 FASE 1 (1 min)
		game_phase = 1
		time_left = 60
		emit_signal("update_phase", game_phase)
		emit_signal("toggle_spawn", true)
		
		# Resetear contador de victorias si pierden en la siguiente ronda
		var all_slimes = get_tree().get_nodes_in_group("slimes")
		for s in all_slimes:
			if s.is_champion:
				s.consecutive_victories = 0
				s.is_champion = false

		var elapsed := 0
		while time_left > 0:
			emit_signal("update_time", time_left)
			await get_tree().create_timer(1).timeout
			time_left -= 1
			elapsed += 1
			var slimes = get_tree().get_nodes_in_group("slimes")
			if slimes.size() >= 50 and elapsed >= 10:
				print("⚠️ Máximo de 50 slimes alcanzado y 10s cumplidos en fase 1")
				break
			if game_phase != 1:
				print("⚠️ Fase 1 interrumpida prematuramente por cambio de fase")
				break

		# 🔴 FASE 2 (2 min)
		game_phase = 2
		time_left = 120
		emit_signal("update_phase", game_phase)
		emit_signal("toggle_spawn", false)

		while time_left > 0:
			emit_signal("update_time", time_left)
			await get_tree().create_timer(1).timeout
			time_left -= 1

			var slimes = get_tree().get_nodes_in_group("slimes")
			if slimes.size() <= 1:
				break

		var winners = check_winner()

		# 🟡 FASE 3 (resultado)
		game_phase = 3
		time_left = 10
		emit_signal("update_phase", game_phase)
		emit_signal("toggle_spawn", false)

		show_results(winners)

		while time_left > 0:
			emit_signal("update_time", time_left)
			await get_tree().create_timer(1).timeout
			time_left -= 1

		clear_all()
		await get_tree().create_timer(2).timeout


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

	for s in slimes:
		s.velocity.x = 0
		s.phase3_result = "win" if s in winners else "lose"
		s.fase3_animacion_hecha = false
		
		if s in winners:
			s.is_champion = true
			s.consecutive_victories += 1
			print("🏆 ", s.nombre, " gana con ", s.consecutive_victories, " victoria(s) consecutiva(s)")
		else:
			s.consecutive_victories = 0


func clear_all():
	var slimes = get_tree().get_nodes_in_group("slimes")

	for s in slimes:
		if is_instance_valid(s):
			if s.is_champion and s.consecutive_victories > 0:
				apply_champion_bonuses(s)
			else:
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
