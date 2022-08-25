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

class Zookeeper(Test):

	"""
	:avocado: tags=funct,health
	Zookeeper health checks.
	"""

	CLIENT_PORT = 21810
	EXPECTED_ZOOKEEPER_FOLLOWERS = 2
	EXPECTED_ZOOKEEPERS = [
		"cluster-zookeeper-0",
		"cluster-zookeeper-1",
		"cluster-zookeeper-2"
	]

	def setUp(self):
		self.log.debug(Zookeeper.__doc__)

	def tearDown(self):
		self.log.debug("tearDown")

	def test_zookeeper_health(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_zookeeper_health", 108596).get()

		leader = 0
		followers = 0
		zookeeper_id = 0
		for uid in self.EXPECTED_ZOOKEEPERS:
			cmd = '''kubectl -n sma exec {} -t -c zookeeper -- /opt/kafka/zookeeper_healthcheck.sh'''.format(uid)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)

			cmd = '''kubectl -n sma exec {} -t -c zookeeper -- /bin/sh -c "echo stat | nc 127.0.0.1 {}"'''.format(uid, self.CLIENT_PORT+zookeeper_id)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			stdout_lines = astring.to_text(r.stdout)
			self.log.debug(stdout_lines)
			self.assertIn('Mode', stdout_lines)
			if (stdout_lines.find('leader') != -1):
				leader += 1
			if (stdout_lines.find('follower') != -1):
				followers += 1
			zookeeper_id += 1

		self.assertEqual(leader, 1)
		self.assertEqual(followers, self.EXPECTED_ZOOKEEPER_FOLLOWERS)

#  k exec cluster-zookeeper-0 -t -c zookeeper -- /bin/sh -c "echo stat | nc 127.0.0.1 21810 | grep Mode"

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
