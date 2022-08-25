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
from system.ha import HA
from system.whiteboard import Whiteboard
from system.config import get_telemetry_request_url, get_telemetry_version

IS_CSTREAM_CONFIGURED = cstream.is_configured()

class Logs(Test):

	"""
	Reading logs from Kafka with high availability checks
	:avocado: tags=unsafe,ha
	"""

	REQUEST_URL = get_telemetry_request_url()
	VERSION = get_telemetry_version()

	BATCHSIZE = 2048
	CONSUME_SECS = 300

	def setUp(self):
		self.log.debug("setUp")
		self.log.debug("{}/{}".self.REQUEST_URL, self.VERSION)

	def tearDown(self):
		self.log.debug("tearDown")

	def consume_rsyslog_topic(self):

		batchsize = self.params.get('batch_size', default=self.BATCHSIZE)
		consume_secs = self.params.get('consume_secs', default=self.CONSUME_SECS)
		count = 0

		request = 'batchsize={}&count={}'.format(batchsize, count)
		url = '''{}/{}/stream/rsyslog?{}'''.format(self.REQUEST_URL(), self.VERSION, request)
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
			self.fail('telemetry api request failed')

		try:
			client = sseclient.SSEClient(response)
		except Exception as e:
			self.assertRaises(e)

		num_events = 0
		num_json_load_errors = 0

		for event in client.events():
			# count number of events received
			num_events += 1
			self.log.debug("Received rsyslog event {}".format(num_events))
			try:
				data = json.loads(event.data)
			except ValueError:
				self.log.debug('unable to load rsyslog data')
				self.log.debug(data)
				num_json_load_errors += 1
				continue

			num_messages = 0
			# WA SMA-4264 - expected rsyslog stream name
			for log in data['metrics']['messages']:
				num_messages += 1

				if log.get('tag') == 'docker_container':
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

	@avocado.skip("test not ready")
	def test_ha_zk_kafka_consume_logs(self):
		# TestRail's test case ID
#		board = Whiteboard("test_container_logs", 130443)
#		self.whiteboard = board.get()

		ha = HA()
# loop over all pods?
		deleted = ha.delete_pod(getattr(HA, "ZK-KAFKA"))
		self.assertNotEqual(deleted, None, 'failed to delete a strimzi pod')
		self.log.debug("deleted pod %s", deleted)

		consume_rsyslog_topic()

	@avocado.skip("test not ready")
	def test_ha_kafka_consume_logs(self):
		# TestRail's test case ID
#		board = Whiteboard("test_container_logs", 130443)
#		self.whiteboard = board.get()

# kill 2 kafka
		ha = HA()
		deleted = ha.delete_pod(getattr(HA, "KAFKA"))
		self.assertNotEqual(deleted, None, 'failed to delete a kafka pod')
		self.log.debug("deleted pod %s", deleted)

		consume_rsyslog_topic()

	@avocado.skip("test not ready")
	def test_ha_zookeeper_consume_logs(self):
		# TestRail's test case ID
#		board = Whiteboard("test_container_logs", 130443)
#		self.whiteboard = board.get()

		ha = HA()
		deleted = ha.delete_pod(getattr(HA, "ZOOKEEPER"))
		self.assertNotEqual(deleted, None, 'failed to delete a zookeeper pod')
		self.log.debug("deleted pod %s", deleted)

		consume_rsyslog_topic()

	@avocado.skip("test not ready")
	def test_ha_telemetry_consume_logs(self):
		# TestRail's test case ID
#		board = Whiteboard("test_container_logs", 130443)
#		self.whiteboard = board.get()

		ha = HA()
		deleted = ha.delete_pod("telemetry")
		self.assertNotEqual(deleted, None, 'failed to delete a telemetry pod')
		self.log.debug("deleted pod %s", deleted)

		consume_rsyslog_topic()

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
