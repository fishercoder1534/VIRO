#!/bin/bash
cwd=`echo $0 | sed 's/\(.*\)\/calculate_perf_data.*/\1/'`
vidfile=''
logfile=''
routers=''

function usage {
    echo "$0 -h -? -f <logfile> -v <vidfile>"
    echo "-h -?: help: print this message"
    echo "-f: file: specify input file to parse"
    echo "-v: vidfile: specify vidfile file to parse"
}

function count_hops_for_each_router {
    routers=`cat $vidfile | awk '{ print $1 }'`
    for router in $routers; do
        npackets=`cat $logfile | grep "\[PERF_DATA\]" | grep $router | wc -l`
        echo -e "Counted $npackets\tpackets passed through router $router"
    done
}

function count_packets {
    npackets=`cat $logfile | grep "\[PERF_DATA\]" | grep "INJECT" | wc -l`
    echo "Found $npackets packets routed through network"
}

function count_hops {
    npackets=`cat $logfile | grep "\[PERF_DATA\]" | wc -l`
    echo "Found $npackets hops through network"
}

#Parse command line options
while getopts "hf:v:" arg; do
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
        v)
            vidfile=$OPTARG
            if [ ! -f $vidfile ]; then
                echo "Could not find log file specified!"
                exit 1
            else
                echo "Reading in $vidfile"
            fi
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done

if [ "$logfile" == "" -o "$vidfile" == "" ]; then
    echo "Must specify logfile and vidfile!"
    exit 1
fi

#main
count_packets
count_hops
count_hops_for_each_router