class_name TalentHooks
extends RefCounted

var burn_store_bonus: float = 0.0
var live_coals_ratio: float = 0.0
var searing_refresh: float = 0.0
var cinder_spark_ratio: float = 0.0
var hotter_coals: float = 0.0
var emberheart: float = 0.0
var fire_crit_bonus: float = 0.0
var fire_damage_pct: float = 0.0
var ice_damage_pct: float = 0.0
var shadow_damage_pct: float = 0.0
var burned_damage_pct: float = 0.0
var chilled_damage_pct: float = 0.0
var afflicted_damage_pct: float = 0.0
var passive_dr: float = 0.0
var shielded_dr: float = 0.0
var auto_damage_bonus: float = 0.0
var auto_threat_bonus: float = 0.0
var auto_self_shield_bonus: float = 0.0
var ally_heal_bonus: float = 0.0
var heal_dealt_pct: float = 0.0
var critical_mass: float = 0.0
var flashover_burn: float = 0.0
var fire_crit_damage_bonus: float = 0.0
var impact_heat: float = 0.0
var afterburn: float = 0.0
var afterburn_left: float = 0.0
var singe_rank: int = 0
var scorch_snare: float = 0.0
var scorch_store: float = 0.0
var scorch_pyre_splash: float = 0.0
var sootbrand_stacks: int = 0
var wick: float = 0.0
var smother: float = 0.0
var pitch_skin: float = 0.0
var cinderfeed: float = 0.0
var wraithfire_rank: int = 0
var kiln_rank: int = 0
var quench: bool = false
var glaze: bool = false
var fumarole_amp: float = 0.0
var fumarole_time: float = 0.0
var alloy: float = 0.0
var obsidian_shell: float = 0.0
var pyroblast_slot: int = -1
var max_health_pct: float = 0.0
var shared_plate: bool = false
var shared_plate_cast_id: int = -1
var shared_plate_msec: int = 0
var shared_plate_shield: float = 0.0
var shield_pct: float = 0.0
var anointed: bool = false
var anointed_heal: float = 0.0
var anointed_threat: float = 0.0
var anointed_icd: float = 0.0
var second_skin_heal: float = 0.0
var second_skin_icd: float = 0.0
var brace_dr: float = 0.0
var brace_heal: float = 0.0
var brace_heal_acc: float = 0.0
var spite_damage: float = 0.0
var spite_dr: float = 0.0
var peal: bool = false
var live_wire: bool = false
var goad: bool = false
var marked_prey: float = 0.0
var claim_threat: float = 0.0
var ire: bool = false
var ire_ratio: float = 0.0
var ire_cap: float = 0.0
var lunge: bool = false
var rampage_left: float = 0.0
var ironhide_left: float = 0.0
var footing: float = 0.0
var undertow: bool = false
var undertow_charges: int = 0
var undertow_charge_max: int = 2
var undertow_recharge: float = 14.4
var undertow_recharge_left: float = 0.0
var wall_hp_pct: float = 0.0
var wall_cdr: float = 0.0
var palisade_length: float = 0.0
var palisade_duration: float = 0.0
var pavise: bool = false
var battlement_rank: int = 0
var mortar: float = 0.0
var vow_ally_shield: float = 0.0
var halo: bool = false
var halo_cap: float = 0.0
var cover: bool = false
var cover_extra: float = 0.0
var redirect: float = 0.0
var mercy_dealt: float = 0.0
var mercy_taken: float = 0.0
var bodyguard_dr: float = 0.0
var bodyguard_convert: float = 0.0
var intercede_left: float = 0.0
var intercede_target_id: int = 0
var intercede_share: float = 0.0
var sanctuary_left: float = 0.0
var nature_heal_pct: float = 0.0
var deep_roots: bool = false
var evergreen: float = 0.0
var lifebloom_hps: float = 0.0
var lifebloom_bloom: float = 0.0
var photosynthesis_heal: float = 0.0
var overgrowth: float = 0.0
var drought_left: float = 0.0
var drought_rejuv_only: bool = false
var loam: float = 0.0
var thicket: bool = false
var ringward: bool = false
var bramble_dps: float = 0.0
var bramble_root: bool = false
var heartwood: float = 0.0
var germinate_shield: float = 0.0
var germinate_rejuv: int = 0
var germinate_seen: Dictionary = {}
var galvanic_grove: float = 0.0
var pulse_ratio_bonus: float = 0.0
var pulse_range: float = 8.5
var stormbond: bool = false
var stormbond_cap: int = 2
var stormbond_ids: Array[int] = []
var pulse_heal_pct: float = 0.0
var seedstorm_stacks: int = 0
var feedback: bool = false
var tempest_bloom_left: float = 0.0
var lightning_damage_pct: float = 0.0
var arc_hops: int = 0
var arc_range: float = 0.0
var charge_coil: int = 0
var conduction: float = 0.0
var totem_hop_pct: float = 0.0
var totem_shock: int = 0
var static_explode: bool = false
var rooted_left: float = 0.0
var eye_storm_left: float = 0.0
var storm_cloud_detached: bool = false
var storm_cloud_jumped: bool = false
var worldroot_zone_id: int = 0
var storm_cloud_id: int = 0
var lifebloom_target_id: int = 0


