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
#   curl https://raw.githubusercontent.com/francois-le-ko4la/hass/main/master_rasp.sh | sudo sh
#
# Example:
#  curl https://raw.githubusercontent.com/francois-le-ko4la/hass/main/master_rasp.sh | sudo sh
# [sudo] password for ko4la:
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100  9247  100  9247    0     0  29514      0 --:--:-- --:--:-- --:--:-- 29637
# 2024-04-28T00:50:27+02:00 - Master RASP - Ubuntu 20.04 or newer detected.
# 2024-04-28T00:50:27+02:00 - Master RASP - Plateform detected: Raspberry Pi 4 Model B Rev 1.4
# 2024-04-28T00:50:27+02:00 - Master RASP - FSTAB: Update is required.
# 2024-04-28T00:50:27+02:00 - Master RASP - FSTAB: Do you want to update ?
# 1,5c1,5
# < # UNCONFIGURED FSTAB FOR BASE SYSTEM
# < LABEL=writable    /     ext4    defaults,noatime,discard,x-systemd.growfs    0 0
# < LABEL=system-boot       /boot/firmware  vfat    defaults        0       1
# < tmpfs /var/cache/apt/archives tmpfs defaults,noexec,nosuid,nodev,mode=0755 0 0
# < tmpfs /media/ramdisk  tmpfs   defaults,noatime,mode=1777 0 0
# ---
# > #                                          UNCONFIGURED             FSTAB  FOR                                        BASE  SYSTEM
# > UUID=aaaaaaaa-bbbb-cccc-cccc-dddddddddddd  /                        ext4   defaults,noatime,discard,x-systemd.growfs  0     0
# > UUID=YYYY-ZZZZ                             /boot/firmware           vfat   defaults                                   0     1
# > tmpfs                                      /var/cache/apt/archives  tmpfs  defaults,noexec,nosuid,nodev,mode=0755     0     0
# > tmpfs                                      /media/ramdisk           tmpfs  defaults,noatime,mode=1777                 0     0
# Do you want to update "/etc/fstab" with the content of "/tmp/fstab" ? [Y/n] Y
# 2024-04-28T00:51:11+02:00 - Master RASP - FSTAB: Update requested by user.
# 2024-04-28T00:51:11+02:00 - Master RASP - Backup your system file: /etc/fstab.202404280051
# 2024-04-28T00:51:11+02:00 - Master RASP - File "/etc/fstab" has been updated.
# 2024-04-28T00:51:11+02:00 - Master RASP - CMDLINE: Root is defined in /boot/firmware/cmdline.txt.
# 2024-04-28T00:51:11+02:00 - Master RASP - CMDLINE: Update is required.
# 2024-04-28T00:51:11+02:00 - Master RASP - CMDLINE: Do you want to update ?
# 1c1
# < dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 elevator=deadline rootwait fixrtc quiet splash
# ---
# > dwc_otg.lpm_enable=0 console=tty1 root=PARTUUID=XXXXXXXX-02 rootfstype=ext4 elevator=deadline rootwait fixrtc quiet splash
# Do you want to update "/boot/firmware/cmdline.txt" with the content of "/tmp/cmdline.txt" ? [Y/n] Y
# 2024-04-28T00:51:38+02:00 - Master RASP - CMDLINE: Update requested by user.
# 2024-04-28T00:51:39+02:00 - Master RASP - Backup your system file: /boot/firmware/cmdline.txt.202404280051
# 2024-04-28T00:51:39+02:00 - Master RASP - File "/boot/firmware/cmdline.txt" has been updated.
# 2024-04-28T00:51:39+02:00 - Master RASP - EEPROM CONFIG: Update is required.
# 2c2
# < BOOT_UART=0
# ---
# > BOOT_UART=0xf14
# EEPROM [Y/n] n
# 2024-04-28T00:51:59+02:00 - Master RASP - EEPROM CONFIG: User canceled. No updates made.
###############################################################################

FSTAB="/etc/fstab"
FSTAB_TMP="/tmp/fstab"
OS_RELEASE="/etc/os-release"
HW_MODEL="/sys/firmware/devicetree/base/model"
CMD_LINE="/boot/firmware/cmdline.txt"
CMD_LINE_TMP="/tmp/cmdline.txt"
CUR_EEPROM_CONFIG="/tmp/current_bootloader_config"
CMD_LIST="blkid diff awk vcgencmd rpi-eeprom-config rpi-eeprom-update"

ROOT_FS_LABEL_SHORT="writable"
ROOT_FS_LABEL="LABEL=$ROOT_FS_LABEL_SHORT"
ROOT_FS_MNTPT='/'
SYSB_FS_LABEL_SHORT="system-boot"
SYSB_FS_LABEL="LABEL=$SYSB_FS_LABEL_SHORT"
SYSB_FS_MNTPT='/boot/firmware'

