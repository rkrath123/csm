#!/usr/bin/env python
import json
import yaml
import argparse
from monascaclient import client as monascaclient
from monascaclient import ksclient
import monascaclient.exc as exc
import pprint
import socket
import datetime

# alarms_container=$(docker images --format="{{.ID}}" cray_sma/alarms)
# docker run --name=check_alarms --network=sma_default -v /etc/sma-data:/etc/sma-data -v /root/sma-sos:/root/sma-sos --rm $alarms_container /root/sma-sos/check_alarms.py

def get_site_config():

	SITE_CONFIG_FILE = "/etc/sma-data/etc/site_config.yaml"
	site_config = None
	try:
		with open(SITE_CONFIG_FILE) as yaml_file:
			site_config = yaml.load(yaml_file)

	except IOError:
		print("get_site_config - I/O error.  No credentials file.")
	except ValueError:
		print("get_site_config - Could not convert value")
	except:
		print("get_site_config - Unexpected error")

	return site_config

def get_predefined_alarms():

	PREDEFINED_ALARMS_FILE = "/config/definitions.yml.j2"
	predefined_alarms = None
	try:
		with open(PREDEFINED_ALARMS_FILE) as yaml_file:
			predefined_alarms = yaml.load(yaml_file)

	except IOError:
		print("get_predefined_alarms - I/O error.  No credentials file.")
	except ValueError:
		print("get_predefined_alarms - Could not convert value")
	except:
		print("get_predefined_alarms - Unexpected error")

	return predefined_alarms

class PredefinedAlarm(object):

	def __init__(self, alarm):
		self.body = alarm
		self.name = self.body['name']

	def __repr__(self):
		match_by = ""
		for by in self.body['match_by']:
			match_by += by
			match_by += ","
		match_by = match_by[:-1]

		output = "%-42s [%s]" % (self.name, match_by)
		return output

	def alarm_name(self):
		return self.name

	def match_by(self):
		return self.body['match_by']

class AlarmDefinition(object):

	def __init__(self, alarm):
		self.body = alarm
		self.name = self.body['name']

	def __repr__(self):
		match_by = ""
		for by in self.body['match_by']:
			match_by += by
			match_by += ","
		match_by = match_by[:-1]

		output = "%-42s [%s]" % (self.name, match_by)
		return output

	def alarm_name(self):
		return self.name

	def match_by(self):
		return self.body['match_by']

class Alarm(object):

	def __init__(self, alarm, match_by, request):
		self.body = alarm
# 		pprint.pprint("{}".format(alarm))
		self.name = self.body['alarm_definition']['name']
		self.alarm_id = self.body['id']
		self.match_by = match_by
		self.system_name = ""
		metric_dimensions = alarm['metrics'][0]['dimensions']
		if 'system_name' in metric_dimensions:
			self.system_name = metric_dimensions['system_name']

		# check alarm history
		self.history = request.alarms.history(alarm_id=self.alarm_id)
#		if not self.history:
#			print "ERROR: no history found for alarm ", alarm_name, " ", alarm_id

	def __repr__(self):
		severity = self.body['alarm_definition']['severity']
		state = self.body['state']

		no_history = ''
		if not self.history:
			no_history = 'NO HISTORY'

		metric_name = self.body['metrics'][0]['name']
		metric_dimensions = self.body['metrics'][0]['dimensions']

#		pprint.pprint("{}".format(metric_dims))
		dimensions = ""
		for key in self.match_by:
			if key in metric_dimensions:
				dimensions += "%s=%s," % (key, metric_dimensions[key])
		dimensions = dimensions[:-1]

		output = "%-42s %-15s %-12s [%s]" % (self.name, state, no_history, dimensions)
		return output

	def get_alarm_id(self):
		return self.alarm_id

	def is_lifecycle_state_ok(self):
 		return self.body['lifecycle_state'] != "RESOLVED"

	def is_warning(self):
		warning = False

		if (self.body['state'] == "ALARM" and
			(self.body['alarm_definition']['severity'] == "LOW" or
			self.body['alarm_definition']['severity'] == "MEDIUM")):
			warning = True
		if self.body['state'] == "UNDETERMINED":
			warning = True

		return warning

	def is_critical(self):
		critical = False 

		if (self.body['state'] == "ALARM" and 
			(self.body['alarm_definition']['severity'] == "HIGH" or
			self.body['alarm_definition']['severity'] == "CRITICAL")):
			critical = True

		return critical

	def is_history_ok(self):
		ok = True
		if not self.history:
			ok = False
		return ok

