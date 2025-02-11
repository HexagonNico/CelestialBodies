@tool
class_name CelestialBody3D
extends RigidBody3D


const GRAVITATIONAL_CONSTANT := 0.01

const GROUP_NAME := &"__celestial_body__"


## The debug color of the orbit.
@export var debug_orbit_color := Color.WHITE


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(GROUP_NAME)


# Called every physics step.
func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		# Compute the total force resulting from the other celestial bodies in the scene
		var celestial_bodies := get_tree().get_nodes_in_group(GROUP_NAME)
		var total_force := Vector3.ZERO
		for node in celestial_bodies:
			# Skip this celestial body
			if node != self and node is CelestialBody3D:
				var celestial_body := node as CelestialBody3D
				# Compute force due to this other body
				var squared_distance := global_position.distance_squared_to(celestial_body.global_position)
				var direction := global_position.direction_to(celestial_body.global_position)
				total_force += direction * GRAVITATIONAL_CONSTANT * mass * celestial_body.mass / squared_distance
		# Apply total force
		constant_force = total_force
