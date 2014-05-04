#!/bin/bash
CWD=`echo $0 | sed 's/\(.*\)\/calculate_perf_data.*/\1/'`
VIDFILE=''
ADLISTFILE=''
LOGFILE=''
ROUTERS=''
HOPCOUNT=0
PERFFILE=/tmp/.perffile

DATA=0x0
ARP_REQUEST=0x01
ARP_REPLY=0x02
R_ARP_REQUEST=0x03
R_ARP_REPLY=0x04
ECHO_REQUEST=0x0500
ECHO_REPLY=0x0600
STORE_REQUEST=0x0700
STORE_REPLY=0x0800
SWITCH_REGISTRATION_REQUEST=0x0900
SWITCH_REGISRATION_REPLY=0x0A00
RDV_PUBLISH=0x1000
RDV_QUERY=0x2000
RDV_REPLY=0x3000

function usage {
    echo "$0 -h -? -f <logfile> -v <vidfile>"
    echo "-h -?: help: print this message"
    echo "-f: file: specify log file to parse"
    echo "-v: vid: specify vid file to parse"
    echo "-a: adlist: specify adlist file to parse"
}

function display_data_packet_count {
    banner "Total data packet count"
    npackets=`cat $PERFFILE | grep "INJECT" | wc -l`
    echo "Found $npackets data packets injected into the network"
}

function display_hop_count {
    banner "Total hop count"
    # All packets
    echo "Found $HOPCOUNT hops through network"

    # For each packet type:
    banner "Hops by packet type"
    display_hop_count_pt $DATA "DATA"
    display_hop_count_pt $ARP_REQUEST "ARP_REQUEST"
    display_hop_count_pt $ARP_REPLY "ARP_REPLY"
    display_hop_count_pt $R_ARP_REQUEST "R_ARP_REQUEST"
    display_hop_count_pt $R_ARP_REPLY "R_ARP_REPLY"
    display_hop_count_pt $ECHO_REQUEST "ECHO_REQUEST"
    display_hop_count_pt $ECHO_REPLY "ECHO_REPLY"
    display_hop_count_pt $STORE_REQUEST "STORE_REQUEST"
    display_hop_count_pt $STORE_REPLY "STORE_REPLY"
    display_hop_count_pt $SWITCH_REGISTRATION_REQUEST "SWITCH_REGISTRATION_REQUEST"
    display_hop_count_pt $SWITCH_REGISRATION_REPLY "SWITCH_REGISRATION_REPLY"
    display_hop_count_pt $RDV_PUBLISH "RDV_PUBLISH"
    display_hop_count_pt $RDV_QUERY "RDV_QUERY"
    display_hop_count_pt $RDV_REPLY "RDV_REPLY"
}


function display_hop_count_for_each_router {
    banner "Hops for each router"
    routers=`cat $VIDFILE | awk '{ print $1 }'`
    for router in $routers; do
        npackets=`cat $PERFFILE | grep "ROUTE" | grep $router | wc -l`
        utilization=`fmt_percentage $npackets $HOPCOUNT`
        printf "Found %4d packets passed through router %s; %6s of traffic\n" $npackets $router $utilization
    done
}

function display_link_traffic_count {
    banner "Traffic on each link"
    srcs=`cat $ADLISTFILE | awk '{ print $1 }'`
    for src in $srcs; do
        dsts=`cat $ADLISTFILE | grep ^$src | sed s/$src//g | tr -d '\n'`
        for dst in $dsts; do
            npackets=`cat $PERFFILE | grep "ROUTE" | grep $src\| | grep $dst | wc -l`
            if [ $npackets -eq 0 ]; then
                continue
            fi
            utilization=`fmt_percentage $npackets $HOPCOUNT`
            printf "%s -> %s %5d packets; %6s of traffic\n" $src $dst $npackets $utilization
        done
    done
}

function display_loss_count {
    banner "Packet loss counts"
    drop_count=`cat $PERFFILE | grep "DROP" | wc -l`
    drop_perc=`fmt_percentage $drop_count $HOPCOUNT`
    printf "Dropped %4d packets; %6s of traffic\n" $drop_count $drop_perc
}

function set_hop_count {
    HOPCOUNT=`cat $PERFFILE | grep "ROUTE" | wc -l`
}

# Args: $1: Packet Type
#       $2: Packet Type String
function display_hop_count_pt {
    ptype=$1
    ptype_str=$2
    npackets=`cat $PERFFILE | grep "ROUTE" | grep $ptype | wc -l`
    if [ $npackets -ne 0 ]; then
        utilization=`fmt_percentage $npackets $HOPCOUNT`
        printf "Found %4d %-11s packet hops through network; %6s of traffic\n" $npackets $ptype_str $utilization
    fi
}

# Args: $1: Message
function banner {
    echo ""
    printf "##### %-25s #####\n" "$1"
}

# Args: $1: X
#       $2: Y
# Display percentage (x/y)*100
function fmt_percentage {
    percent=$(( $1 * 10000 / $2 ))
    perc_hi=$(( percent / 100 ))
    perc_lo=$(( percent % 100 ))
    printf "%2d.%2.2d%%\n" $perc_hi $perc_lo
}

#Parse command line options
while getopts "hf:v:a:" arg; do
    case $arg in
        f)
            LOGFILE=$OPTARG
            if [ ! -f $LOGFILE ]; then
                echo "Could not find log file specified!"
                exit 1
            else
                echo "Reading in $LOGFILE"
            fi
            ;;
        v)
            VIDFILE=$OPTARG
            if [ ! -f $VIDFILE ]; then
                echo "Could not find log file specified!"
                exit 1
            else
                echo "Reading in $VIDFILE"
            fi
            ;;
        a)
            ADLISTFILE=$OPTARG
            if [ ! -f $ADLISTFILE ]; then
                echo "Could not find log file specified!"
                exit 1
            else
                echo "Reading in $ADLISTFILE"
            fi
            ;;
        h)
            usage
            exit 0
            ;;
    esac
done

if [ "$LOGFILE" == "" -o "$VIDFILE" == "" -o "$ADLISTFILE" == "" ]; then
    echo "Must specify log, vid, and adlist files!"
    exit 1
fi



#main
#parse down log file to just the relevant bits
cat $LOGFILE | grep "\[PERF_DATA\]" > $PERFFILE

#display performance data
set_hop_count
display_data_packet_count
display_hop_count
display_hop_count_for_each_router
display_link_traffic_count
display_loss_count

#cleanup
rm $PERFFILE