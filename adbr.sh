#!/bin/bash

# =============================================================================
# Definitions
# =============================================================================

VERSION="0.1"

# Colors for output messages.
G=`tput setaf 2`
Y=`tput setaf 3`
R=`tput setaf 1`
E=`tput sgr0`

# ID of the recording process. 0 if not recording.
RECORDING_PROCESS=0

# Path to the temporary file on the device 
# in which we initially save the recording.
TEMP_FILE="/sdcard/adbr_temp.mp4"

# Default output directory, can be changed later 
# by -o specified by the user.
OUTPUT_DIR="$HOME/adbr-outputs"

# When called, starts recording from the ADB.
start_recording() {
    adb shell screenrecord $TEMP_FILE &
    RECORDING_PROCESS=$!
    echo -ne "Recording..."
}

# When called, stops any ongoing recording process.
stop_recording() {
    # Kill the ongoing recording process.
    kill -9 $RECORDING_PROCESS &>/dev/null
    wait $RECORDING_PROCESS &>/dev/null
    RECORDING_PROCESS=0

    # Generate filename for the recorded video.
    FILENAME="adbr_$(date +"%Y_%m_%d_%H_%M_%S").mp4"

    # Once the recording is done, it takes some time for adb to process the 
    # video, thus we loop until the video is ready and then save it.
    until `ffmpeg -v error -i \$OUTPUT_DIR/\$FILENAME -f null - 2> /dev/null`
    do
        adb pull $TEMP_FILE $OUTPUT_DIR/$FILENAME &> /dev/null
    done

    # Finally, remove the temporary file from the device and mark as done.
    adb shell rm $TEMP_FILE
    echo -e "${Y}${FILENAME}${G}\t[DONE]${E}"
}

# Prints usage instructions.
print_help() {
    cat << EOF
Usage: adbr [-o <output_dir>][-h][-v]

-o Output directory for the recordings
-h Show help
-v Show current version
EOF
}

# Prints current script version.
print_version() {
    echo $VERSION
}

# Reads a single character from the user input.
# Pressed character is not displayed in a terminal.
read_char() {
    stty -icanon -echo
    eval "$1=\$(dd bs=1 count=1 2>/dev/null)"
    stty icanon echo
}

# =============================================================================
# Run
# =============================================================================

# Print welcome message.
echo -e "${G}Android Debug Bridge Recorder (adbr)${E}"

# Read input flags and arguments.
while getopts ":o:hv" opt; do
    case $opt in
        h)
            print_help
            exit 0
            ;;
        o)
            OUTPUT_DIR=$OPTARG
            ;;
        v)
            print_version
            exit 0
            ;;
        \?)
            echo -e "${R}Invalid option, use -h to see the usage.${E}"
            exit 1
            ;;
        :)
            echo -e "${R}Option -$OPTARG requires an argument, use -h " \
                "to see the usage.${E}"
            exit 1
            ;;
    esac
done


# Try to create an output directory.
if mkdir -p $OUTPUT_DIR
then
    # Resolve output directory to full path.
    OUTPUT_DIR=$(cd ${OUTPUT_DIR} && pwd)
    echo "Output directory: ${OUTPUT_DIR}"
else
    echo "${R}Unable to create specified output directory.${E}"
fi

# Print usage directions.
echo -e "${Y}Press any key to start/stop recording, 'q' to exit.${E}"

# Read characters and perform necessary recording logic.
while true
do
    read_char INPUT
    if [[ $INPUT == 'q' ]]
    then
        if [[ "$RECORDING_PROCESS" != "0" ]]
        then
            stop_recording
        fi
        echo -e "${G}Closing adbr. Your files are saved at: ${OUTPUT_DIR}.${E}"
        exit 0
    else
        if [[ "$RECORDING_PROCESS" != "0" ]]
        then
            stop_recording
        else
            start_recording
        fi
    fi
done
