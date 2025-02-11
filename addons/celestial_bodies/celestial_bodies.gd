@tool
extends EditorPlugin


# Name of the gravitational constant setting in the ProjectSettings.
const GRAVITATIONAL_CONSTANT := "physics/3d/celestial_bodies/gravitational_constant"
# Name of the points in debug orbit setting in the ProjectSettings.
const ORBIT_POINTS := "debug/shapes/celestial_bodies/points_in_orbit"


# Instance RIDs of debug orbits.
var _orbit_instances: Array[RID] = []
# Mesh RIDs of debug orbits.
var _orbit_meshes: Array[RID] = []
# Materials used by the meshes of debug orbits.
var _orbit_materials: Array[StandardMaterial3D] = []

# Current number of points in each orbit as it is stored in the project settings.
var _current_orbit_size: int = 1000


# Initialization of the plugin.
func _enter_tree() -> void:
	_add_project_settings(GRAVITATIONAL_CONSTANT, 0.01)
	_add_project_settings(ORBIT_POINTS, 1000, PROPERTY_HINT_RANGE, "2,3000,or_greater,hide_slider")
	ProjectSettings.settings_changed.connect(_on_project_settings_settings_changed)
	ProjectSettings.save()
	_current_orbit_size = maxi(2, ProjectSettings.get_setting(ORBIT_POINTS, 1000))


# Private function used to add a value to the project settings.
func _add_project_settings(setting: String, default_value: Variant, hint := PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set(setting, default_value)
	ProjectSettings.set_initial_value(setting, default_value)
	ProjectSettings.set_as_basic(setting, true)
	ProjectSettings.add_property_info({"name": setting, "type": typeof(default_value), "hint": hint, "hint_string": hint_string})


# Called by the 'settings_changed' signal emitted from the ProjectSettings class.
func _on_project_settings_settings_changed() -> void:
	# Get the new number of points from the project settings
	var orbit_size := maxi(2, ProjectSettings.get_setting(ORBIT_POINTS, 1000))
	if _current_orbit_size != orbit_size:
		# Update the orbits with the new number of points if it has changed
		for i in _orbit_meshes.size():
			var points: PackedVector3Array = []
			points.resize(orbit_size)
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			RenderingServer.mesh_clear(_orbit_meshes[i])
			RenderingServer.mesh_add_surface_from_arrays(_orbit_meshes[i], RenderingServer.PRIMITIVE_LINE_STRIP, arrays)
			RenderingServer.mesh_surface_set_material(_orbit_meshes[i], 0, _orbit_materials[i].get_rid())
		_current_orbit_size = orbit_size


# Called every physics step.
func _physics_process(delta: float) -> void:
	# Get celestial bodies in the currently edited scene
	var nodes := get_tree().get_nodes_in_group(CelestialBody3D.GROUP_NAME)
	# Create new orbits if there are more celestial bodies
	if nodes.size() > _orbit_instances.size():
		var size := _orbit_instances.size()
		_orbit_instances.resize(nodes.size())
		_orbit_meshes.resize(nodes.size())
		_orbit_materials.resize(nodes.size())
		for i in range(size, nodes.size()):
			# Create an instance, a mesh, and a material for every orbit
			_orbit_instances[i] = RenderingServer.instance_create()
			_orbit_meshes[i] = RenderingServer.mesh_create()
			_orbit_materials[i] = StandardMaterial3D.new()
			# Apply mesh to instance
			RenderingServer.instance_set_scenario(_orbit_instances[i], (nodes[i] as Node3D).get_world_3d().scenario)
			RenderingServer.instance_set_base(_orbit_instances[i], _orbit_meshes[i])
			# Allocate space for the orbit mesh
			var points: PackedVector3Array = []
			points.resize(_current_orbit_size)
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			RenderingServer.mesh_add_surface_from_arrays(_orbit_meshes[i], RenderingServer.PRIMITIVE_LINE_STRIP, arrays)
			# Add material to the orbit mesh
			_orbit_materials[i].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			RenderingServer.mesh_surface_set_material(_orbit_meshes[i], 0, _orbit_materials[i].get_rid())
	# Delete old orbits if there are less celestial bodies
	elif nodes.size() < _orbit_instances.size():
		# Delete remaining orbits
		for i in range(nodes.size(), _orbit_instances.size()):
			RenderingServer.free_rid(_orbit_instances[i])
			RenderingServer.free_rid(_orbit_meshes[i])
		# Resize arrays
		_orbit_instances.resize(nodes.size())
		_orbit_meshes.resize(nodes.size())
		_orbit_materials.resize(nodes.size())
	# All celestial bodies must be moved together to predict their orbit
	var positions: PackedVector3Array = []
	positions.resize(nodes.size())
	var velocities: PackedVector3Array = []
	velocities.resize(nodes.size())
	var points: Array[PackedVector3Array] = []
	points.resize(nodes.size())
	# Initialize position and velocity of all celestial bodies
	for i in nodes.size():
		var celestial_body := nodes[i] as CelestialBody3D
		positions[i] = celestial_body.global_position
		velocities[i] = celestial_body.linear_velocity
		points[i].resize(_current_orbit_size)
		# The orbit has the same transform and visibility as the celestial body
		RenderingServer.instance_set_visible(_orbit_instances[i], celestial_body.visible)
		RenderingServer.instance_set_transform(_orbit_instances[i], celestial_body.global_transform)
		# Set debug orbit color
		_orbit_materials[i].albedo_color = celestial_body.debug_orbit_color
	# Only draw the orbits if there is at least one celestial body in the scene
	if not nodes.is_empty():
		var gravitational_constant: float = ProjectSettings.get_setting(GRAVITATIONAL_CONSTANT, 0.01)
		# Predict the orbit for a number of steps
		for iteration in _current_orbit_size:
			for i1 in nodes.size():
				var body_1: CelestialBody3D = nodes[i1]
				for i2 in nodes.size():
					# Skip if body 1 and body 2 are the same body
					if i1 != i2:
						# Compute the acceleration on body 1 caused by body 2
						var body_2: CelestialBody3D = nodes[i2]
						var squared_distance := positions[i1].distance_squared_to(positions[i2])
						var direction := positions[i1].direction_to(positions[i2])
						var acceleration := direction * gravitational_constant * body_2.mass / squared_distance
						velocities[i1] += acceleration * delta
				# Move the position of body 1 and register the current position for the orbit
				positions[i1] += velocities[i1] * delta
				points[i1][iteration] = body_1.to_local(positions[i1])
	# Update the orbits with the computed points
	for i in nodes.size():
		RenderingServer.mesh_surface_update_vertex_region(_orbit_meshes[i], 0, 0, points[i].to_byte_array())


# Called by the engine when the user disables the plugin in the project settings.
func _disable_plugin() -> void:
	ProjectSettings.clear(GRAVITATIONAL_CONSTANT)
	ProjectSettings.clear(ORBIT_POINTS)
	ProjectSettings.save()


# Clean-up of the plugin.
func _exit_tree() -> void:
	for rid in _orbit_instances:
		RenderingServer.free_rid(rid)
	for rid in _orbit_meshes:
		RenderingServer.free_rid(rid)
