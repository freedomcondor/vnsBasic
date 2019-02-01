argosBuildDir="../argos3-harry/build"

#this if may not be necessary
if [ "$ARGOS_PLUGIN_PATH" == "" ]; then 
	echo "sourcing"
	source $argosBuildDir/setup_env.sh
fi
$argosBuildDir/core/argos3 -c experiment.argos

