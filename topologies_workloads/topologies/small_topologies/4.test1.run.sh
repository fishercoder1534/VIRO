python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5001 0 > op5001.txt &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5002 0 > op5002.txt &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5003 0 > op5003.txt &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5004 0 > op5004.txt &
python ../../../traffic-gen.pyc 4.vid 4.test1.workload localhost:5001 &
python ../../../traffic-gen.pyc 4.vid 4.test1.workload localhost:5004 & 

