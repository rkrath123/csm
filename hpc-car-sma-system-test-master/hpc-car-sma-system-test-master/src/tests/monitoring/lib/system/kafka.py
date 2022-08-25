#!/usr/bin/env python

import os
import sys
import time
import datetime
from pykafka import KafkaClient

from avocado.utils import process
from avocado.utils import astring

def wait_for_topic(broker_list, wait_topic):
	print("Wait for Kafka topic: %s %s" % (broker_list, wait_topic))

	end_time = datetime.datetime.now() + datetime.timedelta(minutes=5)
	start_time = datetime.datetime.now()

	while True:
		if datetime.datetime.now() >= end_time:
			break

		client = KafkaClient(hosts=broker_list)
		if wait_topic in client.topics:
			topic = client.topics[wait_topic]
			if len(topic.partitions) > 0:
				print("Kafka topic %s is ready %d partitions" % (wait_topic, len(topic.partitions)))
				break
			else:
				print("Kafka topic %s has no partitions" % (wait_topic))
		else:
			print("Kafka topic %s not found" % (wait_topic))

		del client
		time.sleep(10)

	return

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
