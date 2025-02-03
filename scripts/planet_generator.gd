@tool
class_name PlanetGenerator
extends MeshInstance3D


const DIRECTIONS: PackedVector3Array = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]


@export_range(2, 4096) var resolution: int = 10: set = set_resolution
@export_range(0.001, 100.0, 0.001, "suffix:m") var radius: float = 1.0: set = set_radius

@export var continent_noise: Noise = null: set = set_continent_noise
@export var rigdes_noise: Noise = null: set = set_rigdes_noise

@export var planet_colors: Gradient = null: set = set_planet_colors

@export var generate_normals: bool = false: set = set_generate_normals

var _faces_count: int = 0
var _generation_time: float = 0

var _mutex := Mutex.new()
var _group_task: int = -1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not is_instance_valid(mesh):
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
			var vertex_index := x + y * resolution
			uvs[vertex_index] = Vector2(x, y) / (resolution - 1)
			normals[vertex_index] = (local_up + (uvs[vertex_index].x - 0.5) * 2.0 * axis_b + (uvs[vertex_index].y - 0.5) * 2.0 * axis_a).normalized()
			vertices[vertex_index] = normals[vertex_index] * radius
			if is_instance_valid(continent_noise):
				var mask := continent_noise.get_noise_3dv(vertices[vertex_index])
				var noise := mask
				if is_instance_valid(rigdes_noise):
					noise += rigdes_noise.get_noise_3dv(vertices[vertex_index]) * mask
					vertices[vertex_index] += normals[vertex_index] * noise
				if is_instance_valid(planet_colors):
					colors[vertex_index] = planet_colors.sample(noise)
				else:
					colors[vertex_index] = Color.WHITE
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
	_mutex.lock()
	if mesh is ArrayMesh:
		(mesh as ArrayMesh).add_surface_from_arrays.call_deferred(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
	_generation_time += Time.get_ticks_msec() - time
	_faces_count += 1
	if _faces_count == 6:
		_generation_time /= 6.0
	_mutex.unlock()


func _generate_mesh() -> void:
	# Avoid regenerating the mesh when the scene is loaded
	if is_node_ready():
		# Wait for the previous generation to finish
		if _group_task >= 0:
			WorkerThreadPool.wait_for_group_task_completion(_group_task)
		# Reset generation statistics
		_generation_time = 0.0
		_faces_count = 0
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
