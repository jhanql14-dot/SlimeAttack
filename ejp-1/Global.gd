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

		while time_left > 0:
			emit_signal("update_time", time_left)
			await get_tree().create_timer(1).timeout
			time_left -= 1

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
		s.velocity = Vector2.ZERO
		s.set_physics_process(false)

		if s in winners:
			s.anim.play("Slime_Wiggle")
		else:
			s.anim.play("Slime_Die")


func clear_all():
	var slimes = get_tree().get_nodes_in_group("slimes")

	for s in slimes:
		if is_instance_valid(s):
			s.queue_free()