static func from_spend(spend: TalentSpend) -> TalentHooks:
	var hooks := TalentHooks.new()
	if spend == null:
		return hooks
	_apply_kindling(hooks, spend)
	_apply_cinderfrost(hooks, spend)
	_apply_aegis(hooks, spend)
	_apply_bastion(hooks, spend)
	_apply_wildroot(hooks, spend)
	_apply_tempest(hooks, spend)
	return hooks


static func _apply_kindling(hooks: TalentHooks, spend: TalentSpend) -> void:
	hooks.burn_store_bonus = _rank_value(spend, "kindling_embers_kindling", [0.08, 0.16, 0.25])
	hooks.live_coals_ratio = _rank_value(spend, "kindling_embers_live_coals", [0.20, 0.30])
	hooks.searing_refresh = _rank_value(spend, "kindling_embers_searing_marks", [0.5, 1.0, 1.5])
	hooks.cinder_spark_ratio = _rank_value(spend, "kindling_embers_cinder_spark", [0.06, 0.10])
	if spend.rank_of("kindling_embers_kindling") >= 3:
		hooks.hotter_coals = 0.15
	hooks.emberheart = _rank_value(spend, "kindling_embers_emberheart", [0.04, 0.08, 0.12])
	hooks.emberheart += _rank_value(spend, "kindling_mid_ember_core", [0.04, 0.08, 0.12])
	hooks.fire_crit_bonus = _rank_value(spend, "kindling_detonation_hot_hands", [0.02, 0.04, 0.06])
	hooks.critical_mass = _rank_value(spend, "kindling_detonation_critical_mass", [0.12, 0.20])
	hooks.flashover_burn = _rank_value(spend, "kindling_detonation_flashover", [0.15, 0.25])
	hooks.fire_crit_damage_bonus = _rank_value(spend, "kindling_detonation_glass_furnace", [0.15, 0.30, 0.45])
	hooks.fire_crit_damage_bonus += _rank_value(spend, "kindling_mid_pyromania", [0.05, 0.10, 0.15])
	hooks.afterburn = _rank_value(spend, "kindling_detonation_afterburn", [0.16, 0.32, 0.40])
	hooks.fire_damage_pct += _rank_value(spend, "kindling_mid_cinder_focus", [0.04, 0.07, 0.10])
	hooks.burned_damage_pct += _rank_value(spend, "kindling_mid_burnbrand", [0.03, 0.06, 0.09])
	hooks.singe_rank = spend.rank_of("kindling_mid_singe")
	hooks.scorch_snare = _rank_value(spend, "kindling_mid_scorch", [0.12, 0.18, 0.24])
	hooks.scorch_store = _rank_value(spend, "kindling_mid_scorch", [0.08, 0.12, 0.16])
	if spend.rank_of("kindling_mid_scorch") >= 3:
		hooks.scorch_pyre_splash = 0.15


