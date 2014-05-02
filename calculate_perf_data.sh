#!/bin/bash
cwd=`echo $0 | sed 's/\(.*\)\/calculate_perf_data.*/\1/'`
adlist=''
logfile=''
routers=''

function usage {
    echo "$0 -h -? -f <logfile> -a <adlist>"
    echo "-h -?: help: print this message"
    echo "-f: file: specify input file to parse"
    echo "-a: adlist: specify adlist file to parse"
}

function count_packets_for_each_router {
    routers=`cat $adlist`
    for router in $routers; do
        npackets=`cat $logfile | grep "\[PERF_DATA\]" | grep $router | wc -l`
        echo -e "Counted $npackets\tpackets passed through router $router"
    done
}

function count_packets {
    npackets=`cat $logfile | grep "\[PERF_DATA\]" | wc -l`
    echo "Found $npackets packets routed through network"
}

#Parse command line options
while getopts "hf:a:" arg; do
    case $arg in
        f)
            logfile=$OPTARG
            if [ ! -f $logfile ]; then
                echo "Could not find log file specified!"
                exit 1
            else
                echo "Reading in $logfile"
            fi
            ;;
        a)
            adlist=$OPTARG
            if [ ! -f $adlist ]; then
                echo "Could not find log file specified!"
                exit 1
            else
                echo "Reading in $adlist"
            fi
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done

if [ "$logfile" == "" -o "$adlist" == "" ]; then
    echo "Must specify logfile and adlist!"
    exit 1
fi

#main
count_packets
count_packets_for_each_router