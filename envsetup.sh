source build/envsetup.sh
export USE_CCACHE=1
export CCACHE_DIR=$ANDROID_CCACHE_ROOT
function _get_adb_device()
{
	local TD="device:$( get_build_var TARGET_DEVICE )"
    local TP="product:$( get_build_var TARGET_PRODUCT )"
    local PM="model:$( get_build_var PRODUCT_MODEL  | sed 's/ /_/g' )"
	local ADB_DEV=$( adb devices -l | grep "$TP" )
	#echo "A=$ADB_DEV PM=$PM TP=$TP TD=$TD"

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
    local ADB_DEV=$(_get_adb_device)
	if [ -z "$ADB_DEV" ] ; then
		echo "No Devices Found"
		return 2;
	fi

	local ADB_ROOT=$( ANDROID_SERIAL=$ADB_DEV adb shell id | grep -o uid=0 )
	if [ -z "$ADB_ROOT" ] ; then
		echo "adb not running as root"
		return 2;
	fi
	local SYS_RW=$( ANDROID_SERIAL=$ADB_DEV adb shell mount | grep /system | grep -o rw )
	if [ -z "$SYS_RW" ] ; then
		echo "System Partition is readonly"
		return 2;
	fi

    local INSTALL_PATHS=$(  mm GET-INSTALL-PATH  | grep INSTALL-PATH: | cut -f3 -d' ' | grep -v $ANDROID_HOST_OUT )
    for INSTALL_PATH in $INSTALL_PATHS;
    do
		PUSH_PATH=$( echo $INSTALL_PATH | sed "s#$ANDROID_PRODUCT_OUT##g" )
		echo "ANDROID_SERIAL=$ADB_DEV adb push $INSTALL_PATH $PUSH_PATH"
		ANDROID_SERIAL=$ADB_DEV adb push $INSTALL_PATH $PUSH_PATH
    done

}
