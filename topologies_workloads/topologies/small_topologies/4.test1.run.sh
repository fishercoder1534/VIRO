python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5001 0 > 0.runshout &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5002 0 > 1.runshout &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5003 0 > 2.runshout &
python ../../../veil_switch.pyc 4.adlist 4.vid localhost:5004 0 > 3.runshout &
python ../../../traffic-gen.pyc 4.vid 4.test1.workload localhost:5001 > 4.runshout &
python ../../../traffic-gen.pyc 4.vid 4.test1.workload localhost:5004 > 5.runshout &
