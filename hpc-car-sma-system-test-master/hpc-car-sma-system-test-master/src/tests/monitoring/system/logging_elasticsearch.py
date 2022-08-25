#!/usr/bin/env python

import os
import sys
import json
import time

from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.whiteboard import Whiteboard

class Elasticsearch(Test):

	"""
	:avocado: tags=funct,logging
	Elasticsearch health checks.
	"""

	EXPECTED_ES_INDICES = [
		"shasta-logs",
		".kibana"
	]

	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	def test_es_health(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_es_health", 108590).get()

		cmd = 'curl elasticsearch:9200?pretty=true'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		stdout_lines = astring.to_text(r.stdout)
		self.assertIn("name",         stdout_lines)
		self.assertIn("cluster_name", stdout_lines)
		self.assertIn("cluster_uuid", stdout_lines)
		self.assertIn("tagline",      stdout_lines)

	def test_es_indices(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_es_indices", 108573).get()

		cmd = 'curl elasticsearch:9200/_cat/indices'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		stdout_lines = astring.to_text(r.stdout)

		for index in self.EXPECTED_ES_INDICES:
			self.assertIn(index, stdout_lines)

	def test_es_shasta_logs(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_es_shasta_logs", 108575).get()

		cmd = "curl -S -s 'elasticsearch:9200/shasta-logs*/_search?size=1000&sort=@timereported:desc\&pretty'"
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		json_data = json.loads(r.stdout_text)

		# check if request timed out
		timed_out = json_data.get('timed_out')
		self.assertFalse(timed_out)

		# total number of messages 
		hits = json_data.get('hits')
		total1 = hits['total']
		self.log.debug('Total hits: %d', total1)
		self.assertGreater(total1, 0)

		# validate message content
		message = hits['hits'][0]
		self.assertIn('shasta-logs', message.get('_index'))
		self.assertEqual(message.get('_type'), 'events')

		# wait and repeat
		self.log.debug("Sleeping for 15 seconds")
		time.sleep(15)

		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		json_data = json.loads(r.stdout_text)

		# check if request timed out
		timed_out = json_data.get('timed_out')
		self.assertFalse(timed_out)

		# total number of messages 
		hits = json_data.get('hits')
		total2 = hits['total']
		self.log.debug('Total hits: %d', total2)
		self.assertGreater(total2, 0)
		self.assertGreater(total2, total1)

		# validate message content
		message = hits['hits'][0]
		self.assertIn('shasta-logs', message.get('_index'))
		self.assertEqual(message.get('_type'), 'events')

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
