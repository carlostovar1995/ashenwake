extends SceneTree

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn")
	if packed == null:
		push_error("Failed to load main.tscn")
		quit(1)
		return
	print("Loaded main.tscn OK")
	var main := (packed as PackedScene).instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var gs := root.get_node_or_null("GameSession")
	var as_node := root.get_node_or_null("ArenaState")
	if gs == null or as_node == null:
		push_error("Autoloads missing")
		quit(6)
		return
	gs.call("request_match")
	for i in 60:
		await process_frame
		if as_node.champion and as_node.boss and as_node.allies.size() == 4:
			break
	if as_node.champion == null:
		push_error("Champion was not spawned")
		quit(2)
		return
	if as_node.boss == null:
		push_error("Boss was not spawned")
		quit(3)
		return
	if as_node.allies.size() != 4:
		push_error("Expected 4 allies, got %s" % as_node.allies.size())
		quit(4)
		return
	print("Spawn OK: champion=%s boss=%s allies=%s" % [as_node.champion.unit_name, as_node.boss.unit_name, as_node.allies.size()])
	await process_frame
	await process_frame
	if gs.active_unit == null:
		push_error("No active unit after match start")
		quit(5)
		return
	var abs: Array = gs.active_unit.abilities
	print("Session OK, active=%s abilities=%s" % [gs.active_unit.unit_name, abs.size()])
	if abs.size() >= 4:
		print("QWER: %s, %s, %s, %s" % [abs[0].display_name, abs[1].display_name, abs[2].display_name, abs[3].display_name])
	var fire := load("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/projectile/vfx_fire_projectile_01.tscn")
	var boom := load("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn")
	print("VFX firebolt=%s meteor=%s" % [fire != null, boom != null])
	quit(0)
