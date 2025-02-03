@tool
class_name PlanetGenerator
extends MeshInstance3D


## Node that generates a planet mesh.
##
## PlanetGenerator generates an [ArrayMesh] of a planet.
## The mesh is regenrated every time a property is changed,
## then it is saved in the scene file and reloaded from there the next time the scene is instantiated.
## [br][br]
## This class uses a [WorkerThreadPool] and does not halt the execution while the mesh is being regenerated.


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
## [b]Note:[/b] For colors to be visible, a material must be assigned to [member GeometryInstance3D.material_override] and [member BaseMaterial3D.vertex_color_use_as_albedo] must be enabled.
@export var planet_colors: Gradient = null: set = set_planet_colors

## If [code]true[/code], the mesh will generate normals based on the surface of the planet.
## If [code]false[/code], the resulting normals will point straight up as if the planet was a smooth sphere.
@export var generate_normals: bool = false: set = set_generate_normals

# Private variable used to display the generation time in the editor.
var _generation_time: float = 0

# Mutex needed to prevent concurrent access to the mesh from the generation threads.
var _mutex := Mutex.new()
# Id of the thread group task. Must be kept here for the thread group to be waited for.
var _group_task: int = -1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Don't generate a new mesh if one was loaded from the scene file
	if not is_instance_valid(mesh):
		# Generate a new mesh
		mesh = ArrayMesh.new()
		_generate_mesh()


# Private function used to generate the face at the given index.
func _generate_face(face_index: int) -> void:
	var time := Time.get_ticks_msec()
	# Allocate space for the mesh arrays
	var vertices: PackedVector3Array = []
	vertices.resize(resolution * resolution)
	var indices: PackedInt32Array = []
	indices.resize((resolution - 1) * (resolution - 1) * 6)
	var normals: PackedVector3Array = []
	normals.resize(resolution * resolution)
	var uvs: PackedVector2Array = []
	uvs.resize(resolution * resolution)
	var colors: PackedColorArray = []
	colors.resize(resolution * resolution)
	# Directions on the three axes for the current face
	var local_up := DIRECTIONS[face_index]
	var axis_a := Vector3(local_up.y, local_up.z, local_up.x)
	var axis_b := local_up.cross(axis_a)
	var triangle_index: int = 0
	# Generate the vertices of the current face
	for y in resolution:
		for x in resolution:
			# Generate the vertex position
			var vertex_index := x + y * resolution
			uvs[vertex_index] = Vector2(x, y) / (resolution - 1)
			normals[vertex_index] = (local_up + (uvs[vertex_index].x - 0.5) * 2.0 * axis_b + (uvs[vertex_index].y - 0.5) * 2.0 * axis_a).normalized()
			vertices[vertex_index] = normals[vertex_index] * radius
			# Add noise to the vertex position
			if is_instance_valid(continent_noise):
				var noise_mask := continent_noise.get_noise_3dv(vertices[vertex_index])
				var planet_noise := noise_mask
				if is_instance_valid(rigdes_noise):
					planet_noise += rigdes_noise.get_noise_3dv(vertices[vertex_index]) * noise_mask
					vertices[vertex_index] += normals[vertex_index] * planet_noise
				# Add vertex colors based on the height of the planet
				if is_instance_valid(planet_colors):
					colors[vertex_index] = planet_colors.sample(planet_noise)
				else:
					colors[vertex_index] = Color.WHITE
			# Generate indices
			if x != resolution - 1 and y != resolution - 1:
				indices[triangle_index] = vertex_index
				indices[triangle_index + 1] = vertex_index + resolution + 1
				indices[triangle_index + 2] = vertex_index + resolution
				indices[triangle_index + 3] = vertex_index
				indices[triangle_index + 4] = vertex_index + 1
				indices[triangle_index + 5] = vertex_index + resolution + 1
				triangle_index += 6
	# Commit the result to mesh arrays
	var mesh_array: Array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	mesh_array[Mesh.ARRAY_VERTEX] = vertices
	mesh_array[Mesh.ARRAY_INDEX] = indices
	mesh_array[Mesh.ARRAY_NORMAL] = normals
	mesh_array[Mesh.ARRAY_TEX_UV] = uvs
	mesh_array[Mesh.ARRAY_COLOR] = colors
	# Generate normals using the SurfaceTool
	if generate_normals:
		var surface_tool := SurfaceTool.new()
		surface_tool.create_from_arrays(mesh_array)
		surface_tool.generate_normals()
		mesh_array = surface_tool.commit_to_arrays()
	# Lock the thread to prevent concurrent access to the mesh or the time tracker
	_mutex.lock()
	# Add this face as a surface to the ArrayMesh
	if mesh is ArrayMesh:
		(mesh as ArrayMesh).add_surface_from_arrays.call_deferred(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
	# The generation time of the mesh is the generation time of the slowest face
	_generation_time = maxf(_generation_time, Time.get_ticks_msec() - time)
	# Unlock the mutex to resume other threads
	_mutex.unlock()


# Private function to be called when a property is modified to regenerate the mesh.
func _generate_mesh() -> void:
	# Avoid regenerating the mesh when the scene is loaded
	if is_node_ready():
		# Wait for the previous generation to finish
		if _group_task >= 0:
			WorkerThreadPool.wait_for_group_task_completion(_group_task)
		# Reset generation Time
		_generation_time = 0.0
		# Clear the mesh surfaces for them to be readded after they are generated
		if mesh is ArrayMesh:
			(mesh as ArrayMesh).clear_surfaces()
		# Create the mesh using a thread pool
		_group_task = WorkerThreadPool.add_group_task(_generate_face, DIRECTIONS.size())


# Called when the node exits the scene tree.
func _exit_tree() -> void:
	# Wait for the generation to finish if it is still in progress
	if _group_task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_group_task)


# Customizes existing properties.
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
		_generate_mesh()


# Setter function for 'radius'.
func set_radius(value: float) -> void:
	value = maxf(value, 0.0)
	if radius != value:
		radius = value
		_generate_mesh()


# Setter function for 'continent_noise'.
func set_continent_noise(value: Noise) -> void:
	if continent_noise != value:
		if is_instance_valid(continent_noise) and continent_noise.changed.is_connected(_generate_mesh):
			continent_noise.changed.disconnect(_generate_mesh)
		continent_noise = value
		if is_instance_valid(continent_noise):
			continent_noise.changed.connect(_generate_mesh)
		_generate_mesh()


# Setter function for 'rigdes_noise'.
func set_rigdes_noise(value: Noise) -> void:
	if rigdes_noise != value:
		if is_instance_valid(rigdes_noise) and rigdes_noise.changed.is_connected(_generate_mesh):
			rigdes_noise.changed.disconnect(_generate_mesh)
		rigdes_noise = value
		if is_instance_valid(rigdes_noise):
			rigdes_noise.changed.connect(_generate_mesh)
		_generate_mesh()


# Setter function for 'planet_colors'.
func set_planet_colors(value: Gradient) -> void:
	if planet_colors != value:
		if is_instance_valid(planet_colors) and planet_colors.changed.is_connected(_generate_mesh):
			planet_colors.changed.disconnect(_generate_mesh)
		planet_colors = value
		if is_instance_valid(planet_colors):
			planet_colors.changed.connect(_generate_mesh)
		_generate_mesh()


# Setter function for 'generate_normals'.
func set_generate_normals(value: bool) -> void:
	if generate_normals != value:
		generate_normals = value
		_generate_mesh()
