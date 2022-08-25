#!/usr/bin/env python

import os
import sys
import json
import time
import datetime
import re
from elasticsearch import Elasticsearch

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.whiteboard import Whiteboard

class Latency(Test):

	"""
	Measure log latency using tcpflood
	:avocado: tags=long,logging
	"""

	# Total number of log messages sent
 	NUM_MESSAGES = 200000

	# tcpflood arguments
 	TCPFLOOD_BURST_ARGS  = "-S 0 200000 1"
 	TCPFLOOD_STEADY_ARGS = "-S 30 40000 5"

	# How long to wait for messages to show up in elasticsearch (minutes)
	ELASTICSEARCH_WAIT_TIME = 15

	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def uuid(self, stdout_lines):
		uuid = re.findall(r'uuid: \S+$', stdout_lines, re.M)
		self.assertNotEqual(uuid, -1)
		uuid = uuid[0].strip('uuid: ')
		return uuid

	# Finished sending log messages.  Calculate rate.
	def done(self, stdout_lines, board):
		self.log.debug(stdout_lines)
		total = re.findall(r'total:\s*\S+$', stdout_lines, re.M)
		self.assertNotEqual(total, -1)
		secs = total[0].strip('total:\s*')
		num_messages = self.params.get('num_messages', default=self.NUM_MESSAGES)
		rate = float(num_messages) / float(secs)

		self.log.debug("{} messages sent in {} secs rate= {}".format(num_messages, secs, rate))
		board.add_value('sent messages', num_messages)
		board.add_value('sent secs', secs)
		board.add_value('sent rate', rate)
		self.log.debug(board.log())
		self.whiteboard = board.get()

	# Wait for messages in elasticsearch.  Calculate rate.
	def wait(self, stdout_lines, board):
#		self.log.debug("wait before starting elasticsearch query")
#		time.sleep(60)

		uuid = self.uuid(stdout_lines)
		wait_time = self.params.get('elasticsearch_wait_time', default=self.ELASTICSEARCH_WAIT_TIME)
		expected_messages = self.params.get('num_messages', default=self.NUM_MESSAGES)

		es = Elasticsearch("elasticsearch:9200")
		end_time = datetime.datetime.now() + datetime.timedelta(minutes=wait_time)
		start_time = datetime.datetime.now()
		self.log.debug("starting elasticsearch query at {}".format(str(datetime.datetime.now())))

		last = 0
		total_messages = 0
		while True:
			if datetime.datetime.now() >= end_time:
				break
			res = es.search(body={"query": {"match": {"log": "{}".format(uuid)}}})
			total_messages = res['hits']['total']
			self.log.debug("{} messages in elasticsearch".format(total_messages))

			# dropping es messages so trying to capture time for messages persisted
			rate = 0
			if total_messages > last:
				secs = (datetime.datetime.now() - start_time).seconds
				rate = float(total_messages) / float(secs)
				last = total_messages
			if total_messages >= expected_messages:
				break
			time.sleep(10)

		if total_messages > 0:
			self.log.debug("{} elasticsearch messages in {} secs rate= {}".format(total_messages, secs, rate))
			board.add_value('elasticsearch messages', total_messages)
			board.add_value('elasticsearch secs', secs)
			board.add_value('elasticsearch rate', rate)
			self.log.debug(board.log())
			self.whiteboard = board.get()

		self.assertEqual(total_messages, expected_messages)

	@avocado.skip("disabled for triage")
	def test_log_burst_latency(self):
		# TestRail's test case ID
		board = Whiteboard("test_log_burst_latency", 131511)
		self.whiteboard = board.get()

		tcpflood_args = self.params.get('tcpflood_burst_args', default=self.TCPFLOOD_BURST_ARGS)
		cmd = '''/tests/monitoring/utils/tcpflood_generator.sh {}'''.format(tcpflood_args)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		stdout_lines = astring.to_text(r.stdout)
		self.log.debug(stdout_lines)
		self.done(stdout_lines, board)
		self.wait(stdout_lines, board)

	@avocado.skip("disabled for triage")
	def test_log_steady_latency(self):
		# TestRail's test case ID
		board = Whiteboard("test_log_steady_latency", 131512)
		self.whiteboard = board.get()

		tcpflood_args = self.params.get('tcpflood_steady_args', default=self.TCPFLOOD_STEADY_ARGS)
		cmd = '''/tests/monitoring/utils/tcpflood_generator.sh {}'''.format(tcpflood_args)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		stdout_lines = astring.to_text(r.stdout)
		self.log.debug(stdout_lines)
		self.done(stdout_lines, board)
		self.wait(stdout_lines, board)

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
