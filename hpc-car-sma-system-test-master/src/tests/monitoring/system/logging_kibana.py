#!/usr/bin/env python

import os
import sys
import json
import time

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.config import get_kibana_url
from system.whiteboard import Whiteboard

class Kibana(Test):

	"""
	:avocado: tags=funct,logging
	Kibana health checks.
	"""

	EXPECTED_DEFAULT_KIBANA_INDEX = "shasta-logs"

	def setUp(self):
		self.log.debug(Kibana.__doc__)

	def tearDown(self):
		self.log.debug("tearDown")

	def test_kibana_health(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_kibana_health", 108576).get()

		cmd = 'curl ' + get_kibana_url() + '/api/status'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)

		status = json.loads(r.stdout)
		self.assertIn(status.get('name', None), "kibana")

		overall = status.get('status').get('overall')
		self.assertIn(overall.get('state', None), "green")

	def test_default_kibana_index(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_default_kibana_index", 108574).get()

		# default index
		cmd = 'curl elasticsearch:9200/.kibana/config/5.6.4'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		stdout_lines = astring.to_text(r.stdout)
		self.assertIn("defaultIndex", stdout_lines)
		self.assertIn(self.EXPECTED_DEFAULT_KIBANA_INDEX, stdout_lines)

#   Test kibana index-patterns?
#   curl -s -XGET 'elasticsearch:9200/.kibana/index-pattern/snx-logs_*'

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
