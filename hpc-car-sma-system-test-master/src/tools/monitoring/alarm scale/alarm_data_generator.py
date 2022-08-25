# Copyright 2021 Hewlett Packard Enterprise Development LP
import time
from json import dumps
from kafka import KafkaProducer

ten_id = "dc35af1ccf2d4728b847839d69d1f609"
iteration = [3, 5, 9, 13, 17, 21, 25]
producer = KafkaProducer(bootstrap_servers='localhost:9092')
now = time.time()
for (i in iteration)
    for e in range(60):
        ms = int(time.time() * 1000)
        ns = int(time.time() * 1000000000)
        for hostnumber in range(i):
            data = '{"metric":{"name":"cray_test.other_test","dimensions":{"product":"shasta","system":"ncn","service":"ldms","component":"cray_vmstat","hostname": "host' + str(
                hostnumber) + '","cname":"","job_id":"0"},"timestamp": ' + str(
                ms) + ',"value":80},"meta":{"tenantId":"' + ten_id + '","region":"RegionOne"},"creation_time": ' + str(
                ns) + '}'
            producer.send("cray-node", "%s" % (data));
        time.sleep(1)
producer.close()
elapsed = time.time() - now
print(elapsed)