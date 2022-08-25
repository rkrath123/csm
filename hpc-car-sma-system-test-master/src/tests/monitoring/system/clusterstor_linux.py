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
from system.config import get_postgres_pod
from system import dbschema
from system import cstream
from system import kafka
from system.whiteboard import Whiteboard

if "SMA_TEST_CONTAINER" in os.environ:
	from pykafka import KafkaClient
	from pykafka.common import OffsetType

IS_CONFIGURED = cstream.is_configured()

class Linux(Test):

	"""
	Validate ClusterStor Linux  metrics
	:avocado: tags=long,clusterstor
	"""

	KAFKA_CONSUME_SECS = 60
	POSTGRES_INTERVAL = '1 minutes'

	KAFKA_CONSUMER_TIMEOUT_MS = 120000

	LINUX_METRIC_NAME = "cray_storage"

	LINUX_METRICS = [
#		'cray_storage.cpu_idle_perc',
		'cray_storage.cpu_interrupts_sec',
		'cray_storage.cpu_iowait_perc',
		'cray_storage.cpu_system_perc',
		'cray_storage.cpu_user_perc',
		'cray_storage.cpu_utilization_perc',
		'cray_storage.mem_buffers',
		'cray_storage.mem_cached',
		'cray_storage.memory_utilization_perc'
	]

	DIMENSIONS = {
		'product'   : 'ClusterStor',
		'service'   : 'storage',
		'component' : 'linux',
	}

	@avocado.skipUnless("SMA_TEST_CONTAINER" in os.environ, 'This test must be run in sma-test container')
	@avocado.skipIf(IS_CONFIGURED == False, "cstream is not configured")
	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def test_linux_metrics_kafka(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_linux_metrics_kafka", 130541).get()

		try:
			broker_name = os.environ.get('KAFKA_HOSTNAME', 'kafka')
			broker_port = os.environ.get('KAFKA_BROKER_PORT', '9092')
			broker_list = "%s:%s" % (broker_name, broker_port)
			self.log.debug("Kafka broker list is '%s", broker_list)
			kafka.wait_for_topic(broker_list, 'metrics')

			kafka_client = KafkaClient(hosts=broker_list)
		except (ValueError, KeyError, TypeError):
			self.log.debug("kafka connection failed")

		topic = kafka_client.topics['cray-lustre']
		self.assertGreater(len(topic.partitions), 0)

		metrics_topic = topic.get_simple_consumer(
			consumer_group='metrics_topic',
			auto_offset_reset=OffsetType.LATEST,
			reset_offset_on_start=True,
			consumer_timeout_ms=self.KAFKA_CONSUMER_TIMEOUT_MS
		)

		lustre_metrics_kafka = []

		# Collect metrics from kafka
		consume_secs = self.params.get('kafka_consume_secs', default=self.KAFKA_CONSUME_SECS)
		end_time = time.time() + consume_secs
		self.log.debug("collecting lustre storage metrics from kakfa for %d secs", consume_secs)
		try:
			for message in metrics_topic:
				if message and self.LINUX_METRIC_NAME in message.value:
					try:
						msg = json.loads(message.value)
					except ValueError:
						self.fail('unable to load json data')
					metric = msg.get('metric', {}) 
					self.log.debug(metric)
					lustre_metrics_kafka.append(metric)
				if time.time() > end_time:
					break
			else:
				self.log.debug("kafka consumer timeout")
		except (ValueError, KeyError, TypeError):
			self.log.debug("kafka connection failed")

 		self.log.debug("done with kafka collection")

		# brute force check that all lustre metics exist
		filesystem_names = cstream.get_clusterstor_names()
		for fsname in filesystem_names:
			for expected_name in self.LINUX_METRICS:
				found_it = False
				for metric in lustre_metrics_kafka:
					metric_name = metric.get('name', '')
					dimensions = metric.get('dimensions', {})
					system_name = dimensions.get('system_name', '')
					if expected_name == metric_name and fsname == system_name:
						found_it = True
						self.assertEqual(dimensions.get('product'), self.DIMENSIONS.get('product')) 
						self.assertEqual(dimensions.get('service'), self.DIMENSIONS.get('service')) 
						self.assertEqual(dimensions.get('component'), self.DIMENSIONS.get('component')) 

				self.assertTrue(found_it, 'did not find Linux metric: {} {}'.format(fsname, expected_name))

	def test_linux_seastream_data(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_linux_seastream_data", 130484).get()

		measurements = []
		filesystem_names = cstream.get_clusterstor_names()

		# collect expected linux metrics from the measurement source table
		postgres = get_postgres_pod()

		query = '''select json_agg\(row_to_json\(measurements\)\) FROM \(select measurementtypeid, measurementname from sma.measurementsource\) measurements'''
		cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo {} | psql -t -d sma -U postgres"'''.format(postgres, query)
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		try:
			json_data = json.loads(r.stdout)
		except ValueError:
			self.fail('unable to load json data')

		for expected_name in self.LINUX_METRICS:
			found_it = False
			for row in json_data:
				measurementname = row.get('measurementname')
				if expected_name == measurementname:
					found_it = True
					measurements.append(row)
			self.assertTrue(found_it, 'did not find Linux measurement: {}'.format(expected_name))

		postgres_interval = self.params.get('postgres_interval', default=self.POSTGRES_INTERVAL)
		for measurement in measurements:
			typeid = measurement.get('measurementtypeid')
			name = measurement.get('measurementname')
			self.log.debug('Query Lustre metric data for {} typeid={}'.format(name, typeid))
			query = '''select json_agg(row_to_json(seastream_data)) FROM (select * from sma.seastream_data WHERE seastream_data.measurementtypeid = {} AND \"ts\" >= NOW() - INTERVAL \'{}\') seastream_data'''.format(typeid, postgres_interval)
			cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
 			r = process.run(cmd)
 			self.assertEqual(r.exit_status, 0)
			try:
				seastream_data = json.loads(r.stdout)
			except ValueError:
				self.fail('unable to load json data')
			num_rows = 0
			self.log.debug('Start validating {} Linux metrics typeid={}'.format(name, typeid))
			for data in seastream_data:
				num_rows += 1

				self.assertEqual(data.get('deviceid'), 0)

				# systemid 
				systemid = data.get('systemid')
				r = dbschema.get_system(postgres, systemid)
				self.assertEqual(r.exit_status, 0)
				self.assertNotEqual(b'', r.stdout, 'no systemid found for Linux metric: {} measurementtypeid={}'.format(name, typeid))
				system_data = json.loads(r.stdout)
				system_name = system_data.get('systemname')
				self.assertIn(system_name, filesystem_names)
				self.assertEqual(system_data.get('productname'), self.DIMENSIONS.get('product'))

				# tenantindex 
				r = dbschema.get_tenant(postgres, data.get('tenantindex'))
				self.assertEqual(r.exit_status, 0)
				self.assertNotEqual(b'', r.stdout, 'no tenantindex found for Linux metric: {} measurementtypeid={}'.format(name, typeid))
				tenant_data = json.loads(r.stdout)
				self.assertEqual(tenant_data.get('region'), 'RegionOne')
				self.assertNotEqual(tenant_data.get('tenantid'), b'')

				# hostid 
				r = dbschema.get_clusterstor_host(postgres, data.get('hostid'))
				self.assertEqual(r.exit_status, 0)
				host_data = json.loads(r.stdout)
				self.log.debug(host_data)
				self.assertIn(system_name, host_data.get('hostname'))

			self.log.debug("done validating %d '%s' Linux metrics", num_rows, name)

	@avocado.skip("postgres views are not supported")
	def test_seastream_lustre_views(self):
		# TestRail's test case ID
#		self.whiteboard = Whiteboard("test_linux_metrics_views", 130407).get()

		measurements = []
		filesystem_names = cstream.get_clusterstor_names()
		postgres_interval = self.params.get('postgres_interval', default=self.POSTGRES_INTERVAL)

		postgres = get_postgres_pod()

		for view in ['seastream_lustre_view' 'seastream_lustre_calc_view' ]:
			self.log.debug('Query Lustre view {} data'.format(view))

#		query = '''select json_agg(row_to_json(seastream_data)) FROM (select * from sma.seastream_lustre_view WHERE seastream_lustre_view.measurementname = '{}' AND \"ts\" >= NOW() - INTERVAL \'{}\') seastream_data'''.format(name, postgres_interval)
			query = '''select json_agg(row_to_json(seastream_data)) FROM (select * from sma.{} WHERE \"ts\" >= NOW() - INTERVAL \'{}\') seastream_data'''.format(view, postgres_interval)
			cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			self.log.debug('start validating Lustre view metrics')
			try:
				seastream_data = json.loads(r.stdout)
			except ValueError:
				self.fail('unable to load json data')

			num_rows = 0
			for data in seastream_data:
				num_rows += 1

				self.assertIn(data.get('systemname'), filesystem_names)
				self.assertIn(data.get('productname'), self.DIMENSIONS.get('product'))
# hostname
# devicename
				self.assertTrue(data.get('device_type') == 'mdt' or data.get('device_type') == 'ost')
				self.assertIn(data.get('componentname'), self.DIMENSIONS.get('component'))
				self.assertIn(data.get('service'), self.DIMENSIONS.get('service'))
				self.assertEqual(data.get('measurementunits'), b'')
				self.assertNotEqual(data.get('tenantid'), b'')
				self.assertEqual(data.get('region'), 'RegionOne')

			self.log.debug("done validating %d '%s' Lustre metrics", num_rows, view)
			self.assertGreater(num_rows, 0)

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
