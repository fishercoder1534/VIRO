# Traffic Generator for VIRO emulator
# Pengkui Luo (pluo@cs.umn.edu)
# 4/15/2011

# Usage: traffic-gen.pyc <vid_file> <workload_file> <my_ip:my_port>
'''
 This script simulates all hosts attached to switch <my_ip:my_port>.
 It scans the <workload_file>, forms data packets destined to switches specified
 in <workload_file>, and injects the packets to its attached switch.
'''
import sys, os, random, socket, time, threading, struct
from constants import *

def parse_files():
    pid2vid = {} # mapping pid to vid
    rates = {} # mapping dst_vid to traffic rate
    try:
        my_pid = sys.argv[3] #e.g. 'localhost:8001'
        my_ip, my_pt = my_pid.split(':')
        my_pt = int(my_pt) #e.g. 8001
        # Parse <vid_file>, and store the pid-to-vid mapping in pid2vid[]
        f_vid = file(sys.argv[1], 'r')
        line = f_vid.readline().strip()
        while line != '':
            tokens = line.split(' ')
            pid2vid[tokens[0]] = tokens[1]
            line = f_vid.readline().strip()
        # Parse <workload_file>, and store the traffic rate (to different dst_vid) in rate[]
        f_workload = file(sys.argv[2], 'r')
        line = f_workload.readline() # skip the first row
        line = f_workload.readline().strip()
        while line != '':
            tokens = line.split(' ')
            if tokens[0]==my_pid: # only parse traffic sourced at me
                rates[pid2vid[tokens[1]]] = float(tokens[2])
            line = f_workload.readline().strip()
    except:
        print "Usage: traffic-gen.pyc <vid_file> <workload_file> <src_ip:src_port>"
        f_vid.close()
        f_workload.close()
        sys.exit()
    finally:
        f_vid.close()
        f_workload.close()
    return (my_ip, my_pt), pid2vid[my_pid], rates

def gen_traffic(my_ip_pt, pkt, rate):
    # Keep injecting the static packets to the attached switch
    while True:
        conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        time.sleep( 1.0/ abs( random.gauss(rate,0.05) ) )
        try:
            conn.connect(my_ip_pt)
            conn.send(pkt)
            conn.close() # one-shot, non-persistent for simplicity
        except:
            print "Failed to send packets to", my_ip, my_pt
            sys.exit(1)

if __name__ == "__main__":
    my_ip_pt, my_vid, rates = parse_files()
    time.sleep(5)
    for dst_vid in rates:
        '''
        Construct a static/dummy data packet destined to dst_vid
        note: B:8bit, H:16bit, I:32bit. reference: http://docs.python.org/library/struct.html
            0x0000 for data pkts, 32bit src_vid, 32bit dst_vid, 
            32bit fwd_vid (initialized to dst_vid), 8bit TTL (initialized to 64)
        '''
        # TODO: Add FWD-VID and TTL fields
	
	'''
	Steve: So, I was going to do task 2 but got stuck here:as the assignment says, part 1 of task 2 is to add 
	FWD-VID and TTL fields into the data packet format, but here, in this initial given code, both FWD-VID and TTL 
	field had been given and initialized, FWD-VID had been initialized to dst_vid and TTL had been initialized to 64, so what
	else are we supposed to do? Where and how should we modify packet definition to add these two new fields?
	I've searched through veil.py and veil_switch.py but all packets in those files are CONTROL packets instead
	of data packets. Any one can give me any help please?
	'''

    '''
    RJZ: I see you are right, the fields are already added. What we need to do in traffic_gen.py is to modify
    the initial value of these fields.

    fwd_vid: See page 3, letter b), letter i) on the warmup document. We will initialize this value to 
    the gateway which is selected by the src node. However, this gateway is not known by the traffic-gen
    device. So, setting the value of fwd_vid will be the responsibility of the the router which the 
    traffic-gen is connected to. If we set the initial value here to some know value, say 0x89abcdef, 
    then in the routepacket method, when that router sees that the fwd_vid is 0x89abcdef, that router knows 
    it must set the fwd_vid to the correct value. Again, see the warmup doc to see what that value should be.

    ttl: We may need to reduce this value to shorten the number of hops a packet could traverse when it's 
    stuck in an infinite loop. Let's just leave it set to 64 for now though.
    '''
    
        pkt = struct.pack('!HHBBH', HTYPE, PTYPE, HLEN, PLEN, 0x0000)\
            + struct.pack('!I', int(my_vid, 2))\
            + struct.pack('!I', int(dst_vid,2))\
            + struct.pack('!I', int(dst_vid,2))\
            + struct.pack('!B', 64)\
            + struct.pack('!BHI', 0x00, 0x0000, 0x00000000)
        threading.Thread(\
            target = gen_traffic, name = 'GenTrafficTo:%s'%dst_vid,\
            args = [my_ip_pt, pkt, rates[dst_vid]]\
        ).start()
