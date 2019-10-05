#!/bin/bash
#Script to identify your ISP neighbouring subnet and run masscan on it.

#Sets a bash 'relaxed strict' mode :P
set -eo pipefail
IFS=$'\n\t'

#Masscan dependency check
function run_check () {
    local deps=( "masscan" "xterm" "curl" "whois" )
    declare -i local dependency=0

    #Checks if there are any dependencies missing
    while (( $dependency != ${#deps[*]} )) ; do
        if [ -z $(which masscan) ] ; then
            missdeps[$dependency]="masscan"
            dependency=$dependency+1 ; break
        elif [ -z $(which xterm) ] ; then
            missdeps[$dependency]="xterm"
            dependency=$dependency+1 ; break
        elif [ -z $(which curl) ] ; then
            missdeps[$dependency]="curl"
            dependency=$dependency+1 ; break
        elif [ -z $(which whois) ] ; then
            missdeps[$dependency]="whois"
            dependency=$dependency+1 ; break
        fi
        dependency=$dependency+1 ; break
    done

    #If there are, install them using apt or exit
    if (( ${#missdeps[*]} != 0 )) ; then
        echo -e "Dependency '${missdeps[@]}' are missing!"
        read -p "Do you want to install? ['Y' to approve, any other key to exit] " tryinstall
            case $tryinstall in
            y|yes|Y) apt install ${missdeps[*]} && echo -e "\n\n-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\nDependencies installed, continuing with script!\n-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n\n" && sleep 1 ;;
            *) echo -e "Sure, but please install the packages manually in order for the script to work.\n" && exit 0 ;;
            esac
    fi
}

#Main function
function run_main () {
    if [ -z $configfile ] ; then #if theres no configfile, run
        echo "Found ${#provsubnets[*]} records in the WHOIS database:"
        PS3="Select desired subnet [1-${#provsubnets[@]}]: "
        select option in ${provsubnets[*]}; do
            while (( $REPLY <= ${#provsubnets[*]} )); do #while replies are valid, ask for ports and run
                read -p "Ports (comma separated): " ports
                echo "Searching $option for ports $ports" > mn$(date '+%y%m%d-%H%M%S').log
                xterm -T "Status" -e tail -f $(ls -tr mn*.log | tail -1) &
                masscan -p $ports $option >> $(ls -tr mn*.log | tail -1)
                kill $(pidof xterm) > /dev/null 2>&1
                echo -e "\nExecution complete. Results saved to $(ls -tr mn*.log | tail -1)\n"
                exit 0
            done
        done
    else #if configfile, use it
        echo -e "Using configuration file '$configfile'" > mn$(date '+%y%m%d-%H%M%S').log
        xterm -T "Status" -e tail -f $(ls -tr mn*.log | tail -1) &
        masscan -c $configfile >> $(ls -tr mn*.log | tail -1)
        kill $(pidof xterm) > /dev/null 2>&1
        echo -e "\nExecution complete. Results saved to $(ls -tr mn*.log | tail -1)\n"
        exit 0
    fi
}

#Help function
function run_help () {
    echo -e "\e[1mUsage: $ ./massneighbours\e[0m\nThis script parses your public IP address and queries the public WHOIS database to identify the related subnets. The script is interactive so no parameters are needed (unless you wish to specify an existing masscan configuration file, which can be done by using the \e[1m-c\e[0m switch)."
    exit 0
}

#Main script logic
run_check

if (( $# == 0 )) ; then
    mypubip=$(curl -s ifconfig.me/ip)
    provsubnets=( "$mypubip/24" $(whois $mypubip | grep "inetnum\|inetrev\|CIDR:" | cut -d ':' -f 2 | tr -d '[:blank:]') )
else
    case $1 in
        -c)
            if [ -z $2 ] ; then
                echo -e "\e[1mUsage: $ ./massneighbours -c <configfile>\e[0m\nConfig file switch detected but no config file specified.\nTo export from masscan, use \e[97m'masscan -p <ports> <subnet> --echo >> <configfile>'\e[0m"
                exit 0
            else
                configfile=$2
                run_main
            fi ;;
        *) run_help && exit 0 ;;
    esac
fi

run_main