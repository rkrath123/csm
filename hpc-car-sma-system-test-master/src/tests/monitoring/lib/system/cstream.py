#!/usr/bin/env python

import re
import json
import yaml

from avocado.utils import process
from avocado.utils import astring

# is cstream configured and running
def is_configured():

	is_configured = False

	cmd = 'kubectl -n sma get configmap'
	r = process.run(cmd)
	if re.search(r'cstream-config', r.stdout_text):
		uid = get_uid()
		if uid is not None:
			cmd = 'kubectl -n sma get pod ' + uid + ' -o jsonpath="{.status.phase}"'
			r = process.run(cmd)
			if r.exit_status == 0 and r.stdout_text == 'Running':
				is_configured = True
	return is_configured

# get cstream pod's uid
def get_uid():
	uid = None

	cmd = 'kubectl -n sma get pods'
	r = process.run(cmd)
	if r.exit_status == 0:
		if re.search(r'cstream', r.stdout_text):
			cmd = 'kubectl -n sma get pod -l app=cstream -o jsonpath="{.items[0].metadata.name}"'
			r = process.run(cmd)
			if r.exit_status == 0:
				uid = astring.to_text(r.stdout)
	return uid

def get_clusterstor_names():
	system_names = []

	cmd = 'kubectl -n sma get configmap cstream-config -o json'
	r = process.run(cmd)
	if r.exit_status == 0:
		configmap = json.loads(r.stdout_text)
		data = configmap.get('data')
		site_config = yaml.load(data.get('site_config.yaml'))
		print site_config
		for system in site_config['snx_systems']:
			name = system.get('system') or None
			system_names.append(name)

	return system_names

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
