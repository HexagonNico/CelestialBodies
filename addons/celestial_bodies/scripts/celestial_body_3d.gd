@tool
@icon("res://addons/celestial_bodies/icons/celestial_body_3d.svg")
class_name CelestialBody3D
extends RigidBody3D


## A 3D celestial body.
##
## Celestial bodies react to the gravitational forces of other celestial bodies in the scene.
## The script will calculate the body's [member RigidBody3D.constant_force] at every physics step.
## [br][br]
## The orbit of a celestial body can be adjusted by changing its [member RigidBody3D.linear_velocity] or the [member RigidBody3D.mass] of the body it orbits around.
## [br][br]
## The universal gravitational constant can be changed from the [ProjectSettings] at [member ProjectSettings.physics/3d/celestial_bodies/gravitational_constant].
## [br][br]
## Celestial bodies show a prediction of their orbit while in the editor.
## The number of points in the orbit can be changed from the [ProjectSettings] at [member ProjectSettings.debug/shapes/celestial_bodies/points_in_orbit].


## Name of the group used internally to get all celestial bodies in the scene.
const GROUP_NAME := &"__celestial_body__"


## The debug color of the orbit.
@export_color_no_alpha var debug_orbit_color := Color.WHITE


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(GROUP_NAME)


# Called every physics step.
func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		# Compute the total force resulting from the other celestial bodies in the scene
		var celestial_bodies := get_tree().get_nodes_in_group(GROUP_NAME)
		var gravitational_constant: float = ProjectSettings.get_setting("physics/3d/celestial_bodies/gravitational_constant", 0.01)
		var total_force := Vector3.ZERO
		for node in celestial_bodies:
			# Skip this celestial body
			if node != self and node is CelestialBody3D:
				var celestial_body := node as CelestialBody3D
				# Compute force due to this other body
				var squared_distance := global_position.distance_squared_to(celestial_body.global_position)
				var direction := global_position.direction_to(celestial_body.global_position)
				total_force += direction * gravitational_constant * mass * celestial_body.mass / squared_distance
		# Apply total force
		constant_force = total_force