EEPROM_STABLE_BIN_PATH="/lib/firmware/raspberrypi/bootloader-2711/stable"
EEPROM_BINFILE="pieeprom-2024-04-17.bin"
EEPROM_GH_BINFILE="https://github.com/raspberrypi/rpi-eeprom/raw/master/firmware-2711/latest/$EEPROM_BINFILE"
EEPROM_DEF_VERSION="1713358296"

INFO="INFO"
ERROR="ERROR"

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

MSG_CMDLINE_ROOT_DEFINED="${MSG_CMDLINE_PREFIX}Root is defined in $CMD_LINE."
MSG_CMDLINE_ROOT_NOT_DEFINED="${MSG_CMDLINE_PREFIX}Root is not defined in $CMD_LINE. Check your configuration."
MSG_EEPROM_CONFIC_OK="${MSG_EEPROM_PREFIX}${MSG_CONFIG_OK}"
MSG_EEPROM_UPDATE_REQUIRED="${MSG_EEPROM_PREFIX}${MSG_UPDATE_REQUIRED}"
MSG_EEPROM_USER_VALIDATION="${MSG_EEPROM_PREFIX}${MSG_USER_VALIDATION}"
MSG_EEPROM_USER_CANCELED="${MSG_EEPROM_PREFIX}${MSG_USER_CANCELED}"
MSG_EEPROM_BINNOTFOUND="${MSG_EEPROM_PREFIX}BIN file not found."
MSG_EEPROM_DOWNLD_BIN="${MSG_EEPROM_PREFIX}downloadding BIN file..."
MSG_EEPROM_BINFOUND="${MSG_EEPROM_PREFIX}BIN file already exists."
MSG_EEPROM_UPTD="${MSG_EEPROM_PREFIX}ROM is up to date."
MSG_EEPROM_UPD_IN_PROG="${MSG_EEPROM_PREFIX}ROM update in progress."
MSG_EEPROM_UPDATED="${MSG_EEPROM_PREFIX}ROM updated."
MSG_EEPROM_DOWNLDED="${MSG_EEPROM_PREFIX}BIN file downloaded successfully."
MSG_EEPROM_DOWNLD_FAILED="${MSG_EEPROM_PREFIX}Unable to download BIN file. exit..."

MSG_ERR_COMPO_NOT_FOUND="Please install \"%s\" first"

QUESTION_FMT="Do you want to update \"%s\" with the content of \"%s\" ?"
UPDT_FMT="File \"%s\" has been updated."

CONF_EEPROM="[all]
BOOT_UART=0
WAKE_ON_GPIO=1
POWER_OFF_ON_HALT=0
BOOT_ORDER=0xf14
"
CONF_EEPROM_TMP_FILE="/tmp/boot.conf"

###############################################################################

log() {
    local SEV="$1"
    local MSG="$2"
    echo "$(date --iso-8601=seconds) - Master RASP - $SEV - $MSG"
}

###############################################################################

ask_yes_no() {
    local QUESTION="$1"
    
    while true; do
        printf "%s [Y/n] " "$QUESTION"
        read -r answer </dev/tty
        answer=$(echo "$answer" | tr -d '[:space:]')
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
    # Check the user
    if [ "${EUID:-0}" -ne 0 ] || [ "$(id -u)" -ne 0 ]; then
        log "$ERROR" "Please run this script as root or using sudo!"
        exit 1
    fi
    
    # Check if the platform is Linux
    if [ "$(uname)" != "Linux" ]; then
        log "$ERROR" "$MSG_ERR_NOT_LINUX"
        exit 1
    fi

    # Check if the platform is Ubuntu 20.04 or newer
    if [ -f $OS_RELEASE ]; then
        . $OS_RELEASE
        if [ "$ID" = "ubuntu" ] && [ "${VERSION_ID%.*}" -ge 20 ]; then
            log "$INFO" "$MSG_INFO_OS_SUPPORTED"
            MODEL=$(cat $HW_MODEL)
            if echo "$MODEL" | grep -q "Raspberry" ; then
            log "$INFO" "$MSG_INFO_HW_SUPPORTED $MODEL"
        else
            log "$ERROR" "$MSG_ERR_UNSUPPORTED_HW"
            exit 1
        fi
        else
            log "$ERROR" "$MSG_ERR_UNSUPPORTED_VERSION"
            exit 1
        fi
    else
        log "$ERROR" "$MSG_ERR_OS_DETECT"
        exit 1
    fi

    # check command
    for cmd in $CMD_LIST
    do
        err_message=$(printf "$MSG_ERR_COMPO_NOT_FOUND" "$cmd")
        command -v $cmd > /dev/null 2>&1 || { log "$ERROR" "$err_message"; exit 1; }
    done
}

###############################################################################

