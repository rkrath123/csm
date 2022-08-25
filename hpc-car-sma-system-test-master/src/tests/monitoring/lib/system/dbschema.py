#!/usr/bin/env python

import json

from avocado.utils import process
from avocado.utils import astring

# describe postgres table:  \d TABLE_NAME

# get all table views in postgres
def get_views(postgres_uid):
	query = ("SELECT viewname FROM pg_catalog.pg_views "
			 "WHERE schemaname NOT IN \(\\'pg_catalog\\', \\'information_schema\\'\)")
	cmd = '''kubectl -n sma exec {} -t -- /bin/sh -c "echo {} | psql -d sma -U postgres"'''.format(postgres_uid, query)
	print cmd
	r = process.run(cmd)
	return r

# get tenant table row from tenant index 
def get_tenant(postgres, index):
	query = '''select row_to_json(tenant) FROM (select * from sma.tenant WHERE tenant.tenantindex= {}) tenant'''.format(index)
	cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
	print cmd
	r = process.run(cmd)
	return r

# get system table row from system id 
def get_system(postgres, systemid):
	query = '''select row_to_json(system) FROM (select * from sma.system WHERE system.systemid= {}) system'''.format(systemid)
	cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
	print cmd
	r = process.run(cmd)
	return r

# get system id from name
def get_system_id(postgres, name):
	systemid = None
	query = '''select row_to_json(system) FROM (select systemid from sma.system WHERE system.systemname= \'{}\') system'''.format(name)
	cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
	r = process.run(cmd)
	if r.exit_status == 0:
		try:
			print r.stdout
			system = json.loads(r.stdout)
			systemid = system.get('systemid', None)
		except ValueError:
			print "failed to load json data"

	return systemid

# get ldms host table row from host id 
def get_ldms_host(postgres, hostid):
	query = '''select row_to_json(host) FROM (select * from sma.ldms_host WHERE ldms_host.hostid= {}) host'''.format(hostid)
	cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
	print cmd
	r = process.run(cmd)
	return r

# get cstream device table row from device id 
def get_cstream_device(postgres, index):
	query = '''select row_to_json(device) FROM (select * from sma.seastream_device WHERE seastream_device.deviceid= {}) device'''.format(index)
	cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
	print cmd
	r = process.run(cmd)
	return r

# get clusterstor host table row from host id 
def get_clusterstor_host(postgres, hostid):
	query = '''select row_to_json(host) FROM (select * from sma.seastream_host WHERE seastream_host.hostid= {}) host'''.format(hostid)
	cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
	print cmd
	r = process.run(cmd)
	return r

# get measurement type id for name
def get_measurement_typeid(postgres, name):
	typeid = None

	query = '''select json_agg(row_to_json(data)) FROM (select measurementtypeid from sma.measurementsource where measurementname = \'{}\') data'''.format(name)
	cmd = '''kubectl -n sma exec {} -t -- psql -t -d sma -U postgres -c "{}"'''.format(postgres, query)
	print cmd
	r = process.run(cmd)
	if r.exit_status == 0:
		try:
			print r.stdout
			json_data = json.loads(r.stdout)
			measurement = json_data[0]
			typeid = measurement.get('measurementtypeid', None)
		except ValueError:
			print "failed to load json data"

	return typeid

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
