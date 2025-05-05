#!/bash/sh


echo "Golem 1"
echo ""
cd ./resources/golem_large/fbx
# Convert all the FBX to a single m3d from the current dir
blender_4.3 -b --python ../../../fbx2m3d.py
mv ./base.m3d ../base.m3d
cd -

echo "Golem 2"
echo ""
cd ./resources/golem_small_mele/fbx
# Convert all the FBX to a single m3d from the current dir
blender_4.3 -b --python ../../../fbx2m3d.py
mv ./base.m3d ../base.m3d
cd - 

echo "Golem 2"
echo ""
cd ./resources/golem_small_range/fbx
# Convert all the FBX to a single m3d from the current dir
blender_4.3 -b --python ../../../fbx2m3d.py
mv ./base.m3d ../base.m3d
