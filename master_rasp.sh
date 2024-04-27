#!/bin/sh
#
# DESCRIPTION:
# This script sets up a raspberry pi4 to boot with external USB storage.
#
# DISCLAIMER:
# This script is not supported under any support program or service. 
# All scripts are provided AS IS without warranty of any kind. 
# The author further disclaims all implied warranties including, without
# limitation, any implied warranties of merchantability or of fitness for a
# particular purpose. 
# The entire risk arising out of the use or performance of the sample scripts
# and documentation remains with you. 
# In no event shall its authors, or anyone else involved in the creation,
# production, or delivery of the scripts be liable for any damages whatsoever 
# (including, without limitation, damages for loss of business profits, business
# interruption, loss of business information, or other pecuniary loss) 
# arising out of the use of or inability to use the sample scripts or documentation,
# even if the author has been advised of the possibility of such damages.
#
# REQUIREMENTS:
# - ubuntu 20.04+
#
# SETUP:
#  sudo curl https://raw.githubusercontent.com/francois-le-ko4la/hass/main/master_rasp.sh | sudo sh
#
###############################################################################

FSTAB="/etc/fstab"
FSTAB_TMP="/tmp/fstab"
OS_RELEASE="/etc/os-release"
HW_MODEL="/sys/firmware/devicetree/base/model"
CMD_LINE="/boot/firmware/cmdline.txt"
CMD_LINE_TMP="/tmp/cmdline.txt"
CUR_EEPROM_CONFIG="/tmp/current_bootloader_config"

ROOT_FS_LABEL_SHORT="writable"
ROOT_FS_LABEL="LABEL=$ROOT_FS_LABEL_SHORT"
ROOT_FS_MNTPT='/'
SYSB_FS_LABEL_SHORT="system-boot"
SYSB_FS_LABEL="LABEL=$SYSB_FS_LABEL_SHORT"
SYSB_FS_MNTPT='/boot/firmware'

MSG_ERR_OS_DETECT="Unable to detect the operating system."
MSG_ERR_NOT_LINUX="This script only works on Linux systems."
MSG_ERR_UNSUPPORTED_VERSION="Unsupported Ubuntu version. Exiting..."
MSG_ERR_UNSUPPORTED_HW="This environment does not seem to be a Raspberry Pi."
MSG_INFO_OS_SUPPORTED="Ubuntu 20.04 or newer detected."
MSG_INFO_HW_SUPPORTED="Plateform detected:"
MSG_INFO_BKP_FILE="Backup your system file:"

MSG_CONFIG_OK="Current configuration validated. No update made."
MSG_UPDATE_REQUIRED="Update is required."
MSG_USER_VALIDATION="Do you want to update ?"
MSG_UPDAT_REQUESTED="Update requested by user."
MSG_USER_CANCELED="User canceled. No updates made."

MSG_FSTAB_PREFIX="FSTAB: "
MSG_CMDLINE_PREFIX="CMDLINE: "
MSG_EEPROM_PREFIX="EEPROM CONFIG: "

MSG_CMDLINE_ROOT_DEFINED="CMDLINE: Root is defined in $CMD_LINE."
MSG_CMDLINE_ROOT_NOT_DEFINED="CMDLINE: Root is not defined in $CMD_LINE. Check your configuration."
MSG_EEPROM_CONFIC_OK="${MSG_EEPROM_PREFIX}${MSG_CONFIG_OK}"
MSG_EEPROM_UPDATE_REQUIRED="${MSG_EEPROM_PREFIX}${MSG_UPDATE_REQUIRED}"
MSG_EEPROM_USER_VALIDATION="${MSG_EEPROM_PREFIX}${MSG_USER_VALIDATION}"
MSG_EEPROM_USER_CANCELED="${MSG_EEPROM_PREFIX}${MSG_USER_CANCELED}"


CONF_EEPROM="[all]
BOOT_UART=0xf14
WAKE_ON_GPIO=1
POWER_OFF_ON_HALT=0
"
CONF_EEPROM_TMP_FILE="/tmp/boot.conf"

###############################################################################

log() {
    echo "$(date --iso-8601=seconds) - Master RASP - $1"
}

###############################################################################

ask_yes_no() {
    local QUESTION="$1"
    
    while true; do
        printf "%s [Y/n] " "$QUESTION"
        read answer
        case "$answer" in
            [Yy]*|"")
                return 0
                ;;
            [Nn]*)
                return 1
                ;;
            *)
                echo "Invalid response. Please enter Y or N."
                ;;
        esac
    done
}

###############################################################################

check_env() {
    # Check if the platform is Linux
    if [ "$(uname)" != "Linux" ]; then
        log "$MSG_ERR_NOT_LINUX"
        exit 1
    fi

    # Check if the platform is Ubuntu 20.04 or newer
    if [ -f $OS_RELEASE ]; then
        . $OS_RELEASE
        if [ "$ID" = "ubuntu" ] && [ "${VERSION_ID%.*}" -ge 20 ]; then
            log "$MSG_INFO_OS_SUPPORTED"
            MODEL=$(cat $HW_MODEL)
            if echo "$MODEL" | grep -q "Raspberry" ; then
            log "$MSG_INFO_HW_SUPPORTED $MODEL"
        else
            log "$MSG_ERR_UNSUPPORTED_HW"
            exit 1
        fi
        else
            log "$MSG_ERR_UNSUPPORTED_VERSION"
            exit 1
        fi
    else
        log "$MSG_ERR_OS_DETECT"
        exit 1
    fi
}

