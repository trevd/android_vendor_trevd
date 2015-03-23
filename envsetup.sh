source build/envsetup.sh

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
	else
		unset CCACHE_DIR
		unset USE_CCACHE
	fi
}

setup_ccache

