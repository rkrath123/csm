#!/usr/bin/env python

import os
import json
import time
import sys

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system import dbschema
from system import cstream
from system.whiteboard import Whiteboard

IS_CONFIGURED = cstream.is_configured()

class Latency(Test):

	"""
	Check difference in time between when the job metrics are generated on the ClusterStor 
    and when derived metrics are calculated.  Normally the latency is 2-6 seconds.  If it 
	trends upwards cstream is in trouble and eventually there will be a backlog of unprocessed metrics.
	:avocado: tags=perf
	"""

	LATENCY_METRIC_NAME = "cray_job.latency_time"
	HIGH_LATENCY_TIME = 10

	@avocado.skipIf(IS_CONFIGURED == False, "cstream is not configured")
	def setUp(self):
		self.log.debug("setUp")

	def tearDown(self):
		self.log.debug("tearDown")

	@avocado.skip("system clocks on dev shasta nodes are not ntp synced")
	def test_cstream_jobstat_latency(self):
		# TestRail's test case ID
		board = Whiteboard("test_cstream_jobstat_latency", 130530)
		self.whiteboard = board.get()

		cmd = 'kubectl -n sma get pod -l app=postgres -o jsonpath="{.items[0].metadata.name}"'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		postgres = astring.to_text(r.stdout)

		typeid = dbschema.get_measurement_typeid(postgres, 'cray_job.latency_time')
		jobstat_latency = {}
		filesystem_names = cstream.get_clusterstor_names()

		for system_name in filesystem_names:
			systemid = dbschema.get_system_id(postgres, system_name)
			self.log.debug('Query job latency time for {} systemid={}'.format(system_name, systemid))

			query = '''select json_agg(row_to_json(jobstats_data)) FROM (select count(*) from sma.jobstats_data WHERE measurementtypeid = {} AND systemid = {} AND (value > {} OR value <0)) jobstats_data'''.format(typeid, systemid, self.HIGH_LATENCY_TIME)
			cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			try:
				json_data = json.loads(r.stdout)
				count = json_data[0].get('count', -1)
				jobstat_latency[system_name] = count
				if count != 0:
					query = '''select json_agg(row_to_json(jobstats_data)) FROM (select ts,value from sma.jobstats_data WHERE measurementtypeid = {} AND systemid = {} AND (value > {} OR value <0)) jobstats_data'''.format(typeid, systemid, self.HIGH_LATENCY_TIME)
					cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
					r = process.run(cmd)
					self.assertEqual(r.exit_status, 0)
 					try:
						results = []
 						json_data = json.loads(r.stdout)
 						for data in json_data:
 							results.append(data)
 						jobstat_latency[system_name + '_results'] = results
 					except ValueError:
 						self.fail('unable to load json data', r.stdout_text)
			except ValueError:
				self.fail('unable to load json data', r.stdout_text)

		# record results to whiteboard
		self.log.debug(jobstat_latency)
		board.add_value('jobstat_latency', jobstat_latency)
		self.log.debug(board.log())
		self.whiteboard = board.get()

		# check results
		for system_name in filesystem_names:
			self.assertEqual(jobstat_latency[system_name], 0, 'latency time for job metrics to reach kafka is over {} secs on {}'.format(self.HIGH_LATENCY_TIME, system_name))

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
