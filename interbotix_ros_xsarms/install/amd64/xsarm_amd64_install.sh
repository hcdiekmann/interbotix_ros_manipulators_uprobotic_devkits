#!/usr/bin/env bash

# USAGE: ./xsarm_amd64_install.sh [-h][-d DISTRO][-p PATH][-n]
#
# Install the Interbotix X-Series Arms packages and their dependencies for usage with the UP robotic development kit.

ROS_CORE_REPO_URL="https://github.com/hcdiekmann/interbotix_ros_core_uprobotic_devkits"
ROS_TOOLBOX_REPO_URL="https://github.com/hcdiekmann/interbotix_ros_toolboxes_uprobotic_devkits"
ROS_MANIPULATOR_REPO_URL="https://github.com/hcdiekmann/interbotix_ros_manipulators_uprobotic_devkits"

OFF='\033[0m'
RED='\033[0;31m'
GRN='\033[0;32m'
BLU='\033[0;34m'

BOLD=$(tput bold)
NORM=$(tput sgr0)

ERR="${RED}${BOLD}"
RRE="${NORM}${OFF}"

PROMPT="> "

ROS2_VALID_DISTROS=('galactic' 'humble' 'rolling')

FOCAL_VALID_DISTROS=('galactic')
JAMMY_VALID_DISTROS=('humble' 'rolling')

NONINTERACTIVE=false
DISTRO_SET_FROM_CL=false
INSTALL_PATH=~/interbotix_ws

_usage="${BOLD}USAGE: ./xsarm_amd64_install.sh [-h][-d DISTRO][-p PATH][-n]${NORM}

Install the Interbotix X-Series Arms packages and their dependencies for usage with the UP robotic development kit.

Options:

  -h              Display this help message and quit

  -d DISTRO       Install the ROS distro compatible with your Ubuntu version. Currently only galactic is supported 
                  with Ubuntu 20.04 with plans for humble on Ubuntu 22.04

  -p PATH         Sets the absolute install location for the Interbotix workspace. If not specified,
                  the Interbotix workspace directory will default to '~/interbotix_ws'.

  -n              Install all packages and dependencies without prompting. This is useful if
                  you're running this script in a non-interactive terminal like when building a
                  Docker image.

Examples:

  ./xsarm_amd64_install.sh ${BOLD}-h${NORM}
    This will display this help message and quit.

  ./xsarm_amd64_install.sh ${BOLD}-n${NORM}
    Skip prompts and install all packages and dependencies.

  ./xsarm_amd64_install.sh ${BOLD}-d galactic${NORM}
    Install ROS2 Galactic assuming that your Ubuntu version is compatible.

  ./xsarm_amd64_install.sh ${BOLD}-d galactic -n${NORM}
    Install ROS2 Galactic and all packages and dependencies.

  ./xsarm_amd64_install.sh ${BOLD}-p ~/custom_ws${NORM}
    Installs the Interbotix packages under the '~/custom_ws' path."

function help() {
  # print usage
  cat << EOF
$_usage
EOF
}

# https://stackoverflow.com/a/8574392/16179107
function contains_element () {
  # check if an element is in an array
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

function failed() {
  # Log error and quit with a failed exit code
  echo -e "${ERR}[ERROR] $@${RRE}"
  echo -e "${ERR}[ERROR] Interbotix Installation Failed!${RRE}"
  exit 1
}

function validate_distro() {
  # check if chosen distro is valid and set ROS major version
  if contains_element $ROS_DISTRO_TO_INSTALL "${ROS2_VALID_DISTROS[@]}"; then
    ROS_VERSION_TO_INSTALL=2
    ROS_DISTRO_TO_INSTALL=$ROS_DISTRO_TO_INSTALL
    echo -e "${GRN}${BOLD}Chosen Version: ROS${ROS_VERSION_TO_INSTALL} $ROS_DISTRO_TO_INSTALL${NORM}${OFF}"
    return 0
  else
    failed "'$ROS_DISTRO_TO_INSTALL' is not a valid ROS Distribution. Choose one of: "${ROS2_VALID_DISTROS[@]}""
  fi
}

function check_ubuntu_version() {
 # check if the chosen distribution is compatible with the Ubuntu version
  case $UBUNTU_VERSION in

    20.04 )
      if contains_element $ROS_DISTRO_TO_INSTALL "${FOCAL_VALID_DISTROS[@]}"; then
        PY_VERSION=3
      else
        failed "Chosen ROS distribution '$ROS_DISTRO_TO_INSTALL' is not supported on Ubuntu ${UBUNTU_VERSION}."
      fi
      ;;

    22.04 )
      if contains_element $ROS_DISTRO_TO_INSTALL "${JAMMY_VALID_DISTROS[@]}"; then
        #PY_VERSION=3
        failed "Ubuntu 22.04 is currently not supported by the UP robotic devkit"
      else
        failed "Chosen ROS distribution '$ROS_DISTRO_TO_INSTALL' is not supported on Ubuntu ${UBUNTU_VERSION}."
      fi
      ;;

    *)
      failed "Something went wrong."
      ;;

  esac
}

