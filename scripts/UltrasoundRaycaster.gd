extends Node3D

class_name UltrasoundRaycaster

const DEPTH_SAMPLES: int = 400

var space_state: PhysicsDirectSpaceState3D = null
var active: bool = false
var raw_data: PackedFloat32Array = []
var num_rays: int = 96
var max_depth: float = 0.25
var freeze: bool = false
var frozen_data: PackedFloat32Array = []

func _ready():
	raw_data.resize(num_rays * DEPTH_SAMPLES)
	raw_data.fill(0.0)

func set_active(a: bool):
	active = a
	set_process(a)

func configure(res: TransducerResource):
	num_rays = res.num_rays
	max_depth = res.max_depth
	raw_data.resize(num_rays * DEPTH_SAMPLES)
	raw_data.fill(0.0)
	frozen_data.resize(0)

func _process(_delta):
	if not active or space_state == null or freeze:
		return
	var res = TransducerController.current_transducer_resource
	if res == null:
		return
	raw_data = scan(res)

func scan(res: TransducerResource) -> PackedFloat32Array:
	var data = PackedFloat32Array()
	data.resize(num_rays * DEPTH_SAMPLES)
	data.fill(0.0)

	var origins: Array[Vector3] = []
	var directions: Array[Vector3] = []

	match res.transducer_type:
		TransducerResource.TransducerType.LINEAL:
			compute_linear_rays(origins, directions, res)
		TransducerResource.TransducerType.CONVEXO:
			compute_convex_rays(origins, directions, res)
		TransducerResource.TransducerType.SECTORIAL:
			compute_sectorial_rays(origins, directions, res)

	for i in num_rays:
		if i >= origins.size():
			continue
		var local_dir = directions[i]
		var local_origin = origins[i]
		var global_origin = global_transform * local_origin
		var global_dir = (global_transform.basis * local_dir).normalized()
		process_ray(data, i, global_origin, global_dir)

	return data

func compute_linear_rays(origins: Array[Vector3], directions: Array[Vector3], res: TransducerResource):
	var half_w = res.face_width * 0.5
	for i in num_rays:
		var t = float(i) / float(num_rays - 1) if num_rays > 1 else 0.5
		origins.append(Vector3(lerp(-half_w, half_w, t), 0.0, 0.0))
		directions.append(Vector3(0.0, 0.0, 1.0))

func compute_convex_rays(origins: Array[Vector3], directions: Array[Vector3], res: TransducerResource):
	var half_angle = deg_to_rad(res.field_angle) * 0.5
	for i in num_rays:
		var t = float(i) / float(num_rays - 1) if num_rays > 1 else 0.5
		var angle = lerp(-half_angle, half_angle, t)
		var dir = Vector3(sin(angle), 0.0, cos(angle))
		origins.append(dir * res.arc_radius)
		directions.append(dir)

func compute_sectorial_rays(origins: Array[Vector3], directions: Array[Vector3], res: TransducerResource):
	var half_angle = deg_to_rad(res.field_angle) * 0.5
	var half_w = res.face_width * 0.5
	for i in num_rays:
		var t = float(i) / float(num_rays - 1) if num_rays > 1 else 0.5
		var angle = lerp(-half_angle, half_angle, t)
		origins.append(Vector3(lerp(-half_w, half_w, t), 0.0, 0.0))
		directions.append(Vector3(sin(angle), 0.0, cos(angle)))

func process_ray(data: PackedFloat32Array, ray_idx: int, origin: Vector3, dir: Vector3):
	var query = PhysicsRayQueryParameters3D.create(origin, origin + dir * max_depth)
	query.collision_mask = 1
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)

	var hit_depth = -1.0
	var profile: Array[AcousticProperties] = []
	var region: PhantomRegion = null

	if result and result.has("collider") and result.collider is PhantomRegion:
		region = result.collider as PhantomRegion
		hit_depth = origin.distance_to(result.position)
		profile = region.get_random_tissue_profile()

	if profile.is_empty() and result and result.has("collider"):
		hit_depth = origin.distance_to(result.position)

	var step_size = max_depth / float(DEPTH_SAMPLES)
	var shadow_accum = 0.0
	var shadow_fade = 0.0
	var shadow_active = false
	var last_boundary = 0.0

	for s in DEPTH_SAMPLES:
		var depth = s * step_size + step_size * 0.5
		var val = 0.0
		var noise = randf_range(-0.015, 0.015)

		if hit_depth >= 0.0 and profile.size() > 0:
			var total_layers = profile.size()
			var layer_fraction = depth / max_depth
			var layer_idx = min(int(layer_fraction * total_layers), total_layers - 1)
			var tissue = profile[layer_idx]

			val = tissue.echogenicity * 0.4

			var boundary_depth = (layer_idx + 1) * max_depth / float(total_layers)
			var dist_to_boundary = abs(depth - boundary_depth)
			if dist_to_boundary < step_size * 5 and layer_idx < total_layers - 1:
				var prev = profile[layer_idx]
				var ech_diff = abs(tissue.echogenicity - prev.echogenicity)
				val += ech_diff * 0.7 * max(0.0, 1.0 - dist_to_boundary / (step_size * 5))

			var dist_to_surface = abs(depth - hit_depth)
			if dist_to_surface < step_size * 4:
				val = 0.85 * max(0.0, 1.0 - dist_to_surface / (step_size * 4))

			if tissue.causes_shadow and tissue.shadow_strength > shadow_accum:
				shadow_accum = tissue.shadow_strength
				shadow_fade = 0.0
			if tissue.is_hollow and tissue.posterior_enhancement > 0.0:
				shadow_accum = -tissue.posterior_enhancement
				shadow_fade = 0.0

			if shadow_accum > 0.0:
				var fade = clamp(depth / (max_depth * 0.5), 0.0, 1.0)
				val *= (1.0 - shadow_accum * fade)
			elif shadow_accum < 0.0:
				val *= (1.0 + abs(shadow_accum) * 0.5)

		elif hit_depth >= 0.0:
			if depth < hit_depth:
				val = 0.02
			else:
				val = 0.4 * max(0.0, 1.0 - (depth - hit_depth) / max_depth) + randf_range(-0.05, 0.05)
				shadow_accum = 0.6
				if shadow_accum > 0.0:
					val *= (1.0 - shadow_accum * 0.3)
		else:
			val = randf_range(-0.01, 0.01)

		val += noise
		data[ray_idx * DEPTH_SAMPLES + s] = clamp(val, 0.0, 1.0)

func toggle_freeze():
	freeze = not freeze
	if freeze:
		frozen_data = raw_data.duplicate()
	elif frozen_data.size() > 0:
		frozen_data.resize(0)

func get_display_data() -> PackedFloat32Array:
	if freeze and frozen_data.size() > 0:
		return frozen_data
	return raw_data