def main():

	parser = argparse.ArgumentParser(description='check predefined alarm definitions and lists')

	parser.add_argument('-v', '--verbose',
		action='store_true', dest='verbose',
		default=False, help='enable verbose mode' )

	args = parser.parse_args()
	verbose = args.verbose
	
	site_config = get_site_config()
	auth = site_config['monasca_agent_auth']

	api_version = '2_0'
	creds = {'username': auth.get('OS_USERNAME') or None,
		'password': auth.get('OS_PASSWORD') or None,
		'project_name': auth.get('OS_PROJECT') or None,
		'region_name': "RegionOne",
		'service_type': "monitoring",
		'endpoint_type': "publicURL",
		'auth_url': auth.get('AUTH_URL') or None}

	_ksclient = ksclient.KSClient(**creds)
	try:
		monasca_client = monascaclient.Client(api_version, _ksclient.monasca_url, **creds)

	except exc.HTTPException as he:
		print("Error: " + str(he.message))
		exit(1)

#	now = datetime.datetime.now()
#	print now.strftime("%Y-%m-%d %H:%M")

	# Get list of predefined alarms
	predefined_alarms = get_predefined_alarms()
	body = predefined_alarms['alarm_definitions']

	definition_errors = 0

	predefined_alarms = []
	for alarm in body:
		predefined = PredefinedAlarm(alarm)
		predefined_alarms.append(predefined)

	# Get notifications list
	body = monasca_client.notifications.list()
	email_address = "none"
	if body:
		email_address = body[0]['address']
	print "notifications", email_address

	# Get list of monasca alarm definitions
	alarm_definitions = []
	body = monasca_client.alarm_definitions.list()

	for d in body:
		definition = AlarmDefinition(d)
		alarm_definitions.append(definition)

	# Should find a monasca alarm definition for each predefined alarm
	for predefined in predefined_alarms:
		alarm_name = predefined.alarm_name()
		if verbose:
			print "predefined:", predefined
		monasca = [x for x in alarm_definitions if x.name == alarm_name]
		if len(monasca) == 1:
			if verbose:
				print "monasca:", monasca[0]
			if predefined.match_by() != monasca[0].match_by():
				print "ERROR: alarm match by clauses do not match: ", alarm_name
				definition_errors += 1
		else:
			print "ERROR: no monasca alarm definition found: ", alarm_name
			definition_errors += 1

	print(str(definition_errors) + " alarm definition errors")
	if verbose:
		print(str(len(predefined_alarms)) + " predefined alarms")
		print(str(len(alarm_definitions)) + " monasca alarm-definitions")

	# Get list of monasca alarm state
	alarms = []
	body = monasca_client.alarms.list()
#	pprint.pprint("{}".format(body))

	for a in body:
		alarm_name = a['alarm_definition']['name']
 		definition = [x for x in alarm_definitions if x.name == alarm_name]
#		print type(definition)
#		print definition[0]
		if len(definition) != 1:
			print "ERROR: invalid number ", len(definition), " of definitions for alarm ", alarm_name
			exit(1)

		alarm = Alarm(a, definition[0].match_by(), monasca_client)
		alarms.append(alarm)

	total = 0
	warnings = 0
	criticals = 0
	history_errors = 0
	sorted_alarms = sorted(alarms, key=lambda Alarm: (Alarm.name, Alarm.system_name))

	for alarm in sorted_alarms:
		print alarm
		total += 1
		if alarm.is_lifecycle_state_ok():
			if alarm.is_warning():
				warnings += 1
			if alarm.is_critical():
				criticals += 1
			if not alarm.is_history_ok():
				history_errors += 1
	print
	print(str(total) + " total alarms")
	print(str(criticals) + " critical "+ str(warnings) + " warning ")
	print(str(history_errors) + " alarm history errors")

# monasca alarm-definition-show

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
