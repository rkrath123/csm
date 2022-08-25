#!/usr/bin/env python

import os
import sys
import json
import time
import socket
import requests
import sseclient

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.whiteboard import Whiteboard
from system.config import get_telemetry_request_url, get_telemetry_version, get_telemetry_endpoints, get_telemetry_streams

class Telemetry(Test):

	"""
	:avocado: tags=funct,telemetry
	Telemetry health checks.
	"""

	REQUEST_URL = get_telemetry_request_url()
	VERSION = get_telemetry_version()
	EXPECTED_ENDPOINTS = get_telemetry_endpoints()
	EXPECTED_STREAMS = get_telemetry_streams()

	PING_ENDPOINT = VERSION + '/ping'

	FAKE_DATA_TESTS = [
		{ 'batchsize': 512,  'count': 100 },
		{ 'batchsize': 1024, 'count': 200 },
		{ 'batchsize': 2048, 'count': 300 },
		{ 'batchsize': 4096, 'count': 400 }
	]

	def setUp(self):
		cmd = 'kubectl -n sma get pod -l app=telemetry -o jsonpath="{.items[0].metadata.name}"'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.uid = astring.to_text(r.stdout)
		self.log.debug(self.uid)

	def tearDown(self):
		self.log.debug("tearDown")

	def test_telemetry_health(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_telemetry_health", 108763).get()

		cmd = '''kubectl -n sma exec {} -t -- curl -k -s https://localhost:8080/{}'''.format(self.uid, self.PING_ENDPOINT)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.assertNotEqual(b'', r.stdout, 'no data returned from api')
		try:
			data = json.loads(r.stdout_text)
		except ValueError:
			self.fail('unable to load json data')
		self.assertEqual(self.VERSION, data.get('api_version'))

		cmd = '''curl -k -s {}/{}'''.format(self.REQUEST_URL, self.PING_ENDPOINT)
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		data = json.loads(r.stdout_text)
		self.assertEqual(self.VERSION, data.get('api_version'))

	def test_telemetry_endpoints(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_telemetry_endpoints", 108764).get()

		cmd = '''curl -k -s {}/{}'''.format(self.REQUEST_URL, self.VERSION)
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.assertNotEqual(b'', r.stdout, 'no data returned from api')
		try:
			data = json.loads(r.stdout)
		except ValueError:
			self.fail('unable to load json data')
		num = 0
		self.log.debug(self.EXPECTED_ENDPOINTS)
		for endpoint in data.get('api_endpoints'):
			self.assertTrue(endpoint in self.EXPECTED_ENDPOINTS, 'unexpected endpoint found: %s' % (endpoint))
			num += 1
		self.assertEqual(num, len(self.EXPECTED_ENDPOINTS))

	def test_telemetry_streams(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_telemetry_streams", 108765).get()

		cmd = '''curl -k -s {}/{}/stream'''.format(self.REQUEST_URL, self.VERSION)
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.assertNotEqual(b'', r.stdout, 'no data returned from api')
		try:
			data = json.loads(r.stdout)
		except ValueError:
			self.fail('unable to load json data')
		for expected_stream in self.EXPECTED_STREAMS:
			found_it = False
			stream_name = expected_stream.get('name')
			scale_factor = expected_stream.get('scale_factor')
			for stream in data.get('streams'):
				self.log.debug(stream)
				if stream.get('name') == stream_name:
					found_it = True
					self.assertEqual(stream.get('scale_factor'), scale_factor, 'stream %s expected %d scale_factor got %d' % (stream_name, scale_factor, stream.get('scale_factor')))
					break
			self.assertTrue(found_it, 'missing stream: %s' % (stream_name))

	def test_telemetry_fake_data(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_telemetry_fake_data", 108766).get()

		for fake in self.FAKE_DATA_TESTS:
			self.log.debug(fake)
			batchsize = fake.get('batchsize')
			count = fake.get('count')

			request = 'batchsize={}&count={}'.format(batchsize, count)
			url = '''{}/{}/unit_test?{}'''.format(self.REQUEST_URL, self.VERSION, request)
			self.log.debug(url)

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
				try:
					data = json.loads(event.data)
				except ValueError:
					self.fail('unable to load json data')
				num_messages = 0
				for message in data['metrics']['messages']:
					metric = message.get('metric')
					self.assertEqual(metric.get('name'), 'cray_storage.calculated_write_bytes')
					self.assertEqual(metric.get('value'), 1312160)
					dimensions = metric.get('dimensions')
					self.assertEqual(dimensions.get('count'), num_messages)
					self.assertEqual(dimensions.get('product'), 'ClusterStor')
					self.assertEqual(dimensions.get('component'), 'lustre')
					self.assertEqual(dimensions.get('service'), 'storage')
					self.assertEqual(dimensions.get('device_type'), 'ost')
					num_messages += 1

				self.assertEqual(num_messages, batchsize)
				if num_events == count:
					break
				else:
					continue
			self.assertEqual(num_events, count)
#			self.log.debug(fake)

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