static func _apply_cinderfrost(hooks: TalentHooks, spend: TalentSpend) -> void:
	hooks.sootbrand_stacks = int(_rank_value(spend, "cinderfrost_cinder_sootbrand", [1.0, 2.0, 3.0]))
	hooks.wick = _rank_value(spend, "cinderfrost_cinder_wick", [0.05, 0.08])
	hooks.smother = _rank_value(spend, "cinderfrost_cinder_wraithfire", [0.0, 0.08, 0.15])
	hooks.pitch_skin = _rank_value(spend, "cinderfrost_cinder_pitch_skin", [0.12, 0.20])
	hooks.cinderfeed = _rank_value(spend, "cinderfrost_cinder_cinderfeed", [0.04, 0.07, 0.10])
	hooks.wraithfire_rank = spend.rank_of("cinderfrost_cinder_wraithfire")
	hooks.kiln_rank = int(_rank_value(spend, "cinderfrost_frostfire_kiln", [1.0, 2.0]))
	hooks.quench = spend.rank_of("cinderfrost_frostfire_quench") > 0
	hooks.glaze = spend.rank_of("cinderfrost_frostfire_glaze") > 0
	hooks.fumarole_amp = _rank_value(spend, "cinderfrost_frostfire_fumarole", [0.05, 0.10, 0.15])
	hooks.fumarole_time = _rank_value(spend, "cinderfrost_frostfire_fumarole", [0.0, 1.0, 2.0])
	hooks.alloy = _rank_value(spend, "cinderfrost_frostfire_alloy", [0.03, 0.06, 0.08])
	hooks.fire_damage_pct += _rank_value(spend, "cinderfrost_mid_duality", [0.04, 0.07, 0.10])
	hooks.fire_damage_pct += _rank_value(spend, "cinderfrost_mid_ash", [0.03, 0.06, 0.09])
	hooks.shadow_damage_pct += _rank_value(spend, "cinderfrost_mid_ash", [0.03, 0.06, 0.09])
	hooks.chilled_damage_pct += _rank_value(spend, "cinderfrost_mid_frostbite", [0.03, 0.06, 0.09])
	hooks.afflicted_damage_pct += _rank_value(spend, "cinderfrost_mid_soot", [0.03, 0.06, 0.09])
	hooks.ice_damage_pct += _rank_value(spend, "cinderfrost_mid_steam", [0.02, 0.04, 0.06])
	hooks.auto_damage_bonus += _rank_value(spend, "cinderfrost_mid_branding", [4.0, 8.0, 12.0])


