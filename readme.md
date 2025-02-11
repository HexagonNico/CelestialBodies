
# Celestial Bodies

This project is based on Sebastian Lague's [Solar System](https://github.com/SebLague/Solar-System).

## Project overview

> [!NOTE]
> The demo project requires the Mono version of Godot. The addon, however, can be used with the regular version as well.

### Planet Generators

The project explores different ways of implementing a procedural planet mesh generator.

The `mesh_tester` directory contains different scripts with different mesh generators.
The generators can be viewed together in the `mesh_tester.tscn` scene.

The `gdscript_mesh.gd` script is the basic implementation written in GDScript.

The `CSharpMesh.cs` script is the same implementation, but written in C#.

The `compute_shader_mesh.gd` script uses a compute shader to generate the points on the mesh.
However, it does not support the planet noise, therefore it only generates a sphere.

The `threaded_mesh.gd` script uses the same implementation as the first one, but separates the generation in six threads.

The most efficient implementation is in the `planet_generator.gd` script, the one included in the addon.
It uses six threads to generate the six faces of the mesh, but does not pause the execution until the mesh is finished.
It can also save the mesh in the scene file for it to be reloaded the next time without being regenerated.

Each one of these scripts will show a read-only field in the inspector to show how long it took to generate the mesh in milliseconds.

### Solar system simulation

The `solar_system.tscn` scene shows an example of a solar system where different celestial bodies interact with each other.
In the editor you can see a prediction of the trajectory of each celestial body.

You can modify the masses the and initial velocities of the celestial bodies in the scene to adjust their orbit and the editor will update the prediction in real time.

## Installing the addon

The procedure is the same as other Godot addons.
See the [Godot docs](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html) for a full explanation.

1. Click the **AssetLib** tab at the top of the editor and look for "Celestial Bodies".

2. Download the plugin and install the contents of the `addons` folders into your project's directory.

3. Go to `Project -> Project Settings... -> Plugins` and enable the plugin by checking "Enable".

### Addon content

The addon contains the `planet_generator.gd` script.
A planet generator can be added to your scene from the "Create new node" menu and searching for the **PlanetGenerator** node.

The planet will be regenerated every time a property in the inspector is modified.
The mesh will be saved in the scene file so that is does not have to be regenerated again when the scene is reopened.

The `celestial_body_3d.gd` script extends from **RigidBody3D** and is used to create a celestial body.
A node with this script should usually be at the root of your planet scene.
It can be created by searching for **CelestialBody3D** in the "Create new node" menu.
All celestial bodies in the scene affect each other through gravitational forces.

See the `test_planet.tscn` scene for an example.

## Future plans

* Atmosphere rendering
	* Atmosphere using FogVolume?

## Support

If you like my projects and want to support me, please consider checking out [Ancient Mind](https://store.steampowered.com/app/2376750/Ancient_Mind/).
Out now on Steam!
