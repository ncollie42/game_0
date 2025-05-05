import bpy
import os
import glob 

# blender -b --python fbx2m3d.py 

# Clear existing scene
bpy.ops.wm.read_factory_settings(use_empty=True)
 
# Get current directory
current_dir = os.getcwd()
print(f"[CONVERT] Working in directory: {current_dir}")

# Find all FBX files in the current directory
fbx_files = glob.glob(os.path.join(current_dir, "*.fbx"))
if not fbx_files:
    print("[CONVERT] Error: No FBX files found in the current directory")
    exit(1)
print(f"[CONVERT] Found {len(fbx_files)} FBX files: {[os.path.basename(f) for f in fbx_files]}")

fbx_files.sort()

# Import first FBX file (this will establish the mesh and armature)
bpy.ops.import_scene.fbx(filepath=fbx_files[0])
print(f"[CONVERT] Imported base model: {fbx_files[0]}")

# Get the armature from the first import
base_armature = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        base_armature = obj
        break

if not base_armature:
    print("[CONVERT] Error: No armature found in the first FBX")
    exit(1)

# Store the original action from the first import
original_actions = []
if base_armature.animation_data and base_armature.animation_data.action:
    original_actions.append(base_armature.animation_data.action)

# Import animations from other FBX files
for fbx_path in fbx_files[1:]:
    # Import to a temporary scene
    temp_scene = bpy.data.scenes.new("TempScene")
    bpy.context.window.scene = temp_scene
    
    # Import the FBX for its animation
    bpy.ops.import_scene.fbx(filepath=fbx_path)
    print(f"[CONVERT] Importing animation from: {fbx_path}")
    
    # Find any new actions
    for obj in temp_scene.objects:
        if obj.type == 'ARMATURE' and obj.animation_data and obj.animation_data.action:
            # Copy action to main armature
            action = obj.animation_data.action
            if action not in original_actions:
                original_actions.append(action)
                print(f"[CONVERT] Found action: {action.name}")
    
    # Switch back to main scene and remove temp scene
    bpy.context.window.scene = bpy.data.scenes[0]
    bpy.data.scenes.remove(temp_scene)

# Make sure all actions are available in the NLA editor
if base_armature:
    if not base_armature.animation_data:
        base_armature.animation_data_create()
    
    # Clear any existing tracks
    while base_armature.animation_data.nla_tracks:
        base_armature.animation_data.nla_tracks.remove(base_armature.animation_data.nla_tracks[0])
    
    # Add all actions to NLA
    for i, action in enumerate(original_actions):
        track = base_armature.animation_data.nla_tracks.new()
        track.name = action.name
        
        # Create a strip that references the action
        strip = track.strips.new(action.name, int(i * 50), action)
        
        # Make sure strip length matches action length
        if hasattr(action, 'frame_range'):
            strip.frame_start = int(i * 50)
            strip.frame_end = int(i * 50 + (action.frame_range[1] - action.frame_range[0]))

# Set up the M3D exporter
addon_path = "/home/nico/.config/blender/4.3/scripts/addons/io_scene_m3d.py"
exec(open(addon_path).read())

# Output path for the combined model
output_path = f"{current_dir}/base.m3d"

# Export to M3D format
try:
    bpy.ops.export_scene.m3d(
        filepath=output_path,
        use_selection=False,
        use_mesh_modifiers=True,
        use_normals=True,
        use_uvs=True,
        use_colors=True,
        use_materials=True,
        use_skeleton=True,
        use_animation=True,
        use_markers=False,
        use_gridcompress=True,
        use_fps=30, # (default is 25)
        use_strmcompress=True
    )
    print(f"[CONVERT] Successfully exported to {output_path}")
except Exception as e:
    print(f"[CONVERT] Export error: {e}")


# output_path = f"{current_dir}/base.glb"
# # Export to GLB format
# try:
#     bpy.ops.export_scene.gltf(
#         filepath=output_path,
#         export_format='GLB',
#         use_selection=False,
#         export_animations=True,
#         export_nla_strips=True,
#         export_current_frame=False,
#         export_skins=True,
#         export_morph=True
#     )
#     print(f"[CONVERT] Successfully exported to {output_path}")
# except Exception as e:
#     print(f"[CONVERT] Export error: {e}")
