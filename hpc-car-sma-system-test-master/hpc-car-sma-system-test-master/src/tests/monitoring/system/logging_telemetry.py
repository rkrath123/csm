#!/usr/bin/env python

import os
import json
import time
import socket
import requests
import sseclient
import datetime
import sys
import re

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.timer import Timer
from system import cstream
from system.whiteboard import Whiteboard
from system.config import get_telemetry_request_url, get_telemetry_version

IS_CSTREAM_CONFIGURED = cstream.is_configured()

class Logs(Test):

	"""
	Logs from telemetry-api
	"""

	REQUEST_URL = get_telemetry_request_url()
	VERSION = get_telemetry_version()

	BATCHSIZE = 2048
	CONSUME_SECS = 300

	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def test_telemetry_container_logs(self):
		"""
		:avocado: tags=funct,logging
		"""
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_container_logs", 130443).get()

#		board = Whiteboard("test_container_logs", 130443)
#		self.whiteboard = board.get()

		batchsize = self.params.get('batch_size', default=self.BATCHSIZE)
		consume_secs = self.params.get('batch_size', default=self.CONSUME_SECS)
		count = 0

		request = 'batchsize={}&count={}'.format(batchsize, count)
		url = '''{}/{}/stream/cray-logs-containers?{}'''.format(self.REQUEST_URL, self.VERSION, request)
		self.log.debug(url)

		total_logs = 0
		all_container_logs = []
		stderr_container_logs = []

		end_time = time.time() + consume_secs
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
		num_json_load_errors = 0

		for event in client.events():
			# count number of events received
			num_events += 1
			self.log.debug("Received logs containers event {}".format(num_events))
			try:
				data = json.loads(event.data)
			except ValueError:
				self.log.debug('unable to load json data')
				self.log.debug(data)
				num_json_load_errors += 1
				continue

			num_messages = 0
			# WA SMA-4264 - expected cray-logs-containers stream name
			for log in data['metrics']['messages']:
				num_messages += 1

				self.assertEqual(log.get('tag'), 'docker_container')
				all_container_logs.append(log)
				total_logs += 1
 				if log.get('stream') == 'stderr':
					stderr_container_logs.append(log)

			self.log.debug('asked for {} messages got {} total logs= {}'.format(batchsize, num_messages, total_logs))
			self.assertNotEqual(total_logs, 0, 'no container log messages were found')

			if time.time() > end_time:
				break
			else:
				continue

		elapsed_time = timer.get_time_hhmmss()
		self.log.debug("done at {}".format(str(datetime.datetime.now())))
		self.log.debug("{} container log messages in {}".format(total_logs, elapsed_time))
		self.assertEqual(num_json_load_errors, 0, '{} json load errors'.format(num_json_load_errors))

		self.log.debug('all container log messages')
		num_logs = 0
		for log in all_container_logs:
			timestamp = log.get('timereported', '')
			severity = log.get('severity', '')
# FIXME for rfc5624
			pod = log.get('filename', '').replace('/var/log/containers/', '')
			message = log.get('message', '').rstrip("\n\r")
			self.log.debug('{} {} {} {}'.format(timestamp, severity, pod, message.encode('utf-8')))
			num_logs += 1
		self.log.debug('{} all container log messages'.format(num_logs))

#		board.add_value('elapsed_time', elapsed_time)
#		board.add_value('num_logs', num_logs)
#		self.log.debug(board.log())
#		self.whiteboard = board.get()

	@avocado.skipIf(IS_CSTREAM_CONFIGURED == False, "cstream is not configured")
	def test_clusterstor_logs(self):
		"""
		:avocado: tags=funct,clusterstor
		"""
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_container_logs", 130580).get()

#		board = Whiteboard("test_clusterstor_logs", 130580)
#		self.whiteboard = board.get()

		batchsize = self.params.get('batch_size', default=self.BATCHSIZE)
		consume_secs = self.params.get('batch_size', default=self.CONSUME_SECS)
		count = 0

		request = 'batchsize={}&count={}'.format(batchsize, count)
		url = '''{}/{}/stream/cray-logs-clusterstor?{}'''.format(self.REQUEST_URL, self.VERSION, request)
		self.log.debug(url)

		total_logs = 0
		all_clusterstor_logs = []
		crit_clusterstor_logs = []
		err_clusterstor_logs = []

		end_time = time.time() + consume_secs
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
		num_json_load_errors = 0

		for event in client.events():
			# count number of events received
			num_events += 1
			self.log.debug("Received clusterstorlog event {}".format(num_events))
			try:
				data = json.loads(event.data)
			except ValueError:
				self.log_debug('unable to load json data')
				self.log.debug(data)
				num_json_load_errors += 1
				continue

			num_messages = 0
			# WA SMA-4264 - expected clusterstor stream name
			for log in data['metrics']['messages']:
				num_messages += 1
				total_logs += 1
				all_clusterstor_logs.append(log)

				if log.get('severity') == 'crit':
					crit_clusterstor_logs.append(log)
				elif log.get('severity') == 'err':
					err_clusterstor_logs.append(log)

			self.log.debug('asked for {} messages got {} total logs= {}'.format(batchsize, num_messages, total_logs))
			self.assertNotEqual(total_logs, 0, 'no clusterstor log messages were found')

			if time.time() > end_time:
				break
			else:
				continue

		elapsed_time = timer.get_time_hhmmss()
		self.log.debug("done at {}".format(str(datetime.datetime.now())))
		self.log.debug("{} clusterstor log messages in {}".format(total_logs, elapsed_time))
		self.assertEqual(num_json_load_errors, 0, '{} json load errors'.format(num_json_load_errors))

#		board.add_value('elapsed_time', elapsed_time)

		self.log.debug('all clusterstor log messages')
		num_logs = 0
		for log in all_clusterstor_logs:
			timestamp = log.get('timereported', '')
			severity = log.get('severity', '')
			hostname = log.get('hostname', '')
			message = log.get('message', '').rstrip("\n\r")
			self.log.debug('{} {} {} {}'.format(timestamp, severity, hostname, message.encode('utf-8')))
			num_logs += 1
		self.log.debug('{} all clusterstor log messages'.format(num_logs))
#		board.add_value('all_logs', num_logs)

		self.log.debug('crit clusterstor log messages')
		num_logs = 0
		for log in crit_clusterstor_logs:
			timestamp = log.get('timereported', '')
			severity = log.get('severity', '')
			hostname = log.get('hostname', '')
			message = log.get('message', '').rstrip("\n\r")
			self.log.debug('{} {} {} {}'.format(timestamp, severity, hostname, message.encode('utf-8')))
			num_logs += 1
		self.log.debug('{} crit clusterstor log messages'.format(num_logs))
#		board.add_value('crit_logs', num_logs)

		self.log.debug('err clusterstor log messages')
		num_logs = 0
		for log in err_clusterstor_logs:
			timestamp = log.get('timereported', '')
			severity = log.get('severity', '')
			hostname = log.get('hostname', '')
			message = log.get('message', '').rstrip("\n\r")
			self.log.debug('{} {} {} {}'.format(timestamp, severity, hostname, message.encode('utf-8')))
			num_logs += 1
		self.log.debug('{} err clusterstor log messages'.format(num_logs))
#		board.add_value('err_logs', num_logs)

#		self.log.debug(board.log())
#		self.whiteboard = board.get()

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