function install_essential_packages() {
  # Install necessary core packages
  sudo apt -y install openssh-server curl
  if [ $ROS_VERSION_TO_INSTALL == 2 ]; then
    sudo pip3 install transforms3d
  fi
  if [ $PY_VERSION == 3 ]; then
    sudo apt -y install python3-pip
    python3 -m pip install modern_robotics
  else
    failed "Something went wrong."
  fi
}

function install_ros2() {
  # Install ROS 2
  if [ $(dpkg-query -W -f='${Status}' ros-$ROS_DISTRO_TO_INSTALL-desktop 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo -e "${GRN}Installing ROS 2 $ROS_DISTRO_TO_INSTALL desktop...${OFF}"
    sudo apt install -y software-properties-common
    sudo add-apt-repository universe
    sudo apt install -y curl gnupg lsb-release
    sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(source /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
    sudo apt update
    sudo apt install -y ros-$ROS_DISTRO_TO_INSTALL-desktop
    if [ -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
      sudo rm /etc/ros/rosdep/sources.list.d/20-default.list
    fi
    echo "source /opt/ros/$ROS_DISTRO_TO_INSTALL/setup.bash" >> ~/.bashrc
    sudo apt -y install python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool build-essential python3-colcon-common-extensions
    sudo rosdep init
    rosdep update
  else
    echo "ros-$ROS_DISTRO_TO_INSTALL-desktop-full is already installed!"
  fi
  source /opt/ros/$ROS_DISTRO_TO_INSTALL/setup.bash

  if [ "$INSTALL_PERCEPTION" = true ]; then
    # Install apriltag ROS Wrapper, no official Apriltag ROS 2 package yet
    APRILTAG_WS=~/apriltag_ws
    if [ ! -d "$APRILTAG_WS/src" ]; then
      echo -e "${GRN}Installing Apriltag ROS Wrapper...${OFF}"
      mkdir -p $APRILTAG_WS/src
      cd $APRILTAG_WS/src
      git clone https://github.com/Interbotix/apriltag_ros.git -b ros2-port
      cd $APRILTAG_WS
      rosdep update --include-eol-distros
      rosdep install --from-paths src --ignore-src -r -y
      colcon build
      if [ $? -eq 0 ]; then
        echo -e "${GRN}${BOLD}Apriltag ROS Wrapper built successfully!${NORM}${OFF}"
      else
        failed "Failed to build Apriltag ROS Wrapper."
      fi
      echo "source $APRILTAG_WS/install/setup.bash" >> ~/.bashrc
    else
      echo "Apriltag ROS Wrapper already installed!"
    fi
    source $APRILTAG_WS/install/setup.bash
  fi

  # Install Arm packages
  if [ ! -d "$INSTALL_PATH/src" ]; then
    echo -e "${GRN}Installing ROS packages for the Interbotix Arm...${OFF}"
    mkdir -p $INSTALL_PATH/src
    cd $INSTALL_PATH/src
    git clone $ROS_CORE_REPO_URL -b $ROS_DISTRO_TO_INSTALL
    git clone $ROS_MANIPULATOR_REPO_URL -b $ROS_DISTRO_TO_INSTALL
    git clone $ROS_TOOLBOX_REPO_URL -b $ROS_DISTRO_TO_INSTALL
    # TODO(lsinterbotix) remove below when moveit_visual_tools is available in apt repo
    git clone https://github.com/ros-planning/moveit_visual_tools.git -b ros2
    if [ "$INSTALL_PERCEPTION" = true ]; then
      rm interbotix_ros_manipulators_uprobotic_devkits/interbotix_ros_xsarms/interbotix_xsarm_perception/COLCON_IGNORE
      rm interbotix_ros_toolboxes_uprobotic_devkits/interbotix_perception_toolbox/COLCON_IGNORE
    fi
    rm interbotix_ros_toolboxes_uprobotic_devkits/interbotix_common_toolbox/interbotix_moveit_interface/COLCON_IGNORE
    rm interbotix_ros_toolboxes_uprobotic_devkits/interbotix_common_toolbox/interbotix_moveit_interface_msgs/COLCON_IGNORE
    cd interbotix_ros_core_uprobotic_devkits
    git submodule update --init interbotix_ros_xseries/dynamixel_workbench_toolbox
    git submodule update --init interbotix_ros_xseries/interbotix_xs_driver
    cd ..
    if [ "$INSTALL_MATLAB" = true ]; then
      cd interbotix_ros_toolboxes_uprobotic_devkits
      git submodule update --init third_party_libraries/ModernRobotics
      cd ..
    fi
    cd interbotix_ros_core_uprobotic_devkits/interbotix_ros_xseries/interbotix_xs_sdk
    sudo cp 99-interbotix-udev.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules && sudo udevadm trigger
    cd $INSTALL_PATH
    rosdep update --include-eol-distros
    rosdep install --from-paths src --ignore-src -r -y
    colcon build
    if [ $? -eq 0 ]; then
      echo -e "${GRN}${BOLD}Interbotix Arm ROS Packages built successfully!${NORM}${OFF}"
    else
      failed "Failed to build Interbotix Arm ROS Packages."
    fi
    echo "source $INSTALL_PATH/install/setup.bash" >> ~/.bashrc
  else
    echo "Interbotix Arm ROS packages already installed!"
  fi
  source $INSTALL_PATH/install/setup.bash
}

function setup_env_vars() {
  # Setup Environment Variables
  if [ -z "$ROS_IP" ]; then
    echo -e "${GRN}Setting up Environment Variables...${OFF}"
    echo "# Interbotix Configurations" >> ~/.bashrc
    echo 'export ROS_IP=$(echo `hostname -I | cut -d" " -f1`)' >> ~/.bashrc
    echo -e 'if [ -z "$ROS_IP" ]; then\n\texport ROS_IP=127.0.0.1\nfi' >> ~/.bashrc
  else
    echo "Environment variables already set!"
  fi
}

# parse command line arguments
while getopts 'hnd:p:' OPTION;
do
  case "$OPTION" in
    h) help && exit 0;;
    n) NONINTERACTIVE=true;;
    d) ROS_DISTRO_TO_INSTALL="$OPTARG" && DISTRO_SET_FROM_CL=true && validate_distro;;
    p) INSTALL_PATH="$OPTARG";;
    *) echo "Unknown argument $OPTION" && help && exit 0;;
  esac
