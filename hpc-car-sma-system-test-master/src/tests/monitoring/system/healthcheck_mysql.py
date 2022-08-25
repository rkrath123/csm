#!/usr/bin/env python

import sys
import os

# FIXME
# kubectl -n sma exec mysql-69b87c5f5f-25r67 -t -- /bin/sh -c "echo 'show index from jobevent_tbl' | mysql -t jobevents -u root -psecretmysql"

from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.whiteboard import Whiteboard

class MySQL(Test):

	"""
	:avocado: tags=health
	MySQL health checks.
	"""

	EXPECTED_DATABASES = [
		"grafana",
		"jobevents"
	]

	EXPECTED_TABLES = {
		"grafana"   : [ "dashboard", "data_source", "user" ],
		"jobevents" : [ "jobevent_tbl" ]
	}

	def setUp(self):
		self.log.debug(MySQL.__doc__)

		cmd = 'kubectl -n sma get pod -l app=mysql -o jsonpath="{.items[0].metadata.name}"'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.uid = astring.to_text(r.stdout)

	def tearDown(self):
		self.log.debug("tearDown")

	def test_show_databases(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_show_databases", 108591).get()

		cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo 'show databases' | mysql -u root -psecretmysql"'''.format(self.uid)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		stdout_lines = astring.to_text(r.stdout)

		for database in self.EXPECTED_DATABASES:
			self.assertIn(database, stdout_lines)

	def test_show_tables(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_show_tables", 108592).get()

		for database in self.EXPECTED_DATABASES:
			cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo 'show tables' | mysql -t {} -u root -psecretmysql"'''.format(self.uid, database)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			stdout_lines = astring.to_text(r.stdout)

			tables = self.EXPECTED_TABLES.get(database)
			for i in range(len(tables)):
				table = tables[i]
				self.log.debug(table)
				self.assertIn(table, stdout_lines)

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