static func _apply_aegis(hooks: TalentHooks, spend: TalentSpend) -> void:
	hooks.max_health_pct = _rank_value(spend, "aegis_plate_slab", [0.15, 0.28, 0.40])
	hooks.max_health_pct += _rank_value(spend, "aegis_mid_stamina", [0.04, 0.07, 0.10])
	hooks.shared_plate = spend.rank_of("aegis_plate_shared_plate") > 0
	hooks.shared_plate_shield = _rank_value(spend, "aegis_plate_shared_plate", [50.0, 80.0])
	hooks.anointed = spend.rank_of("aegis_plate_anointed") > 0
	if hooks.anointed:
		hooks.anointed_heal = 40.0 if spend.rank_of("aegis_plate_anointed") >= 2 else 0.0
		hooks.anointed_threat = _rank_value(spend, "aegis_plate_anointed", [25.0, 40.0])
	hooks.second_skin_heal = _rank_value(spend, "aegis_plate_second_skin", [50.0, 90.0, 90.0])
	if spend.rank_of("aegis_plate_second_skin") >= 3:
		hooks.shield_pct = 0.20
	hooks.shield_pct += _rank_value(spend, "aegis_mid_plating", [0.04, 0.08, 0.12])
	hooks.brace_dr = _rank_value(spend, "aegis_plate_brace", [0.10, 0.16, 0.22])
	if spend.rank_of("aegis_plate_brace") >= 3:
		hooks.brace_heal = 40.0
	hooks.spite_damage = _rank_value(spend, "aegis_grudge_spite", [0.04, 0.07, 0.10])
	hooks.spite_dr = _rank_value(spend, "aegis_grudge_spite", [0.05, 0.08, 0.12])
	hooks.goad = spend.rank_of("aegis_grudge_goad") > 0
	hooks.marked_prey = _rank_value(spend, "aegis_grudge_marked_prey", [0.04, 0.07, 0.10])
	hooks.claim_threat = _rank_value(spend, "aegis_grudge_claim", [0.12, 0.20, 0.35])
	hooks.ire = spend.rank_of("aegis_grudge_ire") > 0
	if hooks.ire:
		hooks.ire_ratio = _rank_value(spend, "aegis_grudge_ire", [0.15, 0.25, 0.25])
		hooks.ire_cap = _rank_value(spend, "aegis_grudge_ire", [80.0, 120.0, 120.0])
	if spend.rank_of("aegis_grudge_ire") >= 3:
		hooks.peal = true
	hooks.lunge = spend.rank_of("aegis_auto_iron_fist") > 0
	hooks.passive_dr += _rank_value(spend, "aegis_mid_guard", [0.02, 0.04, 0.06])
	hooks.spite_damage += _rank_value(spend, "aegis_mid_resolve", [0.03, 0.06, 0.09])
	hooks.shielded_dr += _rank_value(spend, "aegis_mid_grit", [0.02, 0.04, 0.06])
	hooks.auto_threat_bonus += _rank_value(spend, "aegis_mid_heavy_hands", [6.0, 12.0, 18.0])


static func _apply_bastion(hooks: TalentHooks, spend: TalentSpend) -> void:
	hooks.footing = _rank_value(spend, "bastion_rampart_footing", [0.04, 0.07, 0.10])
	hooks.footing += _rank_value(spend, "bastion_mid_foundation", [0.04, 0.07, 0.10])
	if spend.rank_of("bastion_rampart_undertow") > 0:
		hooks.undertow = true
		hooks.undertow_charges = hooks.undertow_charge_max
	hooks.wall_hp_pct = _rank_value(spend, "bastion_rampart_masonry", [0.10, 0.20, 0.30])
	hooks.wall_hp_pct += _rank_value(spend, "bastion_mid_bastion", [0.04, 0.08, 0.12])
	hooks.wall_cdr = _rank_value(spend, "bastion_rampart_masonry", [0.08, 0.14, 0.20])
	hooks.palisade_length = _rank_value(spend, "bastion_rampart_palisade", [0.12, 0.20, 0.35])
	if spend.rank_of("bastion_rampart_palisade") >= 3:
		hooks.palisade_duration = 1.5
	hooks.battlement_rank = spend.rank_of("bastion_rampart_battlement")
	if spend.rank_of("bastion_rampart_battlement") >= 2:
		hooks.pavise = true
	if spend.rank_of("bastion_rampart_battlement") >= 3:
		hooks.mortar = 0.35
	hooks.vow_ally_shield = _rank_value(spend, "bastion_oath_vow", [0.06, 0.12, 0.18])
	hooks.vow_ally_shield += _rank_value(spend, "bastion_mid_aegis_wall", [0.04, 0.08, 0.12])
	hooks.mercy_dealt = _rank_value(spend, "bastion_oath_vow", [0.04, 0.08, 0.12])
	hooks.mercy_taken = hooks.mercy_dealt
	hooks.mercy_taken += _rank_value(spend, "bastion_mid_oathbound", [0.03, 0.06, 0.09])
	hooks.halo = spend.rank_of("bastion_oath_halo") > 0
	if hooks.halo:
		hooks.halo_cap = 0.20 if spend.rank_of("bastion_oath_halo") >= 2 else 0.15
	hooks.cover = spend.rank_of("bastion_oath_cover") > 0
	hooks.cover_extra = _rank_value(spend, "bastion_oath_cover", [1.5, 3.0])
	hooks.redirect = _rank_value(spend, "bastion_oath_redirect", [0.06, 0.12, 0.18])
	hooks.bodyguard_dr = _rank_value(spend, "bastion_oath_bodyguard", [0.08, 0.15, 0.15])
	if spend.rank_of("bastion_oath_bodyguard") >= 3:
		hooks.bodyguard_convert = 0.25
	hooks.passive_dr += _rank_value(spend, "bastion_mid_barricade", [0.02, 0.04, 0.06])
	hooks.auto_self_shield_bonus += _rank_value(spend, "bastion_mid_ward", [8.0, 16.0, 24.0])


