class_name StatusIcons
extends Object

const ICON_DIR := "res://assets/ui/icons/"
const _ALIASES := {
	"overcharged": "overcharge",
	"overheat": "overcharge",
}
const _PAINTERLY := {
	"bolt": true,
	"missiles": true,
	"ground_aoe": true,
	"burst": true,
	"aura": true,
	"ray": true,
	"meteor": true,
	"nova": true,
	"wall": true,
	"wave": true,
	"fire": true,
	"ice": true,
	"lightning": true,
	"shadow": true,
	"nature": true,
	"divine": true,
	"protection": true,
	"wind": true,
	"illusion": true,
}

static var _cache: Dictionary = {}


static func stack_text(data: Dictionary) -> String:
	var badge := String(data.get("badge", ""))
	if not badge.is_empty():
		return badge
	var count := int(data.get("stacks", 0))
	return str(count) if count > 0 else ""


static func texture_for(icon_id: String) -> Texture2D:
	var painted := _painterly_texture(icon_id, "")
	if painted:
		return painted
	var base := _spell_base_icon(icon_id)
	if not base.is_empty():
		return _procedural_base(base, "")
	if icon_id.is_empty():
		return _procedural(icon_id)
	if _cache.has(icon_id):
		return _cache[icon_id]
	var key := String(_ALIASES.get(icon_id, icon_id))
	var path := ICON_DIR + key + ".png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			_cache[icon_id] = tex
			return tex
	return _procedural(icon_id)


static func texture_for_ability(icon_id: String, infusion_tag: String = "") -> Texture2D:
	var painted := _painterly_texture(icon_id, infusion_tag)
	if painted:
		return painted
	var base := _spell_base_icon(icon_id)
	if not base.is_empty():
		return _procedural_base(base, infusion_tag)
	if icon_id.is_empty() or infusion_tag.is_empty():
		return texture_for(icon_id)
	var variant_id := "%s_infused_%s" % [icon_id, infusion_tag]
	var variant_path := ICON_DIR + variant_id + ".png"
	if ResourceLoader.exists(variant_path):
		return texture_for(variant_id)
	return texture_for(icon_id)


static func _painterly_key(icon_id: String) -> String:
	var base := _spell_base_icon(icon_id)
	if not base.is_empty():
		return base
	return String(_ALIASES.get(icon_id, icon_id))


static func _painterly_texture(icon_id: String, infusion_tag: String) -> Texture2D:
	var key := _painterly_key(icon_id)
	if key.is_empty():
		return null
	if not infusion_tag.is_empty():
		var variant_id := "%s_infused_%s" % [key, infusion_tag]
		var variant := _load_png(variant_id)
		if variant:
			return variant
	if _PAINTERLY.has(key):
		return _load_png(key)
	return null


static func _load_png(stem: String) -> Texture2D:
	if _cache.has(stem):
		return _cache[stem]
	var path := ICON_DIR + stem + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[stem] = tex
	return tex


static func _spell_base_icon(icon_id: String) -> String:
	match icon_id:
		"bolt", "firebolt", "radiant_bolt", "energy_bolt":
			return "bolt"
		"missiles", "thunder_wave", "chain_spark":
			return "missiles"
		"ground_aoe", "field":
			return "ground_aoe"
		"burst", "aoe_explosion":
			return "burst"
		"aura":
			return "aura"
		"ray", "judgment":
			return "ray"
		"meteor":
			return "meteor"
		"nova", "bastion":
			return "nova"
		"wall":
			return "wall"
		"target", "shield", "ward_cast":
			return "target"
		"wave":
			return "wave"
	return ""