backup_system_file() {
    local FILE=$1
    local BKP_FILE="$1.$(date +'%Y%m%d%H%M')"
    cp $FILE $BKP_FILE
    log "$INFO" "$MSG_INFO_BKP_FILE $BKP_FILE"
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
    echo $(blkid -s UUID -o value $(blkid --label $CUR_LABEL))
}

###############################################################################

get_partuuid_from_label() {
    CUR_LABEL=$1
    echo $(blkid -s PARTUUID -o value $(blkid --label $CUR_LABEL))
}

###############################################################################

compare_and_prompt_update() {
    local FILE1="$1"
    local FILE2="$2"
    local MSG_PREFIX="$3"
    local QUESTION=""
    
    # Check if files are identical
    if diff "$FILE1" "$FILE2" > /dev/null 2>&1; then
        log "$INFO" "${MSG_PREFIX}${MSG_CONFIG_OK}"
        return
    else
        log "$INFO" "${MSG_PREFIX}${MSG_UPDATE_REQUIRED}"
        log "$INFO" "${MSG_PREFIX}${MSG_USER_VALIDATION}"
        diff "$FILE1" "$FILE2"
        
        QUESTION=$(printf "$QUESTION_FMT" "$FILE1" "$FILE2")
        if ask_yes_no "$QUESTION"; then
            log "$INFO" "${MSG_PREFIX}${MSG_UPDAT_REQUESTED}"
            backup_system_file $FILE1
            cp "$FILE2" "$FILE1"
            MSG=$(printf "$UPDT_FMT" $FILE1)
            log "$INFO" "$MSG"
        else
            log "$INFO" "${MSG_PREFIX}${MSG_USER_CANCELED}"
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
                         -m $SYSB_FS_MNTPT | column -t     > $FSTAB_TMP
    compare_and_prompt_update "$FSTAB" "$FSTAB_TMP" "$MSG_FSTAB_PREFIX"
}

###############################################################################

change_partition_uuid_in_cmdline() {
    local ROOT_FS_PARTUUID=$(get_partuuid_from_label "$ROOT_FS_LABEL_SHORT")
    local SEP=$(cat $CMD_LINE | awk -F'root=' '{print $2}' | awk '{print $1}')

    if [ -n "$SEP" ]; then
        log "$INFO" "$MSG_CMDLINE_ROOT_DEFINED"
        cat $CMD_LINE | sed "s/root=[^ ]*/root=PARTUUID=$ROOT_FS_PARTUUID/" > $CMD_LINE_TMP
        compare_and_prompt_update $CMD_LINE $CMD_LINE_TMP "$MSG_CMDLINE_PREFIX"
    else
        log "$INFO" "$MSG_CMDLINE_ROOT_NOT_DEFINED"
    fi
}

###############################################################################

apply_eeprom_config() {
    echo "$CONF_EEPROM" > $CONF_EEPROM_TMP_FILE
    vcgencmd bootloader_config > $CUR_EEPROM_CONFIG
    if diff "$CONF_EEPROM_TMP_FILE" "$CUR_EEPROM_CONFIG" > /dev/null 2>&1; then
        log "$INFO" "$MSG_EEPROM_CONFIC_OK"
    else
        log "$INFO" "$MSG_EEPROM_UPDATE_REQUIRED"
        diff "$CUR_EEPROM_CONFIG" "$CONF_EEPROM_TMP_FILE"
        if ask_yes_no $MSG_EEPROM_USER_VALIDATION; then
            rpi-eeprom-config --apply $CONF_EEPROM_TMP_FILE
        else
            log "$INFO" "$MSG_EEPROM_USER_CANCELED"
        fi
    fi
}

###############################################################################

update_eeprom() {
    if [ -f "$EEPROM_STABLE_BIN_PATH/$EEPROM_BINFILE" ]; then
        log "$INFO" "$MSG_EEPROM_BINFOUND"
    else
        log "$INFO" "$MSG_EEPROM_BINNOTFOUND"
        log "$INFO" "$MSG_EEPROM_DOWNLD_BIN"
        if wget -P $EEPROM_STABLE_BIN_PATH $EEPROM_GH_BINFILE > /dev/null 2>&1 ; then
            log "$INFO" "$MSG_EEPROM_DOWNLDED"
        else
            log "$ERROR" "$MSG_EEPROM_DOWNLD_FAILED"
            exit 1
        fi
    fi
    if rpi-eeprom-update | grep "$EEPROM_DEF_VERSION" > /dev/null 2>&1 ; then
        log "$INFO" "$MSG_EEPROM_UPTD"
    else
        log "$INFO" "$MSG_EEPROM_UPD_IN_PROG"
        rpi-eeprom-update -f "$EEPROM_STABLE_BIN_PATH/$EEPROM_BINFILE"
        log "$INFO" "$MSG_EEPROM_UPDATED"
    fi
}

###############################################################################

# Main
check_env
change_partition_label_2_uuid_in_fstab
change_partition_uuid_in_cmdline
apply_eeprom_config
update_eeprom

exit