static func _apply_wildroot(hooks: TalentHooks, spend: TalentSpend) -> void:
	hooks.nature_heal_pct = _rank_value(spend, "wildroot_canopy_greenheart", [0.04, 0.07, 0.10])
	hooks.nature_heal_pct += _rank_value(spend, "wildroot_mid_vitality", [0.04, 0.07, 0.10])
	hooks.nature_heal_pct += _rank_value(spend, "wildroot_mid_groveheart", [0.04, 0.08, 0.12])
	hooks.deep_roots = spend.rank_of("wildroot_canopy_deep_roots") > 0
	hooks.evergreen = _rank_value(spend, "wildroot_canopy_evergreen", [0.04, 0.07, 0.10])
	hooks.evergreen += _rank_value(spend, "wildroot_mid_bloom", [0.04, 0.07, 0.10])
	hooks.lifebloom_hps = _rank_value(spend, "wildroot_canopy_lifebloom", [14.0, 24.0, 24.0])
	if spend.rank_of("wildroot_canopy_lifebloom") >= 2:
		hooks.lifebloom_bloom = 60.0
	if spend.rank_of("wildroot_canopy_lifebloom") >= 3:
		hooks.lifebloom_bloom = 90.0
		hooks.overgrowth = 0.12
	hooks.photosynthesis_heal = _rank_value(spend, "wildroot_canopy_photosynthesis", [8.0, 14.0, 18.0])
	hooks.loam = _rank_value(spend, "wildroot_grove_loam", [0.04, 0.07, 0.10])
	hooks.loam += _rank_value(spend, "wildroot_mid_thorns", [0.04, 0.08, 0.12])
	hooks.thicket = spend.rank_of("wildroot_grove_thicket") > 0
	hooks.ringward = spend.rank_of("wildroot_grove_ringward") > 0
	if spend.rank_of("wildroot_grove_ringward") > 0:
		hooks.heartwood = 0.05 if spend.rank_of("wildroot_grove_ringward") < 2 else 0.08
	hooks.bramble_dps = _rank_value(spend, "wildroot_grove_bramble", [8.0, 12.0, 20.0])
	hooks.bramble_root = spend.rank_of("wildroot_grove_bramble") >= 3
	hooks.germinate_shield = _rank_value(spend, "wildroot_grove_germinate", [40.0, 70.0, 70.0])
	hooks.germinate_rejuv = int(_rank_value(spend, "wildroot_grove_germinate", [0.0, 1.0, 2.0]))
	hooks.heal_dealt_pct += _rank_value(spend, "wildroot_mid_canopy", [0.02, 0.04, 0.06])
	hooks.ally_heal_bonus += _rank_value(spend, "wildroot_mid_dew", [4.0, 8.0, 12.0])


