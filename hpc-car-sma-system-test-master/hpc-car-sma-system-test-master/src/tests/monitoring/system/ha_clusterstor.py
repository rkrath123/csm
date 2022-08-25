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
from system.ha import HA
from system.whiteboard import Whiteboard

if "SMA_TEST_CONTAINER" in os.environ:
	from pykafka import KafkaClient
	from pykafka.common import OffsetType

IS_CONFIGURED = cstream.is_configured()

class ClusterStor(Test):

	"""
	ClusterStor metrics with high availability checks
	:avocado: tags=unsafe,ha
	"""

	KAFKA_CONSUME_SECS = 300
	POSTGRES_INTERVAL = '5 minutes'

	KAFKA_CONSUMER_TIMEOUT_MS = 120000

	METRIC_NAME = "cray_storage"

	CALCULATED_LUSTRE_METRICS = [
		'cray_storage.calculated_metadata_ops',
		'cray_storage.calculated_read_bytes',
		'cray_storage.calculated_write_bytes',
	]

	LUSTRE_METRICS = [
		'cray_storage.open_rate',
		'cray_storage.getattr_rate',
		'cray_storage.close_rate',
		'cray_storage.read_bytes_rate',
		'cray_storage.write_bytes_rate'
	]

	DIMENSIONS = {
		'product'   : 'ClusterStor',
		'service'   : 'storage',
		'component' : 'lustre',
	}

	@avocado.skipIf(IS_CONFIGURED == False, "cstream is not configured")
	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	@avocado.skip("test not ready")
	def test_service_delete_clusterstor_kafka(self):
		# TestRail's test case ID
#		self.whiteboard = Whiteboard("test_ha_clusterstor_metrics_kafka", 130486).get()

		ha = HA()
		ha.delete_service(getattr(HA, "KAFKA"))
		deleted = ha.get_deleted_service()
		self.assertNotEqual(deleted, None, 'failed to delete Kafka service')
		self.log.debug("deleted service %s", deleted) 

		try:
			broker_name = os.environ.get('KAFKA_HOSTNAME', 'kafka')
			broker_port = os.environ.get('KAFKA_BROKER_PORT', '9092')
			broker_list = "%s:%s" % (broker_name, broker_port)
			self.log.debug("Kafka broker list is '%s", broker_list)
			kafka_client = KafkaClient(hosts=broker_list)
		except (ValueError, KeyError, TypeError):
			self.log.debug("kafka connection failed")

		topic = kafka_client.topics['metrics']
		metrics_topic = topic.get_simple_consumer(
			consumer_group='metrics_topic',
			auto_offset_reset=OffsetType.LATEST,
			reset_offset_on_start=True,
			consumer_timeout_ms=self.KAFKA_CONSUMER_TIMEOUT_MS
		)

		metrics_kafka = []

		# Collect metrics from kafka
		consume_secs = self.params.get('kafka_consume_secs', default=self.KAFKA_CONSUME_SECS)
		end_time = time.time() + consume_secs
		self.log.debug("collecting lustre storage metrics from kakfa for %d secs", consume_secs)
		try:
			for message in metrics_topic:
				if message and self.METRIC_NAME in message.value:
					try:
						msg = json.loads(message.value)
					except ValueError:
						self.fail('unable to load json data')
					metric = msg.get('metric', {}) 
					self.log.debug(metric)
					metrics_kafka.append(metric)
				if time.time() > end_time:
					break
			else:
				self.log.debug("kafka consumer timeout")
		except (ValueError, KeyError, TypeError):
			self.log.debug("kafka connection failed")

 		self.log.debug("done with kafka collection")

		# brute force check that expected lustre metics exist
		filesystem_names = cstream.get_clusterstor_names()
		for fsname in filesystem_names:
			for expected_name in self.LUSTRE_METRICS + self.CALCULATED_LUSTRE_METRICS:
				found_it = False
				for metric in metrics_kafka:
					metric_name = metric.get('name', '')
					dimensions = metric.get('dimensions', {})
					system_name = dimensions.get('system_name', '')
					if expected_name == metric_name and fsname == system_name:
						found_it = True
						self.assertEqual(dimensions.get('product'), self.DIMENSIONS.get('product')) 
						self.assertEqual(dimensions.get('service'), self.DIMENSIONS.get('service')) 
						self.assertEqual(dimensions.get('component'), self.DIMENSIONS.get('component')) 

				self.assertTrue(found_it, 'did not find Lustre metric: {} {}'.format(fsname, expected_name))

#		name = service.get_killed_service()
#		self.assertTrue(service.check_service(), 'service did not )

	@avocado.skip("test not ready")
	def test_ha_clusterstor_metrics_database(self):
		# TestRail's test case ID
#		self.whiteboard = Whiteboard("test_ha_lustre_metrics_database", 130487).get()

		measurements = []
		filesystem_names = cstream.get_clusterstor_names()

		# collect expected lustre metrics from the measurement source table
		cmd = 'kubectl -n sma get pod -l app=postgres -o jsonpath="{.items[0].metadata.name}"'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		postgres = astring.to_text(r.stdout)

		query = '''select json_agg\(row_to_json\(measurements\)\) FROM \(select measurementtypeid, measurementname from sma.measurementsource\) measurements'''
		cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo {} | psql -t -d sma -U postgres"'''.format(postgres, query)
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		try:
			json_data = json.loads(r.stdout)
		except ValueError:
			self.fail('unable to load json data')

		for expected_name in self.LUSTRE_METRICS + self.CALCULATED_LUSTRE_METRICS:
			found_it = False
			for row in json_data:
				measurementname = row.get('measurementname')
				if expected_name == measurementname:
					found_it = True
					measurements.append(row)
			self.assertTrue(found_it, 'did not find Lustre measurement: {}'.format(expected_name))

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
			self.log.debug('Start validating {} Lustre metrics typeid={}'.format(name, typeid))
			for data in seastream_data:
				num_rows += 1

				# deviceid 
 				r = dbschema.get_cstream_device(postgres, data.get('deviceid'))
 				self.assertEqual(r.exit_status, 0)
				self.assertNotEqual(b'', r.stdout, 'no deviceid found for Lustre metric: {} measurementtypeid={}'.format(name, typeid))
				device_data = json.loads(r.stdout)
				self.assertTrue(device_data.get('device_type') == 'mdt' or device_data.get('device_type') == 'ost')
				self.assertIsNot(device_data.get('systemid'), 0)

				# systemid 
				systemid = data.get('systemid')
				r = dbschema.get_system(postgres, systemid)
				self.assertEqual(r.exit_status, 0)
				self.assertNotEqual(b'', r.stdout, 'no systemid found for Lustre metric: {} measurementtypeid={}'.format(name, typeid))
				system_data = json.loads(r.stdout)
				self.assertIn(system_data.get('systemname'), filesystem_names)
				self.assertEqual(system_data.get('productname'), 'ClusterStor')

				# tenantindex 
				r = dbschema.get_tenant(postgres, data.get('tenantindex'))
				self.assertEqual(r.exit_status, 0)
				self.assertNotEqual(b'', r.stdout, 'no tenantindex found for Lustre metric: {} measurementtypeid={}'.format(name, typeid))
				tenant_data = json.loads(r.stdout)
				self.assertEqual(tenant_data.get('region'), 'RegionOne')
				self.assertNotEqual(tenant_data.get('tenantid'), b'')

			self.log.debug("done validating %d '%s' Lustre metrics", num_rows, name)

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
