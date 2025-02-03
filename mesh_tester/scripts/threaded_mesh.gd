@tool
class_name ThreadedMesh
extends "res://mesh_tester/scripts/planet_mesh.gd"


## Script that demonstrates the generation of a mesh using six threads.


# Overrides the '_create_planet_mesh' function in the 'planet_mesh.gd' script.
func _create_planet_mesh() -> Array:
	# Allocate space for the mesh arrays
	var mesh_array: Array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	var vertices: PackedVector3Array = []
	vertices.resize(resolution * resolution * 6)
	var indices: PackedInt32Array = []
	indices.resize((resolution - 1) * (resolution - 1) * 36)
	var normals: PackedVector3Array = []
	normals.resize(resolution * resolution * 6)
	var uvs: PackedVector2Array = []
	uvs.resize(resolution * resolution * 6)
	var colors: PackedColorArray = []
	colors.resize(resolution * resolution * 6)
	# A lambda function is necessary to access the mesh arrays
	var generate_face := func(face: int) -> void:
		# Directions on the three axes for the current face
		var local_up := DIRECTIONS[face]
		var axis_a := Vector3(local_up.y, local_up.z, local_up.x)
		var axis_b := local_up.cross(axis_a)
		var triangle_index := (resolution - 1) * (resolution - 1) * 6 * face
		# Generate the vertices of the current face
		for y in resolution:
			for x in resolution:
				# Generate the vertex position
				var vertex_index: int = resolution * resolution * face + x + y * resolution
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
				# Generate indices
				if x != resolution - 1 and y != resolution - 1:
					indices[triangle_index] = vertex_index
					indices[triangle_index + 1] = vertex_index + resolution + 1
					indices[triangle_index + 2] = vertex_index + resolution
					indices[triangle_index + 3] = vertex_index
					indices[triangle_index + 4] = vertex_index + 1
					indices[triangle_index + 5] = vertex_index + resolution + 1
					triangle_index += 6
	# Create the mesh using a thread pool and wait for its completion
	var task_id := WorkerThreadPool.add_group_task(generate_face, DIRECTIONS.size())
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	# Commit the result
	mesh_array[Mesh.ARRAY_VERTEX] = vertices
	mesh_array[Mesh.ARRAY_INDEX] = indices
	mesh_array[Mesh.ARRAY_NORMAL] = normals
	mesh_array[Mesh.ARRAY_TEX_UV] = uvs
	mesh_array[Mesh.ARRAY_COLOR] = colors
	# Generating normals using the SurfaceTool requires all vertices to be generated
	if generate_normals:
		var surface_tool := SurfaceTool.new()
		surface_tool.create_from_arrays(mesh_array)
		surface_tool.generate_normals()
		mesh_array = surface_tool.commit_to_arrays()
	return mesh_array
