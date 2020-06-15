#!/bin/bash
# bash is needed for easy regex tests

# This script can be used to check that you have all the required software installed
# to run the application with all the nodes. It is built upon the runner.sh script.

# If you have the the required software it will run the ros master and launch
# all the nodes that you wish to run.

# Before running this script make sure that you have read the instructions in
# README.md file found in the repository and created the ROS workspace in the
# right location.

# #######################################
# TODO: Implement option to use roslaunch
# TODO: Implement version checking for all the different required binaries
# #######################################


# Script settings
# ---------------

# When DEV is set to 0 open terminals for everything and dont suppress any output
DEV=0

# Array with all the required binaries
REQ_BIN=(poetry python catkin_make roscore rosparam rosrun)

# ROS package name
ROSPKG=konenako

# Array with all the required parameters that need to be set
REQ_PARAMS=(label_file model_file video_source)
# Default values
DEF_LABEL=ssd_mobilenet_v1_1_metadata_1.tflite
DEF_MODEL=mscoco_complete_labels
DEF_VIDEO=/dev/video0

# Available nodes
NODES=(camera object_detector qr_detector printer input)

# ---------------
# Misc variables
# ---------------
CATKIN_PWD="${PWD%/*/*}/devel"
PROJ_PWD=$(pwd)




# Run the script
# --------------


# Check that all required applications are installed
REQ_MET=0
echo "Checking for required software.."
echo ""
for b in ${REQ_BIN[@]}; do
    if [ -z $(which $b) ]; then
        echo "ERROR: $b is not installed!"
        REQ_MET=1
    fi
done

if [ "$REQ_MET" -ne 0 ]; then
    echo ""
    echo "You will need these programs installed before continuing."
    echo "Consult the Github page README for required versions"
    echo ""
    echo "Exiting.."
    exit 1
fi

echo "All requirements found, continuing"
echo


# Check for virtualenv
if [ ! -z "$POETRY_ACTIVE" ] || [ ! -z "$VIRTUAL_ENV" ]; then
    echo "You are in venv! Quit venv with the command: exit. Then run this script again."
    exit 2
fi


# (re)start roscore, requires pgrep to be installed
if [ $(pgrep roscore) ]; then
    echo "Roscore is running, restarting"
    kill $(pgrep roscore)
fi

if [ "$DEV" -eq 0 ]; then
    gnome-terminal --geometry 60x16 --title="Roscore" -- /bin/bash -c 'cd '${PROJ_PWD}'; roscore; bash' &
else
    roscore > /dev/null 2>&1 &
fi

# Wait until roscore master is running
sleep 2
echo "Master started"
echo

# Check that all required rosparams are set, if not ask user
# for value.
for p in ${REQ_PARAMS[@]}; do
    if [ ! "$(rosparam get $p)" ]; then
        # rosparam get prints an error message if param is not set..
        echo "You need to set this variable to continue:"
        
        # Suggest default values for label and model files, accept with empty input
        if [ "$p" = "label_file" ]; then
            read -p "Enter label file to use [$DEF_LABEL]: " label
            label=${label:-$DEF_LABEL}
            rosparam set $p $label
            if [ "$?" -ne 0 ]; then
                echo "Error setting parameter [$p], exiting.."
                exit 3
            fi
        elif [ "$p" = "model_file" ]; then
            read -p "Enter model file to use [$DEF_MODEL]: " model
            model=${model:-$DEF_MODEL}
            rosparam set $p $model
            if [ "$?" -ne 0 ]; then
                echo "Error setting parameter [$p], exiting.."
                exit 3
            fi
        elif [ "$p" = "video_source" ]; then
            read -p "Enter video source to use [$DEF_VIDEO]: " video
            video=${video:-$DEF_VIDEO}
            rosparam set $p $video
            if [ "$?" -ne 0 ]; then
                echo "Error setting parameter [$p], exiting.."
                exit 3
            fi
        else
            read -p "Enter value for the required parameter $p: " value
            rosparam set $p $value
            if [ "$?" -ne 0 ]; then
                echo "Error setting parameter [$p], exiting.."
                exit 3
            fi
        fi
    else
        echo "Param [$p] is set to the value: $(rosparam get $p)"
    fi
    echo
done
echo

# -------------------
# TODO: Ask user for other parameters and set them one by one until empty string..?
# -------------------


# Print all the set rosparameters, requires tr to be installed
# since many of the parameters set by roscore contains newlines
# and whitespaces.
# TODO: FIX string trimming to use only bash, maybe with parameter expansion?
if [ "$DEV" -eq 0 ] && [ "$(which tr)" ]; then
    echo "Set rosparameters:"

    for p in $(rosparam list); do
        echo "$p: $(rosparam get $p|tr -d '[:space:]')"
    done
fi
echo

# Run all the nodes
# TODO: dont open terminals for all nodes and dont append ;bash to the end so they close when DEV is not set
for node in ${NODES[@]}; do
    read -p "Do you wish to run the node: $node? " -n 1 -r
    echo # Newline
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Running node $node"        
        gnome-terminal --geometry 60x16 --title="$node" -- /bin/bash -c 'source '${CATKIN_PWD}'/setup.bash; cd '${PROJ_PWD}'; poetry run rosrun '${ROSPKG}' node_'${node}'.py; bash' &
    fi
    echo
done
