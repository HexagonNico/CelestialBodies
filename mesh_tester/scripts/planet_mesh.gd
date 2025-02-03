@tool
extends PrimitiveMesh


## Base class used to demonstrate different mesh generators.


## Constant array of directions used to generate the six faces of the cube-sphere.
const DIRECTIONS: PackedVector3Array = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]


## The resolution of the mesh. Determines how many vertices each face of the cube-sphere will have.
@export_range(2, 4096) var resolution: int = 10: set = set_resolution
## The radius of the planet.
@export_range(0.001, 100.0, 0.001, "suffix:m", "or_greater") var radius: float = 1.0: set = set_radius

## Instance of the [Noise] object used to generate continents on the surface of the planet.
## Acts as a mask for the [member rigdes_noise] layer.
@export var continent_noise: Noise = null: set = set_continent_noise
## Instance of the [Noise] object used to generate mountain ranges and finer details on the planet.
## Should use the [constant FastNoiseLite.FRACTAL_RIDGED] fractal type for better results.
@export var rigdes_noise: Noise = null: set = set_rigdes_noise

## A [Gradient] used to sample vertex colors based on the planet's height.
## [member continent_noise] must be assigned for this to take effect.
## [br][br]
## [b]Note:[/b] For colors to be visible, a material must be assigned to the mesh and [member BaseMaterial3D.vertex_color_use_as_albedo] must be enabled.
@export var planet_colors: Gradient = null: set = set_planet_colors

## If [code]true[/code], the mesh will generate normals based on the surface of the planet.
## If [code]false[/code], the resulting normals will point straight up as if the planet was a smooth sphere.
@export var generate_normals: bool = false: set = set_generate_normals

# Private variable used to display the generation time in the editor.
var _generation_time: float = 0


# Function to be implemented by child classes to generate the planet mesh.
func _create_planet_mesh() -> Array:
	return []


# Overrides the '_create_mesh_array' virtual function in PrimitiveMesh.
func _create_mesh_array() -> Array:
	var time := Time.get_ticks_msec()
	var planet_mesh := _create_planet_mesh()
	_generation_time = Time.get_ticks_msec() - time
	return planet_mesh


# Customizes existing exported properties.
func _validate_property(property: Dictionary) -> void:
	match property.get("name"):
		# Show the generation time in the editor
		"_generation_time":
			property["usage"] = PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR
			property["hint_string"] = "suffix:ms"


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
