#!/bin/bash
# Global Variables
# ============================
DIALOG=whiptail                  # Tool used to show interactive prompt
declare -A componentMap          # Mapping used to map short names to full wacom names
devices=()
parameters=()
parameterList=()
device_count=0
parameter_count=0


# Initialization
# =============================
# Initial Configuration Loop, Loads supported devices into array for access

first=true
i=0
while read -r line
do
    fields=($line)

    i=$((i + 1))
    devices[$i]="\"${fields[5]}\""

    i=$((i + 1))
    devices[$i]="\"${fields[*]:0:6}\""

    componentMap["\"${fields[5]}\""]="\"${fields[*]:0:6}\""

    if [ "$first" = true ]
    then
        i=$((i + 1))
        devices[$i]="ON"
        first=false
    else
        i=$((i + 1))
        devices[$i]="OFF"
    fi
done <<< "$(xsetwacom --list)"
device_count=$i

if [ "$i" -eq "3" ]
then
    $DIALOG --title "Wacom Tablet Customizer" --msgbox "No Wacom Devices seem to be connected" 10 50
#    exit -1
fi

first=true
i=0
while read -r line
do
    fields=($line)
    i=$((i + 1))
    parameters[$i]="$i"
    parameterList[$i]="\"${fields[0]}\""

    i=$((i + 1))
    parameters[$i]="\"${fields[0]}\""

done <<< "$(xsetwacom --list parameters)"
parameter_count=$i



# Functions
# =============================

function save_ifs {
    # save IFS to a variable    
    old_IFS=${IFS-$' \t\n'}
    #set IFS to a newline
    IFS=";"
}

function restore_ifs {
    IFS=old_IFS
}




function query_for_component {
    local width=60
    local height=$((device_count + 10))
    local lineheight=$device_count


    local cmd=($DIALOG --title "Wacom Tablet Customizer" --radiolist "Select Component to Customize" $height $width $lineheight) 


    save_ifs
    local choice=$("${cmd[@]}" "${devices[@]}" 2>&1 >/dev/tty)

    restore_ifs
    echo "$choice"
}

function query_for_parameter {
    local width=60
    local height=30
    local lineheight=20
    local fin=false
    local istart=1
    local choice=""
    local cmd=($DIALOG --title "Wacom Tablet Customizer" --menu "Select Parameter to Modify") 

    save_ifs
    choice=$("${cmd[@]}" "$height" "$width" "$lineheight" "${parameters[@]}" 2>&1 >/dev/tty)

    restore_ifs
    echo "$choice"
}

function read_parameter_index {
    local index=$($DIALOG --title "Wacom Tablet Customizer" --inputbox "Edit/View which parameter (usually somewhere around 1-10)?" 8 78 1 3>&1 1>&2 2>&3)
    echo $index
}

function read_mapping {
    if [[ $1 && $2 ]]
    then
        local value=$(xsetwacom --get "$1" "$2" "$3")
        local map=$($DIALOG --title "Wacom Tablet Customizer" --inputbox "Map to what commands (prev: $value)? (i.e undo might be  ctrl +alt z -alt)?" 8 78 "1" 3>&1 1>&2 2>&3)
        if [[ $map ]]
        then
            echo $map
        else
            echo $value
        fi
    else
        local map=$($DIALOG --title "Wacom Tablet Customizer" --inputbox "Map to what commands? (i.e undo might be  ctrl +alt z -alt)?" 8 78 1 3>&1 1>&2 2>&3)
        echo $map
    fi
}



function extract_quoted_string {
    echo "$1" | sed -n 's/^.*"\([^"]*\)".*$/\1/p'
}



# Main
# =============================

config=""
hasFinished=false

while [ "$hasFinished" != "true" ]
do
    hasFinished=true
    component=$(query_for_component)
    if [ $? -ne 0 ]
    then 
        hasFinished=false
        continue
    fi
    parameter=$(query_for_parameter)
    if [ $? -ne 0 ]
    then 
        hasFinished=false
        continue
    fi

    component=${componentMap[$component]}
    parameter=${parameterList[$parameter]}
    component=$(extract_quoted_string "$component") 
    parameter=$(extract_quoted_string "$parameter")
 

    index=$(read_parameter_index)
    if [ $? -ne 0 ]
    then 
        hasFinished=false
        continue
    fi
    mapping=$(read_mapping "$component" "$parameter" "$index")

    if [ $? -ne 0 ] 
    then 
        hasFinished=false
        continue
    fi

    com=("xsetwacom" "--set" "$component" "${parameter}" ${index} "${mapping}")

    temp_file=$(mktemp)

    "${com[@]}"  &> $temp_file
    result=$(cat $temp_file)
    rm ${temp_file}

    if [[ $result ]]
    then
        echo "Result: $result"
        $DIALOG --title "Wacom Tablet Customizer" --msgbox "Command \"$com\" returned result: $result" 10 50
    else
        config+=$(echo $(printf "'%s' " "${com[@]}"))
        config+="\n"
    fi

    if ($DIALOG --title "Wacom Tablet Customizer" --yesno "Add more mappings?(Y/n)" 8 78 1 3>&1 1>&2 2>&3) 
    then
       hasFinished=false 
    fi
done


if ($DIALOG --title "Wacom Tablet Customizer" --yesno "Save config to file (usually, Wacom resets the settings as soon as you unplug your tablet, so it's a good idea to keep the setup in a script)? WILL OVERWRITE IF EXISTS" 8 78 1 3>&1 1>&2 2>&3) 
then
    filename=$($DIALOG --title "Wacom Tablet Customizer" --inputbox "Name of the config file?" 8 78 1 3>&1 1>&2 2>&3)
    echo -e $config > $filename
fi

