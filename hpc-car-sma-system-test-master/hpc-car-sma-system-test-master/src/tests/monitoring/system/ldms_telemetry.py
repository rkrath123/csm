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
from system.config import get_telemetry_request_url, get_telemetry_version

class LDMS(Test):

	"""
	LDMS vmstat compute metrics from telemetry-api
	:avocado: tags=funct,ldms
    """

	REQUEST_URL = get_telemetry_request_url()
	VERSION = get_telemetry_version()

	BATCHSIZE = 1048
	CONSUME_SECS = 120

	# 20 sec gaps are pretty common so increased it.
	VMSTAT_INTERVAL = 60
	VMSTAT_DIMENSIONS = {
		'product'   : 'shasta',
		'job_id'    : '0',
		'service'   : 'ldms',
	}

	@avocado.skipUnless("SMA_TEST_CONTAINER" in os.environ, 'This test must be run in sma-test container')
	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def test_vmstat_metrics_stream(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_vmstat_metrics_stream", 130294).get()

		batchsize = self.params.get('batch_size', default=self.BATCHSIZE)
		count = 0

		request = 'batchsize={}&count={}'.format(batchsize, count)
		url = '''{}/{}/stream/cray-node?{}'''.format(self.REQUEST_URL, self.VERSION, request)
		self.log.debug(url)

		total_metrics = 0

		end_time = time.time() + self.CONSUME_SECS
		self.log.debug("collecting ldms vmstat metrics for %d secs", self.CONSUME_SECS)
		self.log.debug("starting at {}".format(str(datetime.datetime.now())))
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
		l_timestamp = 0

		for event in client.events():

			# count number of events received
			num_events += 1

			self.log.debug("Received metrics event {}".format(num_events))
			data = json.loads(event.data)
#			self.log.debug(data)

			num_messages = 0
			c_timestamp = 0

			for message in data['metrics']['messages']:
				metric = message.get('metric')
				num_messages += 1

				dimensions = metric.get('dimensions', {})
				if dimensions.get('component') == 'cray_vmstat' and dimensions.get('system') == 'compute':
					self.log.debug(metric)
					total_metrics += 1

					timestamp = metric.get('timestamp')
					self.log.debug('timestamp= {}'.format(datetime.datetime.fromtimestamp(float(timestamp)/1000.0).strftime('%c')))
#					self.assertGreaterEqual(timestamp, l_timestamp, 'unexpected timestamp: {} {}'.format(timestamp, l_timestamp))
					if timestamp > c_timestamp:
						c_timestamp = timestamp

					self.assertEqual(dimensions.get('product'), self.VMSTAT_DIMENSIONS.get('product'))
					self.assertEqual(dimensions.get('job_id'), self.VMSTAT_DIMENSIONS.get('job_id'))
					self.assertEqual(dimensions.get('service'), self.VMSTAT_DIMENSIONS.get('service'))

					if l_timestamp != 0:
						interval = int((c_timestamp - l_timestamp)/1000.0)
						self.assertGreater(self.VMSTAT_INTERVAL, interval, 'long vmstat metric interval {}'.format(interval))

					l_timestamp = c_timestamp

			self.log.debug('asked for {} messages got {} vmstat compute metrics found= {}'.format(batchsize, num_messages, total_metrics))

			if time.time() > end_time:
				break

		self.assertNotEqual(total_metrics, 0, 'no vmstat compute metrics were found')

		elapsed_time = timer.get_time_hhmmss()
		self.log.debug("done at {}".format(str(datetime.datetime.now())))
		self.log.debug("{} vmstat metrics in {}".format(total_metrics, elapsed_time))

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
