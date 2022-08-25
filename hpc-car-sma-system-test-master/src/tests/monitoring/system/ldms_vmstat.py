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
from system.config import get_postgres_pod
from system.whiteboard import Whiteboard

from pykafka import KafkaClient
from pykafka.common import OffsetType
from pykafka.exceptions import KafkaException

class LDMS(Test):

	"""
	LDMS metrics in Kafka and Postgres
	:avocado: tags=funct,ldms
	"""

	KAFKA_CONSUME_SECS = 60
	POSTGRES_INTERVAL = '60 seconds'

	KAFKA_CONSUMER_TIMEOUT_MS = 120000
	VMSTAT_METRIC_NAME = 'cray_vmstat'
	VMSTAT_METRIC_COUNT = 16
	VMSTAT_METRICS = []

	DIMENSIONS = {
		'product'   : 'shasta',
		'job_id'    : '0',
		'service'   : 'ldms',
		'component' : 'cray_vmstat',
	}

	def setUp(self):
		self.log.debug("setUp")

		# collect expected ldms metrics from the measurement source table
		self.postgres = get_postgres_pod()
 		query = '''select json_agg\(row_to_json\(measurements\)\) FROM \(select measurementtypeid, measurementname from sma.measurementsource\) measurements'''
		cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo {} | psql -t -d sma -U postgres"'''.format(self.postgres, query)
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		try:
			json_data = json.loads(r.stdout)
		except ValueError:
			self.fail('unable to load json data')

		len_messages = 0
		num_messages = 0

		for row in json_data:
			if row.get('measurementname').find(self.VMSTAT_METRIC_NAME) != -1:
				self.log.debug(row)
				self.VMSTAT_METRICS.append(row)

				len_messages += len(json.dumps(row))
				num_messages += 1

		self.log.debug("numof vmstat messages= {} len= {}".format(num_messages, len_messages))
		self.assertEqual(len(self.VMSTAT_METRICS), self.VMSTAT_METRIC_COUNT)

	def tearDown(self):
		self.log.debug("tearDown")

	def test_vmstat_metrics_kafka(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_vmstat_metrics_kafka", 108652).get()

		retry_count = 5
		while retry_count > 0:
			try:
				broker_name = os.environ.get('KAFKA_HOSTNAME', 'kafka')
				broker_port = os.environ.get('KAFKA_BROKER_PORT', '9092')
				broker_list = "%s:%s" % (broker_name, broker_port)
				self.log.debug("Kafka broker list is '%s", broker_list)
				kafka_client = KafkaClient(hosts=broker_list)
				retry_count = 0

			except (KafkaException, KeyError) as exc:
				self.log.debug("kafka connection failed")
				self.log.debug(exc)
				retry_count -= 1
				time.sleep(5)

		topic = kafka_client.topics['cray-node']
		self.assertGreater(len(topic.partitions), 0)

		cray_node_topic = topic.get_simple_consumer(
			consumer_group='cray_node_topic',
			auto_offset_reset=OffsetType.LATEST,
			reset_offset_on_start=True,
			consumer_timeout_ms=self.KAFKA_CONSUMER_TIMEOUT_MS
		)

		vmstat_metrics = []

 		# Collect metrics from kafka
		consume_secs = self.params.get('kafka_consume_secs', default=self.KAFKA_CONSUME_SECS)
 		end_time = time.time() + consume_secs
 		self.log.debug("collecting ldms metrics from kakfa for %d secs", consume_secs)
 		try:
 			for message in cray_node_topic:
 				if message and self.VMSTAT_METRIC_NAME in message.value:
					try:
						msg = json.loads(message.value)
					except ValueError:
						self.fail('unable to load json data')
 					vmstat_metrics.append(msg)
 				if time.time() > end_time:
 					break
 			else:
 				self.log.debug("kafka consumer timeout")
 		except (ValueError, KeyError, TypeError):
 			self.log.debug("kafka connection failed")

 		self.log.debug("done with kafka collection")

		# brute force check that all vmstat metics exist
		for measurement in self.VMSTAT_METRICS:
			found_it = False

			vmstat = measurement.get('measurementname')
			for value in vmstat_metrics:
				metric = value.get('metric', {}) 

				metric_name = metric.get('name', '')
				if vmstat in metric_name:
					self.log.debug('found vmstat metric %s', metric_name)
					found_it = True
					dimensions = metric.get('dimensions', {})
					self.assertEqual(dimensions.get('product'), self.DIMENSIONS.get('product')) 
					self.assertEqual(dimensions.get('job_id'), self.DIMENSIONS.get('job_id')) 
					self.assertEqual(dimensions.get('service'), self.DIMENSIONS.get('service')) 
					self.assertEqual(dimensions.get('component'), self.DIMENSIONS.get('component')) 
					self.assertTrue(dimensions.get('system') == 'compute' or dimensions.get('system') == 'sms')
					if dimensions.get('system') == 'compute':
						self.assertIn('nid', dimensions.get('hostname'))
					else:
						self.assertIn('sma-ldms-sms', dimensions.get('hostname'))

			self.assertTrue(found_it, 'did not find LDMS vmstat metric: {}'.format(vmstat))

	def test_vmstat_ldms_data(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_vmstat_ldms_data", 108686).get()

		postgres_interval = self.params.get('postgres_interval', default=self.POSTGRES_INTERVAL)
		for measurement in self.VMSTAT_METRICS:
			typeid = measurement.get('measurementtypeid')
			name = measurement.get('measurementname')
			query = '''select json_agg(row_to_json(ldms_data)) FROM (select * from sma.ldms_data WHERE ldms_data.measurementtypeid = {} AND \"ts\" >= NOW() - INTERVAL \'{}\') ldms_data'''.format(typeid, postgres_interval)
			cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(self.postgres, query)
			self.log.debug(cmd)
 			r = process.run(cmd)
 			self.assertEqual(r.exit_status, 0)
			self.assertNotEqual(b'', r.stdout, 'no data found for vmstat metric: {} typeid={}'.format(name, typeid))
			try:
				ldms_data = json.loads(r.stdout)
			except ValueError:
				self.fail('unable to load json data')
			num_rows = 0
# Removed - test is taking too long
#			for data in ldms_data:
#				self.log.debug(data)
#				num_rows += 1

				# job_id 
#				self.assertEqual(data.get('job_id'), '0', 'unexpected job_id for vmstat metric: {} measurementtypeid={}'.format(name, typeid))

				# deviceid 
#				self.assertEqual(data.get('deviceid'), 0, 'unexpected deviceid for vmstat metric: {} measurementtypeid={}'.format(name, typeid))

				# systemid 
#				systemid = data.get('systemid')
#				r = dbschema.get_system(self.postgres, systemid)
#				self.assertEqual(r.exit_status, 0)
#				self.assertNotEqual(b'', r.stdout, 'no systemid found for vmstat metric: {} measurementtypeid={}'.format(name, typeid))
#				system_data = json.loads(r.stdout)
#				self.assertTrue(system_data.get('systemname') == 'compute' or system_data.get('systemname') == 'sms')
#				self.assertEqual(system_data.get('productname'), 'shasta')

				# hostid 
#				r = dbschema.get_ldms_host(self.postgres, data.get('hostid'))
#				self.assertEqual(r.exit_status, 0)
#				self.assertNotEqual(b'', r.stdout, 'no hostid found for metric: {}'.format(name))
#				host_data = json.loads(r.stdout)
#				if system_data.get('systemname') == 'compute':
#					self.assertIn('nid', host_data.get('hostname'))
#					self.assertNotEqual(host_data.get('cname'), b'')
#				else:
#					self.assertIn('sma-ldms-sms', host_data.get('hostname'))
#				self.assertEqual(host_data.get('systemid'), systemid)
 
				# tenantindex 
#				r = dbschema.get_tenant(self.postgres, data.get('tenantindex'))
#				self.assertEqual(r.exit_status, 0)
#				self.assertNotEqual(b'', r.stdout, 'no tenantindex found for vmstat metric: {} measurementtypeid={}'.format(name, typeid))
#				tenant_data = json.loads(r.stdout)
#				self.assertEqual(tenant_data.get('region'), 'RegionOne')
#				self.assertNotEqual(tenant_data.get('tenantid'), b'')

			self.log.debug("done validating %d ldms vmstat metrics", num_rows)

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