###############################################################################

backup_system_file() {
    local FILE=$1
    local BKP_FILE="$1.$(date +'%Y%m%d%H%M')"
    cp $FILE $BKP_FILE
    log "$MSG_INFO_BKP_FILE $BKP_FILE"
}

###############################################################################

change_fstab_row() {
    local CUR_LABEL NEW_UUID CUR_MNTPNT

    while getopts ":l:u:m:" opt; do
        case ${opt} in
            l )
                CUR_LABEL=$OPTARG
                ;;
            u )
                NEW_UUID=$OPTARG
                ;;
            m )
                CUR_MNTPNT=$OPTARG
                ;;
            \? )
                echo "Invalid option: $OPTARG" 1>&2
                return 1
                ;;
            : )
                echo "Option -$OPTARG requires an argument." 1>&2
                return 1
                ;;
        esac
    done
    shift $((OPTIND -1))

    awk -v uuid="$NEW_UUID" -v label="$CUR_LABEL" -v mountpoint="$CUR_MNTPNT" \
        ' \
        (NF==6)&&($1==label)&&($2==mountpoint) { \
            print uuid,$2,$3,$4,$5,$6; \
            next \
        } \
        1'
}

###############################################################################

get_uuid_from_label() {
    CUR_LABEL=$1
    echo $(sudo blkid | grep $CUR_LABEL | grep -oP ' UUID="\K[^"]+')
}

###############################################################################

get_partuuid_from_label() {
    CUR_LABEL=$1
    echo $(sudo blkid | grep $CUR_LABEL | grep -oP ' PARTUUID="\K[^"]+')
}

###############################################################################

compare_and_prompt_update() {
    local FILE1="$1"
    local FILE2="$2"
    local MSG_PREFIX="$3"
    
    # Check if files are identical
    if diff "$FILE1" "$FILE2" > /dev/null 2>&1; then
        log "${MSG_PREFIX}${MSG_CONFIG_OK}"
        return
    else
        log "${MSG_PREFIX}${MSG_UPDATE_REQUIRED}"
        log "${MSG_PREFIX}${MSG_USER_VALIDATION}"
        diff "$FILE1" "$FILE2"
        if ask_yes_no "${MSG_PREFIX}Do you want to update \"$FILE1\" with the content of \"$FILE2\" ?"; then
            log "${MSG_PREFIX}${MSG_UPDAT_REQUESTED}"
            backup_system_file $FILE1
            cp "$FILE2" "$FILE1"
            log "File \"$FILE1\" has been updated."
        else
            log "${MSG_PREFIX}${MSG_USER_CANCELED}"
        fi

    fi
}

###############################################################################

change_partition_label_2_uuid_in_fstab() {
    local ROOT_FS_UUID=$(get_uuid_from_label "$ROOT_FS_LABEL_SHORT")
    local SYSB_FS_UUID=$(get_uuid_from_label "$SYSB_FS_LABEL_SHORT")

    cat "$FSTAB" |                                         \
        change_fstab_row -l $ROOT_FS_LABEL                 \
                         -u "UUID=$ROOT_FS_UUID"           \
                         -m $ROOT_FS_MNTPT |               \
        change_fstab_row -l $SYSB_FS_LABEL                 \
                         -u "UUID=$SYSB_FS_UUID"           \
                         -m $SYSB_FS_MNTPT                 > $FSTAB_TMP
    compare_and_prompt_update "$FSTAB" "$FSTAB_TMP" "$MSG_FSTAB_PREFIX"
}

###############################################################################

change_partition_uuid_in_cmdline() {
    local root_fs=$(get_partuuid_from_label "writable")
    local sep=$(cat $CMD_LINE | awk -F'root=' '{print $2}' | awk '{print $1}')

    if [ -n "$sep" ]; then
        log "$MSG_CMDLINE_ROOT_DEFINED"
        cat $CMD_LINE | sed "s/root=[^ ]*/root=PARTUUID=$root_fs/" > $CMD_LINE_TMP
        compare_and_prompt_update $CMD_LINE $CMD_LINE_TMP "$MSG_CMDLINE_PREFIX"
    else
        log "$MSG_CMDLINE_ROOT_NOT_DEFINED"
    fi

}

###############################################################################

apply_eeprom_config() {
    echo "$CONF_EEPROM" > $CONF_EEPROM_TMP_FILE
    vcgencmd bootloader_config > $CUR_EEPROM_CONFIG
    if diff "$CONF_EEPROM_TMP_FILE" "$CUR_EEPROM_CONFIG" > /dev/null 2>&1; then
        log "$MSG_EEPROM_CONFIC_OK"
    else
        log "$MSG_EEPROM_UPDATE_REQUIRED"
        diff "$CUR_EEPROM_CONFIG" "$CONF_EEPROM_TMP_FILE"
        if ask_yes_no $MSG_EEPROM_USER_VALIDATION; then
            sudo rpi-eeprom-config --apply $CONF_EEPROM_TMP_FILE
        else
            log "$MSG_EEPROM_USER_CANCELED"
        fi
    fi
}

###############################################################################


# Main
check_env
change_partition_label_2_uuid_in_fstab
change_partition_uuid_in_cmdline
apply_eeprom_config

exit
