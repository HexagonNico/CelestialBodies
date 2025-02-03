@tool
class_name ComputeShaderMesh
extends "res://scripts/planet_mesh.gd"


func _create_planet_mesh() -> Array:
	# Create a local rendering device
	var rendering_device := RenderingServer.create_local_rendering_device()
	# Load the shader shader
	var shader_file := load("res://shaders/compute_shader.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rendering_device.shader_create_from_spirv(shader_spirv)
	# Create two shader storage storage buffers
	var vertex_buffer := rendering_device.storage_buffer_create(resolution * resolution * 6 * 4 * 4)
	var index_buffer := rendering_device.storage_buffer_create((resolution - 1) * (resolution - 1) * 36 * 4)
	# Create a uniform to assign the buffer to the rendering device
	var vertex_uniform := RDUniform.new()
	vertex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vertex_uniform.binding = 0
	vertex_uniform.add_id(vertex_buffer)
	var index_uniform := RDUniform.new()
	index_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	index_uniform.binding = 1
	index_uniform.add_id(index_buffer)
	var uniform_set := rendering_device.uniform_set_create([vertex_uniform, index_uniform], shader, 0)
	# Create a compute pipeline
	var pipeline := rendering_device.compute_pipeline_create(shader)
	var compute_list := rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rendering_device.compute_list_dispatch(compute_list, resolution, resolution, 1)
	rendering_device.compute_list_end()
	# Submit to GPU and wait for sync
	rendering_device.submit()
	rendering_device.sync()
	# Read back the data from the buffer
	var output_vertices := rendering_device.buffer_get_data(vertex_buffer).to_float32_array()
	var vertices: PackedVector3Array = []
	vertices.resize(resolution * resolution * 6)
	for i in vertices.size():
		vertices[i] = Vector3(output_vertices[i * 4], output_vertices[i * 4 + 1], output_vertices[i * 4 + 2])
	var indices := rendering_device.buffer_get_data(index_buffer).to_int32_array()
	var mesh_array: Array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	mesh_array[Mesh.ARRAY_VERTEX] = vertices
	mesh_array[Mesh.ARRAY_INDEX] = indices
	return mesh_array
