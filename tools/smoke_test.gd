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
	gs.call("request_match", false)
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
	var near_raw: Variant = as_node.call("units_near", as_node.champion.global_position, 0.25)
	if not (near_raw is Array):
		push_error("ArenaState.units_near did not return an Array")
		quit(7)
		return
	var nearby: Array = []
	for raw in near_raw:
		if raw == null or not is_instance_valid(raw):
			push_error("ArenaState.units_near returned an invalid value")
			quit(8)
			return
		nearby.append(raw)
	if not nearby.has(as_node.champion):
		push_error("ArenaState.units_near omitted the champion at its own position")
		quit(9)
		return
	for unit in nearby:
		if unit.is_dead or unit.is_structure:
			push_error("ArenaState.units_near returned an ineligible unit")
			quit(10)
			return
		if unit.global_position.distance_squared_to(as_node.champion.global_position) > 0.25 * 0.25:
			push_error("ArenaState.units_near returned a unit outside the query radius")
			quit(11)
			return
	print("ArenaState.units_near OK: %d result(s)" % nearby.size())
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
	var fire := load("res://assets/vfx/elemental/effects/projectile/vfx_fire_projectile_01.tscn")
	var boom := load("res://assets/vfx/explosion/effects/ground/vfx_ground_explosion_01.tscn")
	print("VFX firebolt=%s meteor=%s" % [fire != null, boom != null])
	quit(0)
