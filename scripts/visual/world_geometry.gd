class_name WorldGeometry
extends RefCounted


## Builds a flat XZ annulus once for long-lived world-space indicators.
static func annulus_mesh(inner_radius: float, outer_radius: float, y: float, steps: int = 48) -> ArrayMesh:
	var inner := maxf(inner_radius, 0.2)
	var outer := maxf(outer_radius, inner + 0.15)
	var segment_count := maxi(steps, 3)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segment_count:
		var a0 := TAU * float(i) / float(segment_count)
		var a1 := TAU * float(i + 1) / float(segment_count)
		var inner_0 := Vector3(cos(a0) * inner, y, sin(a0) * inner)
		var inner_1 := Vector3(cos(a1) * inner, y, sin(a1) * inner)
		var outer_0 := Vector3(cos(a0) * outer, y, sin(a0) * outer)
		var outer_1 := Vector3(cos(a1) * outer, y, sin(a1) * outer)
		surface.add_vertex(inner_0)
		surface.add_vertex(outer_0)
		surface.add_vertex(outer_1)
		surface.add_vertex(inner_0)
		surface.add_vertex(outer_1)
		surface.add_vertex(inner_1)
	return surface.commit()