done
shift "$(($OPTIND -1))"

if ! command -v lsb_release &> /dev/null; then
  sudo apt update
  sudo apt-get install -y lsb-release
fi

UBUNTU_VERSION="$(lsb_release -rs)"

# set default ROS distro before reading clargs
if [ "$DISTRO_SET_FROM_CL" = false ]; then
  if [ $UBUNTU_VERSION == "20.04" ]; then
    ROS_DISTRO_TO_INSTALL="galactic"
  elif [ $UBUNTU_VERSION == "22.04" ]; then
    ROS_DISTRO_TO_INSTALL="humble"
  else
    echo -e "${BOLD}${RED}Unsupported Ubuntu verison: $UBUNTU_VERSION.${NORM}${OFF}"
    failed "The UP devkit arm only works with Ubuntu 20.04 Focal, or 22.04 Jammy on your hardware."
  fi
fi

check_ubuntu_version

if [ "$NONINTERACTIVE" = false ]; then
  # prompt for perecption packages
  echo -e "${BLU}${BOLD}Install the Interbotix Perception packages? This will include the RealSense and AprilTag packages as dependencies.\n$PROMPT${NORM}${OFF}\c"
  read -r resp
  if [[ $resp == [yY] || $resp == [yY][eE][sS] ]]; then
    INSTALL_PERCEPTION=true
  else
    INSTALL_PERCEPTION=false
  fi

  echo -e "${BLU}${BOLD}Install the MATLAB-ROS API?\n$PROMPT${NORM}${OFF}\c"
  read -r resp
  if [[ $resp == [yY] || $resp == [yY][eE][sS] ]]; then
    INSTALL_MATLAB=true
  else
    INSTALL_MATLAB=false
  fi

  echo -e "${BLU}${BOLD}INSTALLATION SUMMARY:"
  echo -e "\tROS Distribution:           ROS ${ROS_VERSION_TO_INSTALL} ${ROS_DISTRO_TO_INSTALL}"
  echo -e "\tInstall Perception Modules: ${INSTALL_PERCEPTION}"
  echo -e "\tInstall MATLAB Modules:     ${INSTALL_MATLAB}"
  echo -e "\tInstallation path:          ${INSTALL_PATH}"
  echo -e "\nIs this correct?\n${PROMPT}${NORM}${OFF}\c"
  read -r resp

  if [[ $resp == [yY] || $resp == [yY][eE][sS] ]]; then
    :
  else
    help && exit 0
  fi
else
  INSTALL_PERCEPTION=true
  INSTALL_MATLAB=true
fi

echo -e "\n\n"
echo -e "${GRN}${BOLD}**********************************************${NORM}${OFF}"
echo ""
echo -e "${GRN}${BOLD}            Starting installation!            ${NORM}${OFF}"
echo -e "${GRN}${BOLD}   This process may take around 15 Minutes!   ${NORM}${OFF}"
echo ""
echo -e "${GRN}${BOLD}**********************************************${NORM}${OFF}"
echo -e "\n\n"

sleep 4
start_time="$(date -u +%s)"

echo -e "\n# Interbotix Configurations" >> ~/.bashrc

# Update the system
sudo apt update && sudo apt -y upgrade
sudo apt -y autoremove

install_essential_packages

install_ros2

setup_env_vars

end_time="$(date -u +%s)"
elapsed="$(($end_time-$start_time))"

echo -e "${GRN}Installation complete, took $elapsed seconds in total.${OFF}"
echo -e "${GRN}NOTE: Remember to reboot the computer before using the robot!${OFF}"
