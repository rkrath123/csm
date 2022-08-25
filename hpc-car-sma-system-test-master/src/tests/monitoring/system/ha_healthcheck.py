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
from system.config import get_kafka_topics, get_kafka_topic_partitions, get_kafka_topic_replicas
from system.whiteboard import Whiteboard
from system.ha import HA

class Health(Test):

	"""
	ha health checks on base SMF services
	:avocado: tags=unsafe,health
	"""

	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def check_topics(self, pod):

		cmd = '''kubectl -n sma exec {} -c kafka -t -- /opt/kafka/bin/kafka-topics.sh --list --zookeeper localhost:2181'''.format(pod)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.log.debug(r.stdout)

		expected_topics = get_kafka_topics()
		for topic in expected_topics:
			self.assertIn(topic, r.stdout)

		for topic in expected_topics:
			cmd = '''kubectl -n sma exec {} -c kafka -t -- /opt/kafka/bin/kafka-topics.sh --describe --topic {}  --zookeeper localhost:2181'''.format(pod, topic)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			self.log.debug(r.stdout)

			expected_partitions = get_kafka_topic_partitions()
 			for key, value in expected_partitions.iteritems():
 				if key == topic:
 					self.assertIn('PartitionCount:'+ value, r.stdout)

			expected_replicas = get_kafka_topic_replicas()
 			for key, value in expected_replicas.iteritems():
 				if key == topic:
 					self.assertIn('ReplicationFactor:'+ value, r.stdout)

	def test_ha_kafka_health(self):
		# TestRail's test case ID
#		self.whiteboard = Whiteboard("test_kafka_health", 108577).get()

		ha = HA()
		for pod in HA.KAFKA:

			self.check_topics(pod)

# 			deleted = ha.delete_pod(pod)
# 			self.log.debug("deleted pod %s", deleted)
# 			self.assertNotEqual(deleted, None, 'failed to delete pod {}'.format(pod))

# 			ready = ha.wait_pod()
#			self.assertTrue(ready, 'pod {} not ready'.format(pod))

			self.check_topics(pod)

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
