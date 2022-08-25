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
from system import kafka
from system.whiteboard import Whiteboard
from system.config import get_telemetry_request_url, get_telemetry_version

if "SMA_TEST_CONTAINER" in os.environ:
	from pykafka import KafkaClient
	from pykafka.common import OffsetType

class Perf(Test):

	"""
	Telemetry API performance tests
	:avocado: tags=perf
	"""

	REQUEST_URL = get_telemetry_request_url()
	VERSION = get_telemetry_version()

	TIME_LIMIT = 15    # mins
	BATCHSIZE = 1024

	KAFKA_CONSUMER_TIMEOUT_MS = 120000

	@avocado.skipUnless("SMA_TEST_CONTAINER" in os.environ, 'This test must be run in sma-test container')
	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def test_perf_stream_metrics(self):
		# TestRail's test case ID
		board = Whiteboard("test_perf_stream_metrics", 130435)
		self.whiteboard = board.get()

		time_limit = self.params.get('iterations', default=self.TIME_LIMIT)
		batchsize = self.params.get('batch_size', default=self.BATCHSIZE)
		count = 0

		request = 'batchsize={}&count={}'.format(batchsize, count)
		url = '''{}/{}/stream/cray-node?{}'''.format(self.REQUEST_URL, self.VERSION, request)
		self.log.debug(url)

		total_metrics = 0

		end_time = datetime.datetime.now() + datetime.timedelta(minutes=time_limit)
		start_time = datetime.datetime.now()
		self.log.debug("starting at {}".format(str(datetime.datetime.now())))

		while True:

			if datetime.datetime.now() >= end_time:
				break

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
				data = json.loads(event.data)

				num_messages = 0
				for message in data['metrics']['messages']:
					metric = message.get('metric')
					num_messages += 1
					total_metrics += 1

				if datetime.datetime.now() >= end_time:
					break
				else:
					continue

		# metric rate per sec
		secs = (datetime.datetime.now() - start_time).seconds
		rate = float(total_metrics) / float(secs)

		self.log.debug("{} metrics in {} secs rate= {}".format(total_metrics, secs, rate))
		board.add_value('metrics_per_sec', rate)
		self.log.debug(board.log())
		self.whiteboard = board.get()

	def test_perf_kafka_metrics(self):
		# TestRail's test case ID
		board = Whiteboard("test_perf_kafka_metrics", 130436)
		self.whiteboard = board.get()

		time_limit = self.params.get('iterations', default=self.TIME_LIMIT)
		try:
			broker_name = os.environ.get('KAFKA_HOSTNAME', 'kafka')
			broker_port = os.environ.get('KAFKA_BROKER_PORT', '9092')
			broker_list = "%s:%s" % (broker_name, broker_port)
			self.log.debug("Kafka broker list is '%s", broker_list)
			kafka.wait_for_topic(broker_list, 'cray-node')

			kafka_client = KafkaClient(hosts=broker_list)
		except (ValueError, KeyError, TypeError):
			self.log.debug("kafka connection failed")

		topic = kafka_client.topics['cray-node']
		self.assertGreater(len(topic.partitions), 0)

		metrics_topic = topic.get_simple_consumer(
			consumer_group='metrics_topic',
			auto_offset_reset=OffsetType.LATEST,
			reset_offset_on_start=True,
			consumer_timeout_ms=self.KAFKA_CONSUMER_TIMEOUT_MS
		)

		total_metrics = 0

		end_time = datetime.datetime.now() + datetime.timedelta(minutes=time_limit)
		start_time = datetime.datetime.now()
		self.log.debug("starting at {}".format(str(datetime.datetime.now())))

		try:
			for message in metrics_topic:
				if message:
					metric = json.loads(message.value)
					total_metrics += 1

				if datetime.datetime.now() >= end_time:
					break
			else:
				self.log.debug("kafka consumer timeout")
		except (ValueError, KeyError, TypeError):
			self.log.debug("kafka connection failed")

		# metric rate per sec
		secs = (datetime.datetime.now() - start_time).seconds
		rate = float(total_metrics) / float(secs)

		self.log.debug("{} metrics in {} secs rate= {}".format(total_metrics, secs, rate))
		board.add_value('metrics_per_sec', rate)
		self.log.debug(board.log())
		self.whiteboard = board.get()

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
