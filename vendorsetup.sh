function _get_adb_device()
{
	local TD="device:$( get_build_var TARGET_DEVICE )"
    local TP="product:$( get_build_var TARGET_PRODUCT )"
    local PM="model:$( get_build_var PRODUCT_MODEL  | sed 's/ /_/g' )"
	local ADB_DEV=$( adb devices -l | grep "$TP" )
	if [ -z "$ADB_DEV" ] ; then
		ADB_DEV=$( adb devices -l | grep "$PM" )
	fi
	if [ -z "$ADB_DEV" ] ; then
		ADB_DEV=$( adb devices -l | grep "$TD" )
	fi
	echo $ADB_DEV | cut -f1 -d' '



}
function mmp()
{
    mm $@
    if [ $? -ne 0 ] ; then
		echo "mm failed"
		return 2;
    fi
    local LOCAL_ADB_DEV=$(_get_adb_device)
	if [ -z "$LOCAL_ADB_DEV" ] ; then
		echo "No Devices Found"
		return 2;
	fi

	local LOCAL_ADB_ROOT=$( ANDROID_SERIAL=$LOCAL_ADB_DEV adb shell id | grep -o uid=0 )
	if [ -z "$LOCAL_ADB_ROOT" ] ; then
		echo "adb not running as root"
		return 2;
	fi
	local LOCAL_SYS_RW=$( ANDROID_SERIAL=$LOCAL_ADB_DEV adb shell mount | grep /system | grep -o rw )
	if [ -z "$LOCAL_SYS_RW" ] ; then
		echo "System Partition is readonly"
		return 2;
	fi

	local LOCAL_TARGET_ROOT_OUT=$(get_build_var TARGET_ROOT_OUT )

    local LOCAL_INSTALL_PATHS=$(  mm GET-INSTALL-PATH  | grep INSTALL-PATH: | cut -f3 -d' ' | grep -v $ANDROID_HOST_OUT )
    for LOCAL_INSTALL_PATH in $LOCAL_INSTALL_PATHS;
    do
		LOCAL_PUSH_PATH=$( echo $LOCAL_INSTALL_PATH | sed "s#$LOCAL_TARGET_ROOT_OUT\|$ANDROID_PRODUCT_OUT##g" )
		echo "ANDROID_SERIAL=$LOCAL_ADB_DEV adb push $LOCAL_INSTALL_PATH $LOCAL_PUSH_PATH"
		ANDROID_SERIAL=$LOCAL_ADB_DEV adb push $LOCAL_INSTALL_PATH $LOCAL_PUSH_PATH
    done

}
function setup_ccache(){

	export ANDROID_BUILD_ID=$( get_build_var BUILD_ID )
	export ANDROID_CCACHE_DIR="$ANDROID_CCACHE_ROOT/$ANDROID_BUILD_ID"
	if [ -d "$ANDROID_CCACHE_DIR" ] ; then
		echo "setting ccache directory $ANDROID_CCACHE_DIR"
		export CCACHE_DIR=$ANDROID_CCACHE_DIR
		export USE_CCACHE=1
		if [ ! -z $TOP ] ; then
		    $TOP/prebuilts/misc/linux-x86/ccache/ccache -M $ANDROID_CCACHE_SIZE
		fi
	else
		echo "Warning ccache directory for $ANDROID_BUILD_ID Not Found"
		unset CCACHE_DIR
		unset USE_CCACHE
	fi
}
# add_prebuilts_paths 
# This function will be run as part of the build/envsetup.sh proceedure
# It's main purpose is the add a path to the host toolchain and bison binaries
# This lets the chromium_org "build system" function correctly without
# installing gcc and bison on the host operating system
function add_prebuilts_paths(){
	

	# Get the toolchain root from the HOST_TOOLCHAIN_PREFIX
	# The build system should really have an HOST_TOOLCHAIN_ROOT variable.
	# In the meantime we will do a cheeky double dirname to remove the prefix 
	# and the last directory
	local host_tc_root=$( get_abs_build_var HOST_TOOLCHAIN_PREFIX | xargs dirname | xargs dirname )
	
	# We need to export the path to gcc and cc1 for the host toolchain to function 
	local host_tc_paths=$( find $host_tc_root -type f -executable \( -name cc1 -or -name gcc \) -printf "%h:" )
    if [ -n "$host_tc_paths" ] ; then
        export PATH=${PATH/$host_tc_paths/}
    fi
	
	# Export the BISON_PKGDATADIR variable from the Build System
	unset BISON_PKGDATADIR
	export BISON_PKGDATADIR=$( get_build_var BISON_PKGDATADIR )
	
	# Add prebuilt misc tools binary locations to the PATH
	local prebuilt_misc_root=$TOP/prebuilts/misc/$( get_build_var HOST_PREBUILTS_TAG )
	local prebuilt_misc_paths=$( find $prebuilt_misc_root -type f -executable -printf "%h:\0" | uniq -z )
	if [ -n "$prebuilt_misc_paths" ] ; then
        export PATH=${PATH/$prebuilt_misc_paths/}
    fi
	
	# strip leading ':', if any
    export PATH=${PATH/:%/}
	
	export PATH=$host_tc_paths$prebuilt_misc_paths$PATH

}
function copy_local_manifests(){

	mkdir -p $TOP/.repo/local_manifests && echo "Making Local Manifests Directory" && \
	cp -vr $TOP/vendor/*/manifests/*.xml  $TOP/.repo/local_manifests

}
unset TOP
export TOP=$(gettop)

setup_ccache
copy_local_manifests
add_prebuilts_paths

