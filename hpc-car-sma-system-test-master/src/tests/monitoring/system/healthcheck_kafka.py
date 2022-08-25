#!/usr/bin/env python

import os
import sys
import json
import time

from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.whiteboard import Whiteboard
from system.config import get_kafka_pod, get_kafka_topics, get_kafka_topic_partitions, get_kafka_topic_replicas

class Kafka(Test):

	"""
	:avocado: tags=health
	Kafka health checks.
	"""

	POD = get_kafka_pod()
	EXPECTED_TOPICS = get_kafka_topics()
	EXPECTED_PARTITIONS = get_kafka_topic_partitions()
	EXPECTED_REPLICAS = get_kafka_topic_replicas()

	def setUp(self):
		self.log.debug(Kafka.__doc__)

	def tearDown(self):
		self.log.debug("tearDown")

	def test_kafka_health(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_kafka_health", 108577).get()

		cmd = '''kubectl -n sma exec {} -c kafka -t -- /opt/kafka/bin/kafka-topics.sh --list --zookeeper localhost:2181'''.format(self.POD)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		stdout_lines = astring.to_text(r.stdout)

		for topic in self.EXPECTED_TOPICS:
			self.assertIn(topic, stdout_lines, 'missing topic: %s' % (topic))

	def test_kafka_topic_partition_counts(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_kafka_topic_partition_counts", 130410).get()

		for topic in self.EXPECTED_TOPICS:
			cmd = '''kubectl -n sma exec {} -c kafka -t -- /opt/kafka/bin/kafka-topics.sh --describe --topic {}  --zookeeper localhost:2181'''.format(self.POD, topic)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			self.log.debug(r.stdout)
			for key, value in self.EXPECTED_PARTITIONS.iteritems():
				if key == topic:
					self.assertIn('PartitionCount:'+ value, r.stdout, 'invalid partition count found: %s' % (topic))

	def test_kafka_topic_replicas(self):
		# TestRail's test case ID
 		self.whiteboard = Whiteboard("test_kafka_topic_replicas", 131515).get()

		for topic in self.EXPECTED_TOPICS:
			cmd = '''kubectl -n sma exec {} -c kafka -t -- /opt/kafka/bin/kafka-topics.sh --describe --topic {}  --zookeeper localhost:2181'''.format(self.POD, topic)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			self.log.debug(r.stdout)
			for key, value in self.EXPECTED_REPLICAS.iteritems():
				if key == topic:
					self.assertIn('ReplicationFactor:'+ value, r.stdout, 'invalid replica found: %s' % (topic))

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
