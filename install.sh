#!/usr/bin/env bash
#################################################
###### AUTOMATED INSTALL AND UPDATE SCRIPT ######
#################################################
# Written by yomgui1 & Frix_x
# @version: 1.0

# CHANGELOG:
#   v1.0: first version of the script to allow a peaceful install and update ;)
#   v1.1: add more config variables to support custom folders and forks.

USERNAME="danielfmo"
# Where the user Klipper config is located (ie. the one used by Klipper to work)
KLIPPER_CONFIG_PATH="$(realpath -e ${HOME}/printer_data/config)"
# Config Repositiry URL
GIT_REPO_URL="https://github.com/danielfmo/klipper-config.git"
# Where to clone Frix-x repository config files (read-only and keep untouched)
GIT_REPO_PATH="${HOME}/${USERNAME}_config"
# Path used to store backups when updating (backups are automatically dated when saved inside)
BACKUP_PATH="${HOME}/printer_data/backup"


set -eu
export LC_ALL=C

# Step 1: Verify that the script is not run as root and Klipper is installed
function preflight_checks {
    if [ "$EUID" -eq 0 ]; then
        echo "This script must not be run as root"
        exit -1
    fi

    if [ "$(sudo systemctl list-units --full -all -t service --no-legend | grep -F 'klipper.service')" ]; then
        echo "Klipper service found! Continuing..."
    else
        echo "Klipper service not found, please install Klipper first!"
        exit -1
    fi
}

# Step 2: Check if the git config folder exist (or download it)
function check_download {
    local frixtemppath frixreponame
    frixtemppath="$(dirname ${GIT_REPO_PATH})"
    frixreponame="$(basename ${GIT_REPO_PATH})"

    if [ ! -d "${GIT_REPO_PATH}" ]; then
        echo "Downloading Frix-x configuration folder..."
        if git -C $frixtemppath clone ${GIT_REPO_URL} $frixreponame; then
            chmod +x ${GIT_REPO_PATH}/install.sh
            echo "Download complete!"
        else
            echo "Download of Frix-x configuration git repository failed!"
            exit -1
        fi
    else
        echo "Frix-x git repository folder found locally!"
    fi
}

# Step 3: Backup the old Klipper configuration
function backup_config {
    mkdir -p ${BACKUP_DIR}

    if [ -f "${KLIPPER_CONFIG_PATH}/.VERSION" ]; then
        echo "Frix-x configuration already in use: only a backup of the custom user cfg files is needed"
        find ${KLIPPER_CONFIG_PATH} -type f -regex '.*\.\(cfg\|conf\|VERSION\)' | xargs mv -t ${BACKUP_DIR}/ 2>/dev/null
    else
        echo "New installation detected: a full backup of the user config folder is needed"
        cp -fa ${KLIPPER_CONFIG_PATH} ${BACKUP_DIR}
    fi

    echo "Backup done in: ${BACKUP_DIR}"
}

# Step 4: Put the new configuration files in place to be ready to start
function install_config {
    echo "Installation of the last Frix-x Klipper configuration files"
    mkdir -p ${KLIPPER_CONFIG_PATH}

    # Symlink Frix-x config folders (read-only git repository) to the user's config directory
    for dir in config macros scripts moonraker; do
        ln -fsn ${GIT_REPO_PATH}/$dir ${KLIPPER_CONFIG_PATH}/$dir
    done

    # Copy custom user's config files from the last backup to restore them to their config directory (or install templates if it's a first install)
    if [ -f "${BACKUP_DIR}/.VERSION" ]; then
        echo "Update done: restoring user config files now!"
        find ${BACKUP_DIR} -type f -regex '.*\.\(cfg\|conf\)' | xargs cp -ft ${KLIPPER_CONFIG_PATH}/
    else
        echo "New installation detected: default config templates will be set in place!"
        cp -fa ${GIT_REPO_PATH}/user_templates/* ${KLIPPER_CONFIG_PATH}/
    fi

    # CHMOD the scripts to be sure they are all executables (Git should keep the modes on files but it's to be sure)
    chmod +x ${GIT_REPO_PATH}/install.sh
    for file in graph_vibrations.py plot_graphs.sh; do
        chmod +x ${GIT_REPO_PATH}/scripts/$file
    done

    # Create the config version tracking file in the user config directory
    git -C ${GIT_REPO_PATH} rev-parse HEAD > ${KLIPPER_CONFIG_PATH}/.VERSION
}

# Step 5: restarting Klipper
function restart_klipper {
    echo "Restarting Klipper..."
    sudo systemctl restart klipper
}


BACKUP_DIR="${BACKUP_PATH}/klipper_$(date +'%Y%m%d%H%M%S')"

# Run steps
preflight_checks
check_download
backup_config
install_config
restart_klipper

echo "Everything is ok, Frix-x config installed and up to date!"
