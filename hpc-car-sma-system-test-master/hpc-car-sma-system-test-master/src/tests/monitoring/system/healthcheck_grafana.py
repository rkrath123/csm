#!/usr/bin/env python

import os
import json
import sys

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.config import get_grafana_url
from system import dbschema
from system.whiteboard import Whiteboard
from system.config import get_postgres_pod

class Grafana(Test):

	"""
	:avocado: tags=health
	Grafana health checks.
	"""

	POSTGRES_INTERVAL = '5 minutes'

	EXPECTED_VIEWS = [
		"ldms_iostat_grafana_view",
		"ldms_vmstat_grafana_view",
		"seastream_linux_grafana_view",
		"seastream_lustre_grafana_view",
		"seastream_lustre_calc_grafana_view",
		"jobstats_device_grafana_view",
		"jobstats_calc_grafana_view",
		"jobstats_score_grafana_view",
		"jobstats_jobcnt_grafana_view"
	]

	def setUp(self):
		self.log.debug(Grafana.__doc__)
		self.postgres = get_postgres_pod()

	def tearDown(self):
		self.log.debug("tearDown")

	def test_grafana_health(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_grafana_health", 108677).get()

		cmd = get_grafana_url() + '/api/health'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.log.debug(r.stdout_text)
		json_data = json.loads(r.stdout_text)
		self.assertEqual(json_data.get('database'), 'ok')
		self.assertEqual(json_data.get('version'), '6.3.5')

	def test_grafana_views(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_grafana_views", 108678).get()

		r = dbschema.get_views(self.postgres)
		self.assertEqual(r.exit_status, 0)

		for view in self.EXPECTED_VIEWS:
			self.assertIn(view, r.stdout_text)

	def test_ldms_vmstat_grafana_view(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_vmstat_grafana_view", 108679).get()

		expected_measurementnames = [
			"cray_vmstat",
			"cray_iostat",
			"cray_mellanox",
			"cray_ethtool",
		]

		query = '''select json_agg(row_to_json(ldms_view_data)) FROM (select * from sma.ldms_vmstat_grafana_view WHERE \"ts\" >= NOW() - INTERVAL \'{}\') ldms_view_data'''.format(self.POSTGRES_INTERVAL)
		cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(self.postgres, query)
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.assertNotEqual(b'', r.stdout, 'no data found in grafana view')
		try:
			view_data = json.loads(r.stdout)
		except ValueError:
			self.fail('unable to load data - no data in table')
		for data in view_data:
			self.log.debug(data)
			found_it = False
			for measurement in expected_measurementnames:
				if measurement in data.get('measurementname'):
					found_it = True
					break
			self.assertTrue(found_it, 'invalid measurementname found: %s' % (data.get('measurementname')))
			self.assertTrue(data.get('systemname') == 'compute' or data.get('systemname') == 'sms', 'invalid systemname found: %s' % (data.get('systemname')))
			if data.get('systemname') == 'compute':
				self.assertIn('nid', data.get('hostname'), 'invalid hostname found: %s' % (data.get('hostname')))
			else:
				self.assertIn('sma-ldms-sms', data.get('hostname'), 'invalid hostname found: %s' % (data.get('hostname')))

# FIXME
#seastream_linux_grafana_view
#seastream_lustre_grafana_view
#seastream_lustre_calc_grafana_view

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
