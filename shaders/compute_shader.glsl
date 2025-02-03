#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 6, local_size_y = 1, local_size_z = 1) in;

// Constant directions
const vec3 directions[6] = vec3[] (vec3(0, 1, 0), vec3(0, -1, 0), vec3(-1, 0, 0), vec3(1, 0, 0), vec3(0, 0, 1), vec3(0, 0, -1));

layout(set = 0, binding = 0, std430) restrict buffer VerticesBuffer {
	vec4 vertices[];
};

layout(set = 0, binding = 1, std430) restrict buffer IndexBuffer {
	uint indices[];
};

void main() {
	const uint resolution = 256;
	const float radius = 10.0;
	vec3 local_up = directions[gl_LocalInvocationID.x];
	vec3 axis_a = vec3(local_up.y, local_up.z, local_up.x);
	vec3 axis_b = cross(local_up, axis_a);
	uint vertex_index = gl_NumWorkGroups.x * gl_NumWorkGroups.y * gl_LocalInvocationID.x + gl_WorkGroupID.x + gl_WorkGroupID.y * gl_NumWorkGroups.x;
	vec2 uv = gl_WorkGroupID.xy / float(resolution - 1);
	vec3 normal = normalize(local_up + (uv.x - 0.5) * 2.0 * axis_b + (uv.y - 0.5) * 2.0 * axis_a);
	vertices[vertex_index] = vec4(normal * radius, 0.0);
	uint triangle_index = vertex_index * 6;
	indices[triangle_index] = vertex_index;
	indices[triangle_index + 1] = vertex_index + resolution + 1;
	indices[triangle_index + 2] = vertex_index + resolution;
	indices[triangle_index + 3] = vertex_index;
	indices[triangle_index + 4] = vertex_index + 1;
	indices[triangle_index + 5] = vertex_index + resolution + 1;
}
