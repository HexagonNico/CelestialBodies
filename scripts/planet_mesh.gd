@tool
extends PrimitiveMesh


const DIRECTIONS: PackedVector3Array = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]


@export_range(2, 4096) var resolution: int = 10: set = set_resolution
@export_range(0.001, 100.0, 0.001, "suffix:m") var radius: float = 1.0: set = set_radius

@export var continent_noise: Noise = null: set = set_continent_noise
@export var rigdes_noise: Noise = null: set = set_rigdes_noise

@export var planet_colors: Gradient = null: set = set_planet_colors

@export var generate_normals: bool = false: set = set_generate_normals

var _generation_time: int = 0


func _create_planet_mesh() -> Array:
	return []


func _create_mesh_array() -> Array:
	var time := Time.get_ticks_msec()
	var planet_mesh := _create_planet_mesh()
	_generation_time = Time.get_ticks_msec() - time
	print(
		(get_script() as Script).get_global_name(),
		" - Resolution: ", resolution,
		" - Use noise: ", is_instance_valid(continent_noise),
		" - Use colors: ", is_instance_valid(planet_colors),
		" - Generate normals: ", generate_normals,
		" - Time: ", _generation_time, "ms"
	)
	return planet_mesh


# Setter function for 'resolution'.
func set_resolution(value: int) -> void:
	value = clampi(value, 2, 4096)
	if resolution != value:
		resolution = value
		request_update()
		emit_changed()


# Setter function for 'radius'.
func set_radius(value: float) -> void:
	value = maxf(value, 0.0)
	if radius != value:
		radius = value
		request_update()
		emit_changed()


# Setter function for 'continent_noise'.
func set_continent_noise(value: Noise) -> void:
	if continent_noise != value:
		if is_instance_valid(continent_noise):
			continent_noise.changed.disconnect(request_update)
			continent_noise.changed.disconnect(emit_changed)
		continent_noise = value
		if is_instance_valid(continent_noise):
			continent_noise.changed.connect(request_update)
			continent_noise.changed.connect(emit_changed)
		request_update()
		emit_changed()


# Setter function for 'rigdes_noise'.
func set_rigdes_noise(value: Noise) -> void:
	if rigdes_noise != value:
		if is_instance_valid(rigdes_noise):
			rigdes_noise.changed.disconnect(request_update)
			rigdes_noise.changed.disconnect(emit_changed)
		rigdes_noise = value
		if is_instance_valid(rigdes_noise):
			rigdes_noise.changed.connect(request_update)
			rigdes_noise.changed.connect(emit_changed)
		request_update()
		emit_changed()


# Setter function for 'planet_colors'.
func set_planet_colors(value: Gradient) -> void:
	if planet_colors != value:
		if is_instance_valid(planet_colors):
			planet_colors.changed.disconnect(request_update)
			planet_colors.changed.disconnect(emit_changed)
		planet_colors = value
		if is_instance_valid(planet_colors):
			planet_colors.changed.connect(request_update)
			planet_colors.changed.connect(emit_changed)
		request_update()
		emit_changed()


# Setter function for 'generate_normals'.
func set_generate_normals(value: bool) -> void:
	if generate_normals != value:
		generate_normals = value
		request_update()
		emit_changed()


func _validate_property(property: Dictionary) -> void:
	match property.get("name"):
		"_generation_time":
			property["usage"] = PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR
			property["hint_string"] = "suffix:ms"
