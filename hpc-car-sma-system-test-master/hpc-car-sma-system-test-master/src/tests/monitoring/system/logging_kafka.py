#!/usr/bin/env python

import os
import sys
import json
import time

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system import kafka
from system.whiteboard import Whiteboard

if "SMA_TEST_CONTAINER" in os.environ:
	from pykafka import KafkaClient
	from pykafka.common import OffsetType

class LoggingKafka(Test):

	"""
	:avocado: tags=funct,logging
	Validate health of logging to Kakfa topics
	"""

	MAX_KAFKA_MESSAGES = 50

	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def test_container_logs_kafka(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_container_logs_health", 108595).get()

		retry_count = 5
		while retry_count > 0:
			try:
				broker_name = os.environ.get('KAFKA_HOSTNAME', 'kafka')
				broker_port = os.environ.get('KAFKA_BROKER_PORT', '9092')
				broker_list = "%s:%s" % (broker_name, broker_port)
		 		self.log.debug("Kafka broker list is '%s", broker_list)
				client = KafkaClient(hosts=broker_list)
				retry_count = 0
			except (KafkaException, KeyError) as exc:
				self.log.debug("Kafka connection failed")
				self.log.debug(exc)
				retry_count -= 1
				time.sleep(5)

		topic = client.topics['cray-logs-containers']
		self.assertGreater(len(topic.partitions), 0)

		consumer = topic.get_simple_consumer(
			consumer_group='mygroup',
			auto_offset_reset=OffsetType.LATEST,
			reset_offset_on_start=True,
			consumer_timeout_ms=10000
		)
		types = set()
		group_types = set()
		i = 0
		for message in consumer:
# Total rows
			self.log.debug(i)
			self.log.debug(message)
			self.log.debug(message.value)
			i += 1
			if i > self.MAX_KAFKA_MESSAGES:
				break

if __name__ == "__main__":
    main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