static func _procedural_base(base_id: String, infusion_tag: String) -> Texture2D:
	var key := "%s|%s" % [base_id, infusion_tag]
	if _cache.has(key):
		return _cache[key]
	var pal := _infusion_palette(infusion_tag)
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_round(img, pal.bg)
	_draw_base_glyph(img, base_id, pal.ink, pal.glow)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _infusion_palette(tag: String) -> Dictionary:
	match tag:
		"fire":
			return {"bg": Color(0.28, 0.07, 0.02), "ink": Color(1.0, 0.48, 0.12), "glow": Color(1.0, 0.86, 0.32)}
		"ice":
			return {"bg": Color(0.05, 0.14, 0.26), "ink": Color(0.48, 0.84, 1.0), "glow": Color(0.82, 0.96, 1.0)}
		"lightning", "storm":
			return {"bg": Color(0.12, 0.07, 0.2), "ink": Color(0.82, 0.7, 1.0), "glow": Color(1.0, 0.95, 0.55)}
		"shadow":
			return {"bg": Color(0.1, 0.04, 0.16), "ink": Color(0.72, 0.38, 0.95), "glow": Color(0.92, 0.7, 1.0)}
		"nature":
			return {"bg": Color(0.04, 0.16, 0.07), "ink": Color(0.4, 0.88, 0.4), "glow": Color(0.78, 1.0, 0.52)}
		"divine", "holy":
			return {"bg": Color(0.2, 0.14, 0.04), "ink": Color(1.0, 0.84, 0.36), "glow": Color(1.0, 0.97, 0.78)}
		"protection":
			return {"bg": Color(0.1, 0.14, 0.22), "ink": Color(0.72, 0.82, 1.0), "glow": Color(0.94, 0.97, 1.0)}
		"wind":
			return {"bg": Color(0.06, 0.16, 0.14), "ink": Color(0.72, 0.92, 0.82), "glow": Color(0.92, 1.0, 0.9)}
		"illusion":
			return {"bg": Color(0.16, 0.05, 0.14), "ink": Color(0.92, 0.55, 0.82), "glow": Color(1.0, 0.78, 0.92)}
		_:
			return {"bg": Color(0.1, 0.12, 0.18), "ink": Color(0.78, 0.86, 1.0), "glow": Color(0.95, 0.97, 1.0)}


static func _draw_base_glyph(img: Image, base_id: String, ink: Color, glow: Color) -> void:
	match base_id:
		"bolt":
			_poly(img, [Vector2(14, 36), Vector2(22, 20), Vector2(18, 20), Vector2(30, 10), Vector2(26, 22), Vector2(30, 22), Vector2(16, 38)], ink)
			_disc(img, 30, 12, 3, glow)
		"missiles":
			_poly(img, [Vector2(10, 32), Vector2(16, 16), Vector2(20, 18), Vector2(14, 34)], ink)
			_poly(img, [Vector2(20, 36), Vector2(26, 14), Vector2(30, 16), Vector2(24, 38)], glow)
			_poly(img, [Vector2(30, 32), Vector2(36, 18), Vector2(40, 20), Vector2(34, 34)], ink)
		"ground_aoe":
			for y in range(28, 42):
				var t := absf(float(y) - 34.0) / 7.0
				var half := int(round(lerpf(16.0, 6.0, t)))
				for x in range(24 - half, 25 + half):
					var edge := y == 28 or y == 41 or x == 24 - half or x == 24 + half
					img.set_pixel(x, y, glow if edge else ink.darkened(0.25))
			_disc(img, 24, 22, 5, ink)
			_disc(img, 24, 22, 2, glow)
		"burst":
			_disc(img, 24, 24, 14, ink.darkened(0.2))
			_disc(img, 24, 24, 9, ink)
			_disc(img, 24, 24, 4, glow)
			_star(img, 24, 24, 18, 6, glow)
		"aura":
			for r in [16, 11, 6]:
				_ring_pixels(img, 24, 24, r, ink if r > 8 else glow)
			_disc(img, 24, 24, 3, glow)
		"ray":
			for y in range(8, 42):
				var t := absf(float(y) - 24.0) / 16.0
				var half := int(round(lerpf(4.0, 1.0, t)))
				for x in range(24 - half, 25 + half):
					img.set_pixel(x, y, ink.lerp(glow, 1.0 - t))
			_disc(img, 24, 9, 4, glow)
			_disc(img, 24, 40, 3, ink)
		"meteor":
			for i in 12:
				var t := float(i) / 11.0
				_disc(img, 16 + int(round(t * 10.0)), 8 + int(round(t * 16.0)), int(round(lerpf(2.0, 6.0, t))), ink.lerp(glow, t))
			_disc(img, 30, 32, 8, ink)
			_disc(img, 28, 30, 3, glow)
		"nova":
			_star(img, 24, 24, 17, 6, ink)
			_star(img, 24, 24, 9, 3, glow)
			_disc(img, 24, 24, 3, glow)
		"wall":
			for y in range(10, 40):
				for x in range(16, 33):
					var edge := x == 16 or x == 32 or y == 10 or y == 39
					img.set_pixel(x, y, glow if edge else ink.darkened(0.15))
			_disc(img, 24, 16, 3, glow)
		"target":
			_target_reticle(img, ink, glow)
		"shield":
			_target_reticle(img, ink, glow)
		"wave":
			_poly(img, [Vector2(8, 34), Vector2(18, 14), Vector2(24, 18), Vector2(14, 36)], ink)
			_poly(img, [Vector2(16, 36), Vector2(28, 12), Vector2(36, 16), Vector2(24, 38)], glow)
			_poly(img, [Vector2(26, 36), Vector2(38, 18), Vector2(42, 22), Vector2(32, 38)], ink)
		_:
			_disc(img, 24, 24, 10, ink)


