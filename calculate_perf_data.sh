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

function display_punt_count {
    banner "Punt counts"
    punt_count=`cat $PERFFILE | grep "PUNT" | wc -l`
    if [ $punt_count -eq 0 ]; then
        return
    fi
    #NO_FWD
    nf_count=`cat $PERFFILE | grep "PUNT" | grep "NO_FWD" | wc -l`
    nf_perc=`fmt_percentage $nf_count $punt_count`
    printf " %4d punts due to no forward; %6s of punts\n" $nf_count $nf_perc
    #NO_NH
    nnh_count=`cat $PERFFILE | grep "PUNT" | grep "NO_NH" | wc -l`
    nnh_perc=`fmt_percentage $nnh_count $punt_count`
    printf " %4d punts due to no nexthop; %6s of punts\n" $nnh_count $nnh_perc
    #NO_RECORD 
    nrc_count=`cat $PERFFILE | grep "PUNT" | grep "NO_RECORD" | wc -l`
    nrc_perc=`fmt_percentage $nrc_count $punt_count`
    printf " %4d punts due to no record; %6s of punts\n" $nrc_count $nrc_perc
}

function display_loss_count {
    banner "Packet loss counts"
    total_pkt_count=$(( DATACOUNT + CTRLCOUNT ))
    drop_count=`cat $PERFFILE | grep "DROP" | wc -l`
    drop_perc=`fmt_percentage $drop_count $total_pkt_count`
    printf "Dropped %4d packets; %6s of traffic\n" $drop_count $drop_perc
    
    if [ $drop_count -eq 0 ]; then
        return
    fi

    # Drop types:
    #NO_ROUTE
    nr_count=`cat $PERFFILE | grep "DROP" | grep "NO_ROUTE" | wc -l`
    nr_perc=`fmt_percentage $nr_count $drop_count`
    printf " %4d drops due to no route; %6s of drops\n" $nr_count $nr_perc
    #TTL_EXPIRE
    ttl_count=`cat $PERFFILE | grep "DROP" | grep "TTL_EXPIRE" | wc -l`
    ttl_perc=`fmt_percentage $ttl_count $drop_count`
    printf " %4d drops due to TTL expiration; %6s of drops\n" $ttl_count $ttl_perc
}

function display_convergence_times {
    banner "Convergence Times"
    rtmodify_count=`cat $PERFFILE | grep "RTMODIFY" | wc -l`
    if [ $rtmodify_count -eq 0 ]; then
        echo "No routing table modifications detected."
        return
    fi
    for idx in $(seq 0 $(( rtmodify_count - 1 ))); do
        rtmodify_line_num=`cat $PERFFILE | grep -n "RTMODIFY" | tail -$(( rtmodify_count - idx )) | head -1 | sed 's/:/ /g' | awk '{ printf $1 }'`
        rtmodify_time_str=`cat $PERFFILE | grep "RTMODIFY" | tail -$(( rtmodify_count - idx )) | head -1 | awk '{ printf $2 }'`
        rtmodify_time=`fmt_time $rtmodify_time_str`

        num_ctrl_pkts_before_line_num=`head -$rtmodify_line_num $PERFFILE | grep "CREATE" | wc -l`
        printf "Routing table modification at %-6s sec into run; found %4d ctrl packets thus far\n" $rtmodify_time $num_ctrl_pkts_before_line_num
    done
}


function display_failure_times {
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

function display_node_failures {
    banner "Detected node failures"
    fail_count=`cat $PERFFILE | grep "DELETE" | wc -l`
    if [ $fail_count -eq 0 ]; then
        echo "No node failures detected."
        return
    fi
    for idx in $(seq 0 $(( fail_count - 1 ))); do
        fail_node=`cat $PERFFILE | grep "DELETE" | tail -$(( fail_count - idx )) | head -1  | awk '{ printf $6 }'`
        fail_time_str=`cat $PERFFILE | grep "DELETE" | tail -$(( fail_count - idx )) | head -1  | awk '{ printf $2 }'`
        fail_time=`fmt_time $fail_time_str`
        printf "Detection of down link %s at %s sec into run\n" $fail_node $fail_time
    done
}


function display_packets_arrived {
    banner "Packets arrived at each destination"
    routers=`cat $VIDFILE | awk '{ print $1 }'`
    total_arrived=`cat $PERFFILE | grep "ARRIVED" | grep $DATA | wc -l`
    if [ $total_arrived -eq 0 ]; then
        echo "No data packets sent in this test"
        return
    fi

    for router in $routers; do
        npackets=`cat $PERFFILE | grep "ARRIVED" | grep $router | grep $DATA | wc -l`
        utilization=`fmt_percentage $npackets $total_arrived`
        printf "Found %4d data packets arrived at router %s; %6s of traffic\n" $npackets $router $utilization
    done
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
#parse down log file to just the relevant bits; add a couple checks to make sure
# we have valid messages, since they are often corrupted
sort $LOGFILE | grep "^\[PERF_DATA\]" | grep "\[PERF_END\]$" | grep "\." | grep -v "  " > $PERFFILE

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
display_punt_count
display_loss_count
# display_convergence_times
display_failure_times
display_node_failures
display_packets_arrived

#cleanup
rm $PERFFILE
