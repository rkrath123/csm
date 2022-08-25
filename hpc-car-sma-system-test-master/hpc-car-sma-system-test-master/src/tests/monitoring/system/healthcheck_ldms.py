#!/usr/bin/env python

import os
import json
import time
import sys

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system import dbschema
from system import kafka
from system.whiteboard import Whiteboard

if "SMA_TEST_CONTAINER" in os.environ:
	from pykafka import KafkaClient
	from pykafka.common import OffsetType

class LDMS(Test):

	"""
	:avocado: tags=funct,ldms
	LDMS health checks.
	"""

	POSTGRES_POD = "craysma-postgres-cluster-0"

	KAFKA_CONSUME_SECS = 90
	KAFKA_CONSUMER_TIMEOUT_MS = 120000

	VMSTAT_METRIC_NAME = 'cray_vmstat'

	EXPECTED_VIEWS = [
		"ldms_view",
		"ldms_iostat_view",
		"ldms_vmstat_view",
	]

	@avocado.skipUnless("SMA_TEST_CONTAINER" in os.environ, 'This test must be run in sma-test container')
	def setUp(self):
		self.log.debug(LDMS.__doc__)

		self.postgres = self.POSTGRES_POD
		self.log.debug(self.postgres)

	def tearDown(self):
		self.log.debug("tearDown")

	def test_ldms_health(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_ldms_health", 108653).get()

		try:
			broker_name = os.environ.get('KAFKA_HOSTNAME', 'kafka')
			broker_port = os.environ.get('KAFKA_BROKER_PORT', '9092')
			broker_list = "%s:%s" % (broker_name, broker_port)
			self.log.debug("Kafka broker list is '%s", broker_list)
			kafka.wait_for_topic(broker_list, 'cray-node')

			kafka_client = KafkaClient(hosts=broker_list)
		except (ValueError, KeyError, TypeError):
			self.fail('kafka connection failed')

		topic = kafka_client.topics['cray-node']
		self.assertGreater(len(topic.partitions), 0)

		metrics_topic = topic.get_simple_consumer(
			consumer_group='metrics_topic',
			auto_offset_reset=OffsetType.LATEST,
			reset_offset_on_start=True,
			consumer_timeout_ms=self.KAFKA_CONSUMER_TIMEOUT_MS
		)

		# collect metrics from kafka
		found_vmstat_metric = False
		end_time = time.time() + self.KAFKA_CONSUME_SECS
		self.log.debug("collecting ldms metrics from kakfa for %d secs", self.KAFKA_CONSUME_SECS)
		try:
			for message in metrics_topic:
				if message and self.VMSTAT_METRIC_NAME in message.value:
					self.log.debug(message.value)
					found_vmstat_metric = True
					break
				if time.time() > end_time:
					break
			else:
				self.log.debug("kafka consumer timeout")
		except (ValueError, KeyError, TypeError):
			self.fail("kafka connection failed")

		self.log.debug("done with kafka collection")
		self.assertTrue(found_vmstat_metric, 'no LDMS vmstat metrics found in kafka')

	def test_ldms_conf(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_ldms_conf", 108703).get()

		ldms_aggr_pods = []

		cmd = 'kubectl -n sma get pod -l app=sma-ldms-aggr-sms -o jsonpath="{.items[0].metadata.name}"'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		pod = astring.to_text(r.stdout)
		ldms_aggr_pods.append(pod)

		cmd = '''kubectl -n sma exec {} -t -- md5sum /etc/sysconfig/ldms.d/ClusterSecrets/sms.ldmsauth.conf'''.format(pod)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)

		cmd = 'kubectl -n sma get pod -l app=sma-ldms-aggr-compute -o jsonpath="{.items[0].metadata.name}"'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		pod = astring.to_text(r.stdout)
		ldms_aggr_pods.append(pod)

		cmd = '''kubectl -n sma exec {} -t -- md5sum /etc/sysconfig/ldms.d/ClusterSecrets/compute.ldmsauth.conf'''.format(pod)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)

		for pod in ldms_aggr_pods:
			cmd = '''kubectl -n sma exec {} -t -- ls -lR /etc/sysconfig/ldms.d'''.format(pod)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)

			cmd = '''kubectl -n sma exec {} -t -- /ldmsd-bootstrap container_check'''.format(pod)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)

	def test_ldms_views(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_ldms_views", 130406).get()

		r = dbschema.get_views(self.postgres)
		self.assertEqual(r.exit_status, 0)

		for view in self.EXPECTED_VIEWS:
			self.assertIn(view, r.stdout_text)

if __name__ == "__main__":
    main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