static func _ring_pixels(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= 48 or y >= 48:
				continue
			var d := Vector2(float(x - cx), float(y - cy)).length()
			if absf(d - float(radius)) <= 1.35:
				img.set_pixel(x, y, color)


static func _procedural(icon_id: String) -> Texture2D:
	if _cache.has(icon_id):
		return _cache[icon_id]
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_icon(img, icon_id)
	var tex := ImageTexture.create_from_image(img)
	_cache[icon_id] = tex
	return tex


static func _draw_icon(img: Image, icon_id: String) -> void:
	match icon_id:
		"overcharge", "overcharged", "overheat":
			_fill_round(img, Color(0.28, 0.18, 0.04, 1.0))
			_star(img, 24, 24, 16, 7, Color(1.0, 0.86, 0.28))
			_star(img, 24, 24, 8, 3, Color(1.0, 0.97, 0.72))
		"fire_infused", "burn":
			_fill_round(img, Color(0.28, 0.08, 0.02, 1.0))
			_flame(img, Color(1.0, 0.42, 0.08), Color(1.0, 0.82, 0.22))
		"ice_infused", "chilled":
			_fill_round(img, Color(0.06, 0.16, 0.28, 1.0))
			_snow(img, Color(0.72, 0.94, 1.0))
		"frozen":
			_fill_round(img, Color(0.08, 0.28, 0.42, 1.0))
			_snow(img, Color(0.88, 0.98, 1.0))
			_disc(img, 24, 24, 4, Color(0.7, 0.92, 1.0))
		"freeze_immune":
			_fill_round(img, Color(0.16, 0.2, 0.24, 1.0))
			_snow(img, Color(0.55, 0.68, 0.78))
			_slash(img, Color(0.95, 0.38, 0.32))
		"storm_infused", "charged", "shocked", "lightning":
			_fill_round(img, Color(0.12, 0.08, 0.18, 1.0) if icon_id == "shocked" or icon_id == "charged" else Color(0.08, 0.1, 0.28, 1.0))
			_bolt(img, Color(0.88, 0.72, 1.0) if icon_id == "shocked" or icon_id == "charged" else Color(0.7, 0.82, 1.0))
		"shadow", "afflicted":
			_fill_round(img, Color(0.1, 0.04, 0.16, 1.0))
			_disc(img, 24, 24, 11, Color(0.42, 0.16, 0.62))
			_disc(img, 24, 24, 5, Color(0.78, 0.42, 1.0))
		"nature", "rejuvenation":
			_fill_round(img, Color(0.05, 0.16, 0.08, 1.0))
			_disc(img, 24, 28, 8, Color(0.32, 0.72, 0.28))
			_star(img, 24, 18, 10, 4, Color(0.7, 1.0, 0.45))
		"divine", "holy_blessing":
			_fill_round(img, Color(0.2, 0.14, 0.04, 1.0))
			_star(img, 24, 24, 15, 6, Color(1.0, 0.9, 0.42))
			_disc(img, 24, 24, 5, Color(1.0, 0.97, 0.78))
		"protection":
			_fill_round(img, Color(0.1, 0.14, 0.22, 1.0))
			_shield(img, Color(0.78, 0.86, 1.0))
		"altered_fire":
			_fill_round(img, Color(0.28, 0.08, 0.02, 1.0))
			_flame(img, Color(1.0, 0.42, 0.08), Color(1.0, 0.82, 0.22))
		"altered_ice", "frost_trail":
			_fill_round(img, Color(0.06, 0.16, 0.28, 1.0))
			_snow(img, Color(0.72, 0.94, 1.0))
		"altered_lightning":
			_fill_round(img, Color(0.08, 0.1, 0.28, 1.0))
			_bolt(img, Color(0.7, 0.82, 1.0))
		"altered_shadow", "shadow_pact":
			_fill_round(img, Color(0.1, 0.04, 0.16, 1.0))
			_disc(img, 24, 24, 11, Color(0.42, 0.16, 0.62))
			_disc(img, 24, 24, 5, Color(0.78, 0.42, 1.0))
		"encore":
			_fill_round(img, Color(0.2, 0.12, 0.04, 1.0))
			_encore(img)
		"ward":
			_fill_round(img, Color(0.22, 0.14, 0.04, 1.0))
			_shield(img, Color(1.0, 0.72, 0.28))
		"slow":
			_fill_round(img, Color(0.08, 0.14, 0.24, 1.0))
			_chevrons(img, Color(0.62, 0.84, 1.0))
		"umbral":
			_fill_round(img, Color(0.05, 0.06, 0.14, 1.0))
			_umbral(img)
		"firebolt":
			_fill_round(img, Color(0.28, 0.07, 0.02, 1.0))
			_firebolt(img)
		"ice_blast":
			_fill_round(img, Color(0.05, 0.15, 0.28, 1.0))
			_ice_blast(img)
		"thunder_wave":
			_fill_round(img, Color(0.07, 0.1, 0.28, 1.0))
			_thunder_wave(img)
		"meteor":
			_fill_round(img, Color(0.22, 0.06, 0.02, 1.0))
			_meteor(img)
		"chilled_ground":
			_fill_round(img, Color(0.05, 0.16, 0.28, 1.0))
			_chilled_ground(img)
		"attenuate":
			_fill_round(img, Color(0.1, 0.08, 0.16, 1.0))
			_attenuate(img)
		"auto":
			_fill_round(img, Color(0.16, 0.12, 0.06, 1.0))
			_auto_attack(img)
		"combust":
			_fill_round(img, Color(0.3, 0.06, 0.02, 1.0))
			_flame(img, Color(1.0, 0.28, 0.04), Color(1.0, 0.78, 0.18))
		"atonement":
			_fill_round(img, Color(0.18, 0.14, 0.05, 1.0))
			_atonement(img)
		"radiant_bolt":
			_fill_round(img, Color(0.22, 0.14, 0.04, 1.0))
			_radiant_bolt(img)
		"ward_cast":
			_fill_round(img, Color(0.14, 0.16, 0.22, 1.0))
			_shield(img, Color(0.92, 0.94, 1.0))
		"judgment":
			_fill_round(img, Color(0.2, 0.14, 0.04, 1.0))
			_judgment(img)
		"bastion":
			_fill_round(img, Color(0.16, 0.14, 0.06, 1.0))
			_bastion(img)
		"sanctuary":
			_fill_round(img, Color(0.18, 0.12, 0.04, 1.0))
			_sanctuary(img)
		"radiance":
			_fill_round(img, Color(0.22, 0.16, 0.04, 1.0))
			_star(img, 24, 24, 16, 7, Color(1.0, 0.9, 0.4))
			_star(img, 24, 24, 8, 3, Color(1.0, 0.98, 0.78))
		"holy":
			_fill_round(img, Color(0.2, 0.14, 0.04, 1.0))
			_star(img, 24, 24, 15, 6, Color(1.0, 0.9, 0.42))
			_disc(img, 24, 24, 5, Color(1.0, 0.97, 0.78))
		_:
			_fill_round(img, Color(0.16, 0.16, 0.2, 1.0))
			_disc(img, 24, 24, 10, Color(0.85, 0.85, 0.9))


static func _fill_round(img: Image, color: Color) -> void:
	var cx := 23.5
	var cy := 23.5
	var rad := 23.5
	for y in 48:
		for x in 48:
			var d := Vector2(float(x) - cx, float(y) - cy).length()
			var a := clampf(rad - d, 0.0, 1.0)
			if a > 0.0:
				var c := color
				c.a *= a
				img.set_pixel(x, y, c)


static func _disc(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= 48 or y >= 48:
				continue
			var ddx := x - cx
			var ddy := y - cy
			if ddx * ddx + ddy * ddy <= r2:
				img.set_pixel(x, y, color)


static func _star(img: Image, cx: int, cy: int, outer: int, inner: int, color: Color) -> void:
	for y in 48:
		for x in 48:
			var v := Vector2(float(x - cx), float(y - cy))
			var ang := atan2(v.x, -v.y)
			if ang < 0.0:
				ang += TAU
			var t := fposmod(ang / (TAU / 8.0), 1.0)
			var r := lerpf(float(outer), float(inner), absf(t - 0.5) * 2.0)
			if v.length() <= r:
				img.set_pixel(x, y, color)


static func _flame(img: Image, outer: Color, inner: Color) -> void:
	for y in range(8, 42):
		for x in range(10, 38):
			var nx := (float(x) - 24.0) / 12.0
			var ny := (float(y) - 30.0) / 16.0
			var wobble := 0.12 * sin(float(y) * 0.45)
			var body := nx * nx / maxf(0.18, 1.05 + ny * 0.7) + (ny + wobble) * (ny + wobble)
			if body < 1.0:
				img.set_pixel(x, y, outer.lerp(inner, clampf(1.0 - body, 0.0, 1.0)))
	_disc(img, 24, 34, 5, inner)


static func _snow(img: Image, color: Color) -> void:
	_spoke(img, 24, 24, 0.0, 15, color)
	_spoke(img, 24, 24, 60.0, 15, color)
	_spoke(img, 24, 24, 120.0, 15, color)
	_disc(img, 24, 24, 3, Color.WHITE)


static func _spoke(img: Image, cx: int, cy: int, deg: float, length: int, color: Color) -> void:
	var rad := deg_to_rad(deg)
	var dir := Vector2(sin(rad), -cos(rad))
	for i in range(-length, length + 1):
		var p := Vector2(float(cx), float(cy)) + dir * float(i)
		_stamp(img, int(round(p.x)), int(round(p.y)), color)
		if abs(i) > 5 and abs(i) % 5 == 0:
			var side := Vector2(-dir.y, dir.x)
			for k in range(-3, 4):
				var q := p + side * float(k)
				_stamp(img, int(round(q.x)), int(round(q.y)), color)


static func _bolt(img: Image, color: Color) -> void:
	var pts: Array[Vector2] = [
		Vector2(28, 8), Vector2(18, 22), Vector2(25, 22), Vector2(16, 40),
		Vector2(30, 24), Vector2(22, 24), Vector2(32, 8)
	]
	_poly(img, pts, color)


static func _encore(img: Image) -> void:
	var gold := Color(1.0, 0.84, 0.38)
	var light := Color(1.0, 0.95, 0.7)
	for y in 48:
		for x in 48:
			var d := Vector2(float(x) - 24.0, float(y) - 24.0).length()
			if d < 14.2 or d > 17.8:
				continue
			if x > 26 and y < 20:
				continue
			img.set_pixel(x, y, gold)
	_poly(img, [Vector2(24, 7), Vector2(36, 15), Vector2(24, 22)], light)


static func _target_reticle(img: Image, ink: Color, glow: Color) -> void:
	_ring_pixels(img, 24, 24, 16, ink)
	_ring_pixels(img, 24, 24, 10, glow)
	_disc(img, 24, 24, 2, glow)
	for i in range(6, 12):
		img.set_pixel(24, i, glow)
		img.set_pixel(24, 47 - i, glow)
		img.set_pixel(i, 24, glow)
		img.set_pixel(47 - i, 24, glow)
	for i in range(13, 18):
		img.set_pixel(24, i, ink)
		img.set_pixel(24, 47 - i, ink)
		img.set_pixel(i, 24, ink)
		img.set_pixel(47 - i, 24, ink)


static func _shield(img: Image, color: Color) -> void:
	for y in range(8, 42):
		var t := float(y - 8) / 34.0
		var half := int(round(lerpf(13.0, 3.0, t * t)))
		for x in range(24 - half, 25 + half):
			img.set_pixel(x, y, color if y < 14 or y > 38 or x == 24 - half or x == 24 + half else color.darkened(0.15))
	_disc(img, 24, 18, 3, Color(1.0, 0.92, 0.55))


static func _chevrons(img: Image, color: Color) -> void:
	for i in 3:
		var y0 := 12 + i * 10
		for x in range(12, 37):
			var mid := absi(x - 24)
			var y := y0 + mid / 2
			_stamp(img, x, y, color)
			_stamp(img, x, y + 1, color)


static func _poly(img: Image, pts: Array[Vector2], color: Color) -> void:
	var min_x := 47
	var min_y := 47
	var max_x := 0
	var max_y := 0
	for p in pts:
		min_x = mini(min_x, int(p.x))
		min_y = mini(min_y, int(p.y))
		max_x = maxi(max_x, int(p.x))
		max_y = maxi(max_y, int(p.y))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_poly(Vector2(float(x) + 0.5, float(y) + 0.5), pts):
				img.set_pixel(x, y, color)


static func _point_in_poly(p: Vector2, pts: Array[Vector2]) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		if ((a.y > p.y) != (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / maxf(b.y - a.y, 0.0001) + a.x):
			inside = not inside
		j = i
	return inside


static func _stamp(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= 48 or y >= 48:
		return
	img.set_pixel(x, y, color)


static func _umbral(img: Image) -> void:
	_disc(img, 24, 24, 16, Color(0.1, 0.14, 0.28))
	_disc(img, 24, 24, 11, Color(0.05, 0.07, 0.16))
	_disc(img, 24, 24, 6, Color(0.02, 0.03, 0.08))
	for y in range(10, 39):
		for x in range(10, 39):
			var v := Vector2(float(x - 24), float(y - 24))
			var d := v.length()
			if d < 15.2 and d > 12.4:
				var ang := atan2(v.x, -v.y)
				if ang > -0.55 and ang < 2.35:
					img.set_pixel(x, y, Color(0.42, 0.52, 0.85))


static func _slash(img: Image, color: Color) -> void:
	for i in range(-16, 17):
		_stamp(img, 24 + i, 24 + i, color)
		_stamp(img, 24 + i, 23 + i, color)
		_stamp(img, 23 + i, 24 + i, color)


static func _firebolt(img: Image) -> void:
	for i in 20:
		var t := float(i) / 19.0
		var x := 11 + int(round(t * 22.0))
		var y := 36 - int(round(t * 24.0))
		var r := int(round(lerpf(7.0, 3.0, t)))
		var col := Color(1.0, 0.28, 0.05).lerp(Color(1.0, 0.88, 0.28), t)
		_disc(img, x, y, r, col)
	_disc(img, 33, 13, 6, Color(1.0, 0.95, 0.55))
	_disc(img, 33, 13, 3, Color(1.0, 0.98, 0.85))


static func _ice_blast(img: Image) -> void:
	_poly(img, [Vector2(24, 38), Vector2(8, 12), Vector2(18, 14)], Color(0.45, 0.78, 1.0))
	_poly(img, [Vector2(24, 38), Vector2(18, 10), Vector2(30, 10)], Color(0.78, 0.94, 1.0))
	_poly(img, [Vector2(24, 38), Vector2(30, 14), Vector2(40, 12)], Color(0.4, 0.72, 1.0))
	_disc(img, 24, 36, 4, Color(0.88, 0.97, 1.0))
	_spoke(img, 24, 16, 0.0, 6, Color(0.92, 0.98, 1.0))
	_spoke(img, 24, 16, 60.0, 6, Color(0.92, 0.98, 1.0))
	_spoke(img, 24, 16, 120.0, 6, Color(0.92, 0.98, 1.0))


static func _thunder_wave(img: Image) -> void:
	_bolt(img, Color(0.78, 0.88, 1.0))
	var side: Array[Vector2] = [
		Vector2(36, 14), Vector2(30, 24), Vector2(34, 24), Vector2(26, 38),
		Vector2(38, 26), Vector2(33, 26), Vector2(40, 14)
	]
	_poly(img, side, Color(1.0, 0.94, 0.45))
	_disc(img, 18, 22, 2, Color(1.0, 0.98, 0.7))


static func _meteor(img: Image) -> void:
	for i in 14:
		var t := float(i) / 13.0
		var x := 16 + int(round(t * 10.0))
		var y := 6 + int(round(t * 18.0))
		var r := int(round(lerpf(3.0, 7.0, t)))
		_disc(img, x, y, r, Color(1.0, 0.45, 0.08).lerp(Color(1.0, 0.82, 0.22), t))
	_disc(img, 28, 32, 10, Color(0.55, 0.18, 0.08))
	_disc(img, 28, 32, 7, Color(0.85, 0.32, 0.08))
	_disc(img, 26, 30, 3, Color(1.0, 0.78, 0.28))
	_disc(img, 31, 34, 2, Color(0.28, 0.1, 0.06))


static func _chilled_ground(img: Image) -> void:
	for y in range(28, 42):
		var t := absf(float(y) - 34.0) / 7.0
		var half := int(round(lerpf(16.0, 6.0, t)))
		for x in range(24 - half, 25 + half):
			img.set_pixel(x, y, Color(0.35, 0.72, 1.0) if y == 28 or y == 41 or x == 24 - half or x == 24 + half else Color(0.18, 0.42, 0.72))
	_spoke(img, 24, 20, 0.0, 11, Color(0.82, 0.95, 1.0))
	_spoke(img, 24, 20, 60.0, 11, Color(0.82, 0.95, 1.0))
	_spoke(img, 24, 20, 120.0, 11, Color(0.82, 0.95, 1.0))
	_disc(img, 24, 20, 3, Color.WHITE)


static func _attenuate(img: Image) -> void:
	_disc(img, 16, 30, 8, Color(1.0, 0.42, 0.1))
	_disc(img, 16, 30, 4, Color(1.0, 0.82, 0.28))
	_disc(img, 32, 30, 8, Color(0.4, 0.78, 1.0))
	_disc(img, 32, 30, 4, Color(0.82, 0.95, 1.0))
	_disc(img, 24, 16, 8, Color(0.72, 0.78, 1.0))
	_disc(img, 24, 16, 4, Color(1.0, 0.92, 0.4))


static func _auto_attack(img: Image) -> void:
	_poly(img, [Vector2(10, 24), Vector2(30, 14), Vector2(30, 20), Vector2(40, 24), Vector2(30, 28), Vector2(30, 34)], Color(1.0, 0.86, 0.42))
	_disc(img, 14, 24, 3, Color(1.0, 0.94, 0.7))


static func _atonement(img: Image) -> void:
	_shield(img, Color(0.95, 0.86, 0.42))
	_plus(img, 24, 20, 5, Color(1.0, 0.98, 0.78))


static func _radiant_bolt(img: Image) -> void:
	for i in 18:
		var t := float(i) / 17.0
		var x := 12 + int(round(t * 20.0))
		var y := 36 - int(round(t * 22.0))
		var r := int(round(lerpf(6.0, 3.0, t)))
		_disc(img, x, y, r, Color(1.0, 0.78, 0.22).lerp(Color(1.0, 0.96, 0.7), t))
	_disc(img, 32, 14, 5, Color(1.0, 0.98, 0.82))


static func _judgment(img: Image) -> void:
	for y in range(8, 40):
		var t := absf(float(y) - 22.0) / 16.0
		var half := int(round(lerpf(5.0, 2.0, t)))
		for x in range(24 - half, 25 + half):
			img.set_pixel(x, y, Color(1.0, 0.86, 0.32).lerp(Color(1.0, 0.96, 0.7), 1.0 - t))
	_disc(img, 24, 10, 5, Color(1.0, 0.95, 0.55))
	_disc(img, 24, 10, 2, Color(1.0, 0.98, 0.85))


static func _bastion(img: Image) -> void:
	_shield(img, Color(0.98, 0.9, 0.48))
	_shield(img, Color(0.85, 0.78, 0.38))
	for y in range(10, 20):
		for x in range(18, 31):
			if img.get_pixel(x, y).a > 0.2:
				img.set_pixel(x, y, Color(1.0, 0.96, 0.72))


static func _sanctuary(img: Image) -> void:
	for y in range(26, 42):
		var t := absf(float(y) - 34.0) / 8.0
		var half := int(round(lerpf(16.0, 6.0, t)))
		for x in range(24 - half, 25 + half):
			var edge := y == 26 or y == 41 or x == 24 - half or x == 24 + half
			img.set_pixel(x, y, Color(1.0, 0.86, 0.32) if edge else Color(0.72, 0.52, 0.12))
	_star(img, 24, 18, 10, 4, Color(1.0, 0.92, 0.4))
	_disc(img, 24, 18, 3, Color(1.0, 0.98, 0.78))


static func _plus(img: Image, cx: int, cy: int, arm: int, color: Color) -> void:
	for i in range(-arm, arm + 1):
		_stamp(img, cx + i, cy, color)
		_stamp(img, cx + i, cy - 1, color)
		_stamp(img, cx + i, cy + 1, color)
		_stamp(img, cx, cy + i, color)
		_stamp(img, cx - 1, cy + i, color)
		_stamp(img, cx + 1, cy + i, color)
