#!/bin/bash
CWD=`echo $0 | sed 's/\(.*\)\/calculate_perf_data.*/\1/'`
VIDFILE=''
ADLISTFILE=''
LOGFILE=''
ROUTERS=''
DATACOUNT=0
CTRLCOUNT=0
HOPCOUNT=0
PERFFILE=/tmp/.perffile
TIME0=0
TIME_FINAL=0

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

function display_packet_count {
    # All data packets
    banner "Total data packet count"
    echo "Found $DATACOUNT data packets injected into the network"

    # All control packets
    banner "Total control packet count"
    echo "Found $CTRLCOUNT control packets injected into the network"

    # For each packet type:
    banner "Packets by type"
    display_count_pt $DATA "DATA"
    display_count_pt $ARP_REQUEST "ARP_REQUEST"
    display_count_pt $ARP_REPLY "ARP_REPLY"
    display_count_pt $R_ARP_REQUEST "R_ARP_REQUEST"
    display_count_pt $R_ARP_REPLY "R_ARP_REPLY"
    display_count_pt $ECHO_REQUEST "ECHO_REQUEST"
    display_count_pt $ECHO_REPLY "ECHO_REPLY"
    display_count_pt $STORE_REQUEST "STORE_REQUEST"
    display_count_pt $STORE_REPLY "STORE_REPLY"
    display_count_pt $SWITCH_REGISTRATION_REQUEST "SWITCH_REGISTRATION_REQUEST"
    display_count_pt $SWITCH_REGISRATION_REPLY "SWITCH_REGISRATION_REPLY"
    display_count_pt $RDV_PUBLISH "RDV_PUBLISH"
    display_count_pt $RDV_QUERY "RDV_QUERY"
    display_count_pt $RDV_REPLY "RDV_REPLY"
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
    total_pkt_count=$(( DATACOUNT + CTRLCOUNT ))
    drop_count=`cat $PERFFILE | grep "DROP" | wc -l`
    drop_perc=`fmt_percentage $drop_count $total_pkt_count`
    printf "Dropped %4d packets; %6s of traffic\n" $drop_count $drop_perc
}

function display_initial_convergence_time {
    banner "Initial convergence time"
    first_data_pkt=`cat $PERFFILE | grep "INJECT" | head -1 | awk '{ printf $2 }'`
    first_data_pkt_time=`fmt_time $first_data_pkt`
    printf "System injected first data packet after %s sec.\n" $first_data_pkt_time
    last_ctrl_pkt=`cat $PERFFILE | grep "CREATE" | grep "$RDV_REPLY" | tail -1 | awk '{ printf $2 }'`
    last_ctrl_pkt_time=`fmt_time $last_ctrl_pkt`

    last_ctrl_pkt_line_num=`cat $PERFFILE | grep -n "CREATE" | grep "$RDV_REPLY" | tail -1 | sed 's/:/ /g' | awk '{ printf $1 }'`
    num_ctrl_pkts_before_line_num=`head -$last_ctrl_pkt_line_num $PERFFILE | grep "CREATE" | wc -l`

    printf "System injected last RDV_REPLY packet at %s sec, found %d ctrl packets up to that point\n" $last_ctrl_pkt_time $num_ctrl_pkts_before_line_num
}

function display_failure_convergence_times {
    banner "Failure convergence time"
    fail_count=`cat $PERFFILE | grep "NODE_FAIL" | wc -l`
    if [ $fail_count -eq 0 ]; then
        echo "No node failures detected."
        return
    fi
    for idx in $(seq 0 $(( fail_count - 1 ))); do
        fail_node=`cat $PERFFILE | grep "NODE_FAIL" | tail -$(( fail_count - idx )) | head -1  | awk '{ printf $3 }'`
        fail_time_str=`cat $PERFFILE | grep "NODE_FAIL" | tail -$(( fail_count - idx )) | head -1  | awk '{ printf $2 }'`
        fail_time=`fmt_time $fail_time_str`
        printf "Failure of %s at %s sec into run\n" $fail_node $fail_time
    done
}

function display_rdv_reply_times {
    banner "RDV_REPLY packets"
    times=''
    rdv_reply_pkts=`cat $PERFFILE | grep "CREATE" | grep "$RDV_REPLY" | awk '{ print $2_ }' | sed 's/_/ /g'`
    for pkt in $rdv_reply_pkts; do
        rdv_reply_time=`fmt_time $pkt`
        echo "RDV_REPLY message after $rdv_reply_time sec"
        # times=`echo $times $rdv_reply_time`
    done
    # echo $times
}

function set_data_count {
    DATACOUNT=`cat $PERFFILE | grep "INJECT" | wc -l`
}

function set_ctrl_count {
    CTRLCOUNT=`cat $PERFFILE | grep "CREATE" | wc -l`
}

function set_hop_count {
    HOPCOUNT=`cat $PERFFILE | grep "ROUTE" | wc -l`
}


# Args: $1: Packet Type
#       $2: Packet Type String
function display_count_pt {
    ptype=$1
    ptype_str=$2
    npackets=`cat $PERFFILE | grep "CREATE" | grep $ptype | wc -l`
    if [ $npackets -ne 0 ]; then
        utilization=`fmt_percentage $npackets $CTRLCOUNT`
        printf "Found %4d %-11s packet hops through network; %6s of all control packets\n" $npackets $ptype_str $utilization
    fi
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

# Args: $1: Time from PERFFILE
function fmt_time {
    time_sec=`echo $1 | tr '.' ' ' | awk '{ printf $1 }'`
    time_msec=`echo $1 | tr '.' ' ' | awk '{ printf $2 }' | sed 's/0\([0-9]\)/\1/g'`
    time=`printf "%d.%2.2d" $time_sec $time_msec`
    time_difference $time $TIME0
}

function set_times {
    time0_sec=`cat $PERFFILE | head -1 | tr '.' ' ' | awk '{ printf $2 }'`
    time0_msec=`cat $PERFFILE | head -1 | tr '.' ' ' | awk '{ printf $3 }'`
    TIME0=`printf "%d.%2.2d" $time0_sec $time0_msec`
    time_final_sec=`cat $PERFFILE | tail -1 | tr '.' ' ' | awk '{ printf $2 }'`
    time_final_msec=`cat $PERFFILE | tail -1 | tr '.' ' ' | awk '{ printf $3 }'`
    TIME_FINAL=`printf "%d.%2.2d" $time_final_sec $time_final_msec`
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

# Args: $1: time_a
#       $4: time_b
# Display timeA - timeB
function time_difference {
    echo "${1}-${2}" | bc
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
sort $LOGFILE | grep "^\[PERF_DATA\]" | grep "\[PERF_END\]$" | grep -v "  " > $PERFFILE

#Set globals with some stats which will be used in various displays
set_times
set_data_count
set_ctrl_count
set_hop_count

# Display run time
t=`time_difference $TIME_FINAL $TIME0`
printf "\nNetwork ran for %s sec.\n" $t

#display performance data
display_packet_count
display_hop_count
display_hop_count_for_each_router
display_link_traffic_count
display_loss_count
display_rdv_reply_times
display_initial_convergence_time
display_failure_convergence_times

# #cleanup
# rm $PERFFILE
