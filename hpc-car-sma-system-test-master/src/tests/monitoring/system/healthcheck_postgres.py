#!/usr/bin/env python

# FIXME
# \di table_name
# SELECT * FROM pg_indexes WHERE tablename = 'mytable';

import sys
import os
import json

from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.config import get_postgres_pod
from system.whiteboard import Whiteboard

# @fail_on(process.CmdError)
class PostgreSQL(Test):

	"""
	:avocado: tags=funct,health
	PostgreSQL health checks.
	"""

	POD = "craysma-postgres-cluster-0"

	EXPECTED_USERS = [
		"postgres",
		"smauser"
	]

	EXPECTED_TABLES = [
		"ldms_data",
		"ldms_device",
		"ldms_host",
		"jobstats_data",
		"seastream_data",
		"seastream_device",
		"seastream_host",
		"measurementfull",
		"measurementsource",
		"system",
		"tenant",
		"version"
	]

	EXPECTED_PRIMARY_KEYS = {
		"ldms_data"         : [ "ts", "measurementtypeid", "systemid", "hostid", "deviceid", "tenantindex" ],
		"ldms_device"       : [ "deviceid" ],
		"ldms_host"         : [ "hostid" ],
		"seastream_data"    : [ "ts", "measurementtypeid", "systemid", "hostid", "deviceid", "tenantindex" ],
		"seastream_device"  : [ "deviceid" ],
		"seastream_host"    : [ "hostid" ],
		"jobstats_data"     : [ "ts", "measurementtypeid", "systemid", "hostid", "deviceid", "tenantindex", "job_id" ],
		"measurementfull"   : [ "measurementtypeid" ],
		"measurementsource" : [ "measurementtypeid" ],
		"system"            : [ "systemid" ],
		"tenant"            : [ "tenantindex" ],
		"version"           : [ "component_name", "major_num", "minor_num", "gen_num" ]
	}

	PRIMARY_KEY_QUERY = ("SELECT c.column_name, c.ordinal_position "
                         "FROM information_schema.key_column_usage AS c "
                         "LEFT JOIN information_schema.table_constraints AS t "
                         "ON t.constraint_name = c.constraint_name "
                         "WHERE t.table_name = \\'{}\\' AND t.constraint_type = \\'PRIMARY KEY\\'")

	INDEX_QUERY = ("SELECT indexname,indexdef FROM pg_indexes WHERE tablename = \\'{}\\'")

	EXPECTED_INDEXES = {
		"ldms_data"         : [ "ldms_data_pkey", "ldms_data_ts_index", "ldms_data_systemid_index", "ldms_data_hostid_index", "ldms_data_deviceid_index", "ldms_data_tenantidx_index", "ldms_data_measurementtypeid_index" ],
		"ldms_device"       : [ "ldms_device_pkey", "ldms_device_hostid_devicename_key" ],
		"ldms_host"         : [ "ldms_host_pkey", "ldms_host_systemid_hostname_key" ],
        "seastream_data"    : [ "seastream_data_pkey", "seastream_data_ts_index", "seastream_data_systemid_index", "seastream_data_hostid_index", "seastream_data_deviceid_index", "seastream_data_tenantidx_index",
		                        "seastream_data_measurementtypeid_index", "jobstats_data_ts_index", "jobstats_data_systemid_index", "jobstats_data_hostid_index", "jobstats_data_deviceid_index",
		                        "jobstats_data_tenantidx_index", "jobstats_data_measurementtypeid_index" ],
		"seastream_device"  : [ "seastream_device_pkey", "seastream_device_systemid_devicename_key" ],
		"seastream_host"    : [ "seastream_host_pkey", "seastream_host_systemid_hostname_key" ],
        "jobstats_data"     : [ "jobstats_data_pkey" ],
		"measurementfull"   : [ "measurementfull_pkey", "measurementfull_measurementname_key" ],
		"measurementsource" : [ "measurementsource_pkey", "measurementsource_measurementname_key" ],
		"system"            : [ "system_pkey", "system_systemname_key" ],
		"tenant"            : [ "tenant_pkey", "tenant_tenantid_key" ],
		"version"           : [ "version_pkey" ]
	}

	EXPECTED_SCHEMA_VERSION = {
		"component_name" : "DB_SCHEMA",
		"major_num"      : 2
	}

	def setUp(self):
		self.log.debug(PostgreSQL.__doc__)

		self.uid = get_postgres_pod()

	def tearDown(self):
		self.log.debug("tearDown")

	def test_show_tables(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_show_tables", 108593).get()

		cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo '\dt sma.*' | psql -d sma -U postgres"'''.format(self.uid)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)

		for table_name in self.EXPECTED_TABLES:
			cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo '\dt sma.{}' | psql -d sma -U postgres"'''.format(self.uid, table_name)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			stdout_lines = astring.to_text(r.stdout)
			self.assertIn(table_name, stdout_lines)
			self.assertIn("smauser", stdout_lines)

	def test_list_users(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_list_users", 108659).get()

		cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo '\du sma.*' | psql -d sma -U postgres"'''.format(self.uid)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		stdout_lines = astring.to_text(r.stdout)

		for user in self.EXPECTED_USERS:
			self.assertIn(user, stdout_lines)

	def test_version_table(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_version_table", 108658).get()

		query = '''select row_to_json\(version\) FROM \(select \* from sma.version\) version'''
		cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo {} | psql -t -d sma -U postgres"'''.format(self.uid, query)
		self.log.debug(cmd)
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		self.log.debug(r.stdout)
		json_data = json.loads(r.stdout)
		self.assertEqual(json_data.get('component_name'), self.EXPECTED_SCHEMA_VERSION.get('component_name'))
		self.assertEqual(json_data.get('major_num'), self.EXPECTED_SCHEMA_VERSION.get('major_num'))

	def test_primary_keys(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_primary_keys", 108594).get()

		for table_name in self.EXPECTED_TABLES:
			query = self.PRIMARY_KEY_QUERY.format(table_name)
			cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo {} | psql -d sma -U postgres"'''.format(self.uid, query)
			self.log.debug(cmd)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			stdout_lines = astring.to_text(r.stdout)

			if table_name in self.EXPECTED_PRIMARY_KEYS:
				keys = self.EXPECTED_PRIMARY_KEYS.get(table_name)
				for i in range(len(keys)):
					key = keys[i]
					self.log.debug(key)
					self.assertIn(key, stdout_lines)

	def test_table_indexes(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_table_indexes", 108685).get()

		for table_name in self.EXPECTED_TABLES:
			query = self.INDEX_QUERY.format(table_name)
			cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo {} | psql -d sma -U postgres"'''.format(self.uid, query)
			self.log.debug(cmd)
			r = process.run(cmd)
			self.assertEqual(r.exit_status, 0)
			stdout_lines = astring.to_text(r.stdout)

			if table_name in self.EXPECTED_INDEXES:
				keys = self.EXPECTED_INDEXES.get(table_name)
				for i in range(len(keys)):
					key = keys[i]
					self.log.debug(key)
					self.assertIn(key, stdout_lines)

	def test_cluster_health(self):
		# TestRail's test case ID
#		self.whiteboard = Whiteboard("test_table_indexes", 108685).get()

		master = 0
		replica = 0

		master_node = None
		replica_node = None

		cmd = 'kubectl -n sma get pod -l application=spilo -L spilo-role -o json'
		r = process.run(cmd)
		if r.exit_status == 0:
			data = json.loads(r.stdout_text)
			for item in data.get('items'):
				metadata = item.get('metadata')
				spec = item.get('spec')

				self.log.debug(metadata.get('name'))
				self.log.debug(spec.get('nodeName'))

				label = item.get('metadata').get('labels')
				self.log.debug(label)

				if label.get('application') == 'spilo' and label.get('pgsubsystem') == 'sma-postgres':
					if label.get('spilo-role') == 'master':
						master += 1
						master_node = spec.get('nodeName')
					if label.get('spilo-role') == 'replica':
						replica += 1
						replica_node = spec.get('nodeName')

		self.assertEqual(master, 1, 'did not find a master in postgres cluster')
		self.assertEqual(replica, 1, 'did not find a replica in postgres cluster')
		self.assertNotEqual(master_node, replica_node)

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