static func _apply_tempest(hooks: TalentHooks, spend: TalentSpend) -> void:
	hooks.galvanic_grove = _rank_value(spend, "tempest_stormbloom_galvanic_grove", [0.03, 0.06, 0.08])
	hooks.pulse_heal_pct = _rank_value(spend, "tempest_stormbloom_galvanic_grove", [0.04, 0.07, 0.10])
	hooks.pulse_heal_pct += _rank_value(spend, "tempest_mid_pulse", [0.03, 0.06, 0.10])
	hooks.pulse_ratio_bonus = _rank_value(spend, "tempest_stormbloom_atonement", [0.10, 0.20, 0.30])
	if spend.rank_of("tempest_stormbloom_atonement") >= 3:
		hooks.pulse_range = 12.0
	hooks.stormbond = spend.rank_of("tempest_stormbloom_stormbond") > 0
	hooks.seedstorm_stacks = int(_rank_value(spend, "tempest_stormbloom_seedstorm", [1.0, 2.0, 3.0]))
	hooks.feedback = spend.rank_of("tempest_stormbloom_feedback") > 0
	hooks.lightning_damage_pct = _rank_value(spend, "tempest_thunderhead_high_voltage", [0.04, 0.07, 0.10])
	hooks.lightning_damage_pct += _rank_value(spend, "tempest_mid_charge", [0.04, 0.07, 0.10])
	hooks.lightning_damage_pct += _rank_value(spend, "tempest_mid_conduit", [0.04, 0.08, 0.12])
	hooks.lightning_damage_pct += _rank_value(spend, "tempest_mid_stormheart", [0.03, 0.06, 0.09])
	hooks.nature_heal_pct += _rank_value(spend, "tempest_mid_stormheart", [0.03, 0.06, 0.09])
	hooks.conduction = _rank_value(spend, "tempest_thunderhead_high_voltage", [0.03, 0.06, 0.08])
	hooks.conduction += _rank_value(spend, "tempest_mid_static_field", [0.03, 0.06, 0.09])
	if spend.rank_of("tempest_thunderhead_arc") > 0:
		hooks.arc_hops = 1
		hooks.arc_range = 2.0 if spend.rank_of("tempest_thunderhead_arc") >= 2 else 0.0
	hooks.charge_coil = int(_rank_value(spend, "tempest_thunderhead_charge_coil", [2.0, 3.0, 4.0]))
	hooks.totem_hop_pct = _rank_value(spend, "tempest_thunderhead_totem_surge", [0.50, 0.70, 0.70])
	if spend.rank_of("tempest_thunderhead_totem_surge") >= 3:
		hooks.totem_shock = 2
	hooks.static_explode = spend.rank_of("tempest_thunderhead_static") > 0
	hooks.auto_damage_bonus += _rank_value(spend, "tempest_mid_spark", [4.0, 8.0, 12.0])


static func apply_compile(abilities: Array[AbilityDef], spend: TalentSpend) -> void:
	var hooks := from_spend(spend)
	for i in abilities.size():
		var ab: AbilityDef = abilities[i]
		if ab == null:
			continue
		if ab.skill_id == "pyroblast" or ab.skill_id == "pyre":
			hooks.pyroblast_slot = i
		_apply_bulwark_compile(ab, hooks)
		_apply_storm_druid_compile(ab, hooks)
		if not ab.has_element(AbilityDef.Element.FIRE):
			continue
		if hooks.fire_crit_bonus > 0.0:
			ab.crit_chance += hooks.fire_crit_bonus
		if hooks.fire_crit_damage_bonus > 0.0:
			ab.crit_damage = 2.0 + hooks.fire_crit_damage_bonus
		if hooks.smother > 0.0:
			ab.mana_cost *= maxf(0.0, 1.0 - hooks.smother)
		if hooks.impact_heat > 0.0 and (
			ab.delivery == AbilityDef.Delivery.AOE_EXPLOSION
			or ab.delivery == AbilityDef.Delivery.NOVA
			or ab.delivery == AbilityDef.Delivery.METEOR
		):
			ab.damage *= 1.0 + hooks.impact_heat
			ab.tick_damage *= 1.0 + hooks.impact_heat
		if hooks.alloy > 0.0 and ab.has_element(AbilityDef.Element.ICE):
			ab.damage *= 1.0 + hooks.alloy
			ab.tick_damage *= 1.0 + hooks.alloy
		if hooks.fire_damage_pct > 0.0:
			ab.damage *= 1.0 + hooks.fire_damage_pct
			ab.tick_damage *= 1.0 + hooks.fire_damage_pct


