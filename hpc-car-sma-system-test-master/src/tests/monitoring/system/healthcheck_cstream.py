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
from system import cstream
from system import kafka
from system.whiteboard import Whiteboard

if "SMA_TEST_CONTAINER" in os.environ:
	from pykafka import KafkaClient
	from pykafka.common import OffsetType

IS_CONFIGURED = cstream.is_configured()

class Cstream(Test):

	"""
	:avocado: tags=funct,clusterstor
	ClusterStor cstream health checks
	"""

	KAFKA_CONSUME_SECS = 60
	KAFKA_CONSUMER_TIMEOUT_MS = 120000

	POSTGRES_POD = "craysma-postgres-cluster-0"

	# subset of expected metrics simply to confirm that something is coming in
	EXPECTED_LUSTRE_METRIC = "cray_storage.open_rate"
	EXPECTED_LINUX_METRIC = "cray_storage.memory_utilization_perc"

	EXPECTED_VIEWS = [
		"seastream_view",
		"seastream_lustre_view",
		"seastream_lustre_calc_view",
		"seastream_linux_view",
		"clusterstor_status_view",
		"jobstats_view",
		"jobstats_device_view",
		"jobstats_calc_view",
		"jobstats_score_view",
		"jobstats_jobcnt_view",
	]

	def setUp(self):
		self.log.debug(Cstream.__doc__)

		self.postgres = self.POSTGRES_POD

	def tearDown(self):
		self.log.debug("tearDown")

	@avocado.skipIf(IS_CONFIGURED == False, "cstream is not configured")
	def test_cstream_health(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_cstream_health", 130407).get()

		try:
			broker_name = os.environ.get('KAFKA_HOSTNAME', 'kafka')
			broker_port = os.environ.get('KAFKA_BROKER_PORT', '9092')
			broker_list = "%s:%s" % (broker_name, broker_port)
			self.log.debug("Kafka broker list is '%s", broker_list)
			kafka.wait_for_topic(broker_list, 'metrics')

			kafka_client = KafkaClient(hosts=broker_list)
		except (ValueError, KeyError, TypeError):
			self.fail('kafka connection failed')

		topic = kafka_client.topics['cray-lustre']
		self.assertGreater(len(topic.partitions), 0)

		metrics_topic = topic.get_simple_consumer(
			consumer_group='metrics_topic',
			auto_offset_reset=OffsetType.LATEST,
			reset_offset_on_start=True,
			consumer_timeout_ms=self.KAFKA_CONSUMER_TIMEOUT_MS
		)

		# collect metrics from kafka
		found_lustre_metric = False
		found_linux_metric = False
		end_time = time.time() + self.KAFKA_CONSUME_SECS
		self.log.debug("collecting lustre/linux metrics from kakfa for %d secs", self.KAFKA_CONSUME_SECS)
		try:
			for message in metrics_topic:
				if message and self.EXPECTED_LUSTRE_METRIC in message.value:
					self.log.debug(message.value)
					found_lustre_metric = True
				if message and self.EXPECTED_LINUX_METRIC in message.value:
					self.log.debug(message.value)
					found_linux_metric = True
				if (found_lustre_metric and found_linux_metric) or time.time() > end_time:
					break
			else:
				self.log.debug("kafka consumer timeout")
		except (ValueError, KeyError, TypeError):
			self.fail("kafka connection failed")

		self.log.debug("done with kafka collection")
		self.assertTrue(found_lustre_metric, 'no lustre metrics found in kafka')
		self.assertTrue(found_linux_metric, 'no linux metrics found in kafka')

	@avocado.skipIf(IS_CONFIGURED == False, "cstream is not configured")
	def test_cstream_conf(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_cstream_conf", 130408).get()

		cmd = 'kubectl get configmap cstream-config -o json'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		data = json.loads(r.stdout_text)
		self.assertEqual('v1', data.get('apiVersion'))
		self.assertEqual('ConfigMap', data.get('kind'))
		metadata = data.get('metadata')
		self.assertEqual('cstream-config', metadata.get('name'))
		self.assertEqual('sma', metadata.get('namespace'))

		system_names = cstream.get_clusterstor_names()
		self.log.debug(system_names)
		self.assertGreaterEqual(len(system_names), 1)

	def test_cstream_views(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_cstream_views", 130409).get()

		r = dbschema.get_views(self.postgres)
		self.assertEqual(r.exit_status, 0)

		for view in self.EXPECTED_VIEWS:
			self.assertIn(view, r.stdout_text)

if __name__ == "__main__":
    main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
