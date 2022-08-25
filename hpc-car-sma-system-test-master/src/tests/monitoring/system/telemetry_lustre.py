#!/usr/bin/env python

import os
import json
import time
import socket
import requests
import sseclient
import datetime
import sys

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.timer import Timer
from system.whiteboard import Whiteboard
from system import cstream
from system.config import get_telemetry_request_url, get_telemetry_version

IS_CONFIGURED = cstream.is_configured()

class Lustre(Test):

	"""
	ClusterStor Lustre metrics from telemetry-api
	:avocado: tags=funct,clusterstor
	"""

	REQUEST_URL = get_telemetry_request_url()
	VERSION = get_telemetry_version()

	BATCHSIZE = 512
	COUNT = 5

	ERROR_INTERVAL = 120
	WARN_INTERVAL = 10

	CALCULATED_METRICS = [
		'cray_storage.calculated_metadata_ops',
		'cray_storage.calculated_read_bytes',
		'cray_storage.calculated_write_bytes',
	]

	METRICS = [
		'cray_storage.close_rate',
		'cray_storage.getattr_rate',
		'cray_storage.mkdir_rate',
		'cray_storage.open_rate',
		'cray_storage.read_bytes_rate',
		'cray_storage.unlink_rate',
		'cray_storage.write_bytes_rate'
	]

	DIMENSIONS = {
		'product'   : 'ClusterStor',
		'service'   : 'storage',
		'component' : 'lustre',
	}

	@avocado.skipUnless("SMA_TEST_CONTAINER" in os.environ, 'This test must be run in sma-test container')
	@avocado.skipIf(IS_CONFIGURED == False, "cstream is not configured")
	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def test_lustre_metrics_stream(self):
		# TestRail's test case ID
		board = Whiteboard("test_lustre_metrics_stream", 130549)
		self.whiteboard = board.get()

		batchsize = self.params.get('batch_size', default=self.BATCHSIZE)
		count = self.params.get('count', default=self.COUNT)

		request = 'batchsize={}&count={}'.format(batchsize, count)
		url = '''{}/{}/stream/cray-lustre?{}'''.format(self.REQUEST_URL, self.VERSION, request)
		self.log.debug(url)

		filesystem_names = cstream.get_clusterstor_names()

		for system_name in filesystem_names:

			total_metrics = 0
			system_metrics = []

			self.log.debug("starting {} at {}".format(system_name, str(datetime.datetime.now())))
			timer = Timer()

			try:
				response = requests.get(url, stream=True, verify=False)
			except Exception as e:
				self.assertRaises(e)

			try:
				client = sseclient.SSEClient(response)
			except Exception as e:
				self.assertRaises(e)

			num_events = 0

			for event in client.events():
				# count number of events received
				num_events += 1
				self.log.debug("Received metrics event {} of {}".format(num_events, count))
 				data = json.loads(event.data)

				num_messages = 0

				for message in data['metrics']['messages']:
					metric = message.get('metric')
					num_messages += 1

					name = metric.get('name')
					if not name in self.METRICS + self.CALCULATED_METRICS:
						continue

					dimensions = metric.get('dimensions', {})
					if system_name != dimensions.get('system_name'):
						continue

 					self.log.debug(metric)
					total_metrics += 1
					system_metrics.append(metric)

					self.assertEqual(dimensions.get('product'), self.DIMENSIONS.get('product'))
					self.assertEqual(dimensions.get('service'), self.DIMENSIONS.get('service'))
					self.assertEqual(dimensions.get('component'), self.DIMENSIONS.get('component'))

					if name in self.METRICS:
						hostname = dimensions.get('hostname')
						self.assertTrue(system_name in hostname or hostname == 'unknown')
						device_type = dimensions.get('device_type')
						self.assertTrue(device_type == 'mdt' or device_type == 'ost')
						self.assertIn(device_type.upper(), dimensions.get('device'))

				if num_events == count:
					break
				else:
					continue

			self.assertEqual(count, num_events, 'expected {} got {} events'.format(count, num_events))
			self.assertNotEqual(total_metrics, 0, 'no lustre metrics were found')

			elapsed_time = timer.get_time_hhmmss()
			self.log.debug("done {} at {}".format(system_name, str(datetime.datetime.now())))
			self.log.debug("{} lustre metrics in {}".format(total_metrics, elapsed_time))

			warning_intervals = {}
			for name in self.METRICS + self.CALCULATED_METRICS:
				self.log.debug('timestamp checks for {}: {}'.format(system_name, name))
				l_timestamp = 0
				c_timestamp = 0
				warnings = []
				for metric in system_metrics:
					if name == metric.get('name'):
						timestamp = metric.get('timestamp')
						self.log.debug('found timestamp= {}'.format(datetime.datetime.fromtimestamp(float(timestamp)/1000.0).strftime('%c')))
						if timestamp > c_timestamp:
							c_timestamp = timestamp

						if l_timestamp != 0:
							last = datetime.datetime.fromtimestamp(float(l_timestamp)/1000.0).strftime('%Y-%m-%d %H:%M:%S')
							curr = datetime.datetime.fromtimestamp(float(c_timestamp)/1000.0).strftime('%Y-%m-%d %H:%M:%S')
							interval = int((c_timestamp - l_timestamp)/1000.0)
							self.assertGreater(self.ERROR_INTERVAL, interval, 'lustre metric {} interval is {} secs around {}'.format(name, interval, curr))
							if interval > self.WARN_INTERVAL:
								self.log.debug('warning lustre metric {} interval is {} secs around {}'.format(name, interval, curr))
								data = {'ts': curr, 'interval': interval}
								warnings.append(data)

						l_timestamp = c_timestamp

				if warnings:
					warning_intervals[name] = warnings
					self.log.debug('warnings= {}'.format(warning_intervals))

			# record timestamp warnings to whiteboard
			board.add_value(system_name, warning_intervals)

		self.log.debug(board.log())
		self.whiteboard = board.get()

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