static func _apply_bulwark_compile(ab: AbilityDef, hooks: TalentHooks) -> void:
	if ab == null or hooks == null:
		return
	if hooks.peal and (
		ab.delivery == AbilityDef.Delivery.NOVA
		or ab.delivery == AbilityDef.Delivery.AOE_EXPLOSION
	) and ab.skill_id.is_empty():
		ab.threat_mult *= 2.5
	if hooks.claim_threat > 0.0 and ab.skill_id.is_empty() and (ab.damage > 0.05 or ab.tick_damage > 0.05):
		ab.threat_mult *= 1.0 + hooks.claim_threat
	if hooks.footing > 0.0 and ab.delivery == AbilityDef.Delivery.GROUND_AOE and ab.skill_id.is_empty():
		ab.damage *= 1.0 + hooks.footing
		ab.tick_damage *= 1.0 + hooks.footing
		ab.heal *= 1.0 + hooks.footing
		ab.shield *= 1.0 + hooks.footing
		ab.tick_shield *= 1.0 + hooks.footing
	if hooks.wall_cdr > 0.0 and ab.delivery == AbilityDef.Delivery.WALL:
		ab.cooldown *= maxf(0.05, 1.0 - hooks.wall_cdr)
	if hooks.palisade_length > 0.0 and ab.delivery == AbilityDef.Delivery.WALL:
		var base_len := CombatBalance.flat("wall.length")
		ab.skillshot_width = maxf(ab.skillshot_width, base_len) * (1.0 + hooks.palisade_length)
	if hooks.palisade_duration > 0.0 and ab.delivery == AbilityDef.Delivery.WALL:
		ab.zone_duration = maxf(ab.zone_duration, 4.0) + hooks.palisade_duration
	if hooks.pavise and ab.delivery == AbilityDef.Delivery.WALL and ab.has_element(AbilityDef.Element.PROTECTION):
		ab.zone_duration = CombatBalance.flat("wall.protection.time") + 1.0


static func _apply_storm_druid_compile(ab: AbilityDef, hooks: TalentHooks) -> void:
	if ab == null or hooks == null or not ab.skill_id.is_empty():
		return
	if not ab.has_element(AbilityDef.Element.NATURE):
		return
	if hooks.thicket and ab.delivery == AbilityDef.Delivery.GROUND_AOE:
		ab.zone_duration = 8.0
		ab.aoe_radius *= 1.15
		ab.aoe_radius_max *= 1.15
	if hooks.loam > 0.0 and (
		ab.delivery == AbilityDef.Delivery.GROUND_AOE
		or ab.delivery == AbilityDef.Delivery.AURA
		or ab.delivery == AbilityDef.Delivery.WALL
	):
		ab.heal *= 1.0 + hooks.loam
		ab.tick_damage *= 1.0 + hooks.loam


static func _rank_value(spend: TalentSpend, talent_id: String, values: Array) -> float:
	var rank := spend.rank_of(talent_id)
	if rank <= 0 or values.is_empty():
		return 0.0
	return float(values[mini(rank, values.size()) - 1])
