python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5001 0 &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5002 0 &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5003 0 &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5004 0 &
python ../../../traffic-gen.pyc 4.vid 4.test1.workload localhost:5001 &
python ../../../traffic-gen.pyc 4.vid 4.test1.workload localhost:5004 & 

