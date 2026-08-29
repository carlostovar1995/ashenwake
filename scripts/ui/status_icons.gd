class_name StatusIcons
extends Object

const ICON_DIR := "res://assets/ui/icons/"
const _ALIASES := {
	"overcharged": "overcharge",
	"overheat": "overcharge",
}

static var _cache: Dictionary = {}


static func texture_for(icon_id: String) -> Texture2D:
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
	if icon_id.is_empty() or infusion_tag.is_empty():
		return texture_for(icon_id)
	var variant_id := "%s_infused_%s" % [icon_id, infusion_tag]
	var variant_path := ICON_DIR + variant_id + ".png"
	if ResourceLoader.exists(variant_path):
		return texture_for(variant_id)
	return texture_for(icon_id)


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
		"storm_infused", "charged":
			_fill_round(img, Color(0.12, 0.1, 0.02, 1.0) if icon_id == "charged" else Color(0.08, 0.1, 0.28, 1.0))
			_bolt(img, Color(1.0, 0.92, 0.35) if icon_id == "charged" else Color(0.7, 0.82, 1.0))
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
