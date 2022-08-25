#!/usr/bin/python

import argparse
import sys
import json
import time
import datetime
import socket
import sseclient
import requests
import traceback

from avocado.utils import process
from avocado.utils import astring
import config

def shell(cmd):
	return subprocess.check_output(cmd, shell=True).decode()

def get_auth_token():

	# FIXME - needs error checking
	# Get client secret from k8s
	cmd = "kubectl get secrets admin-client-auth -ojsonpath='{.data.client-secret}' | base64 -d"
	secret = shell(cmd)

	# Use client secret to get authentication token from keycloak
	keycloak_token_url = get_keycloak_token_url()
	cmd = '''curl -s -d grant_type=client_credentials -d client_id=admin-client -d client_secret={} {}'''.format(k8s_secret, keycloak_token_uri)
	results = shell(cmd)

	# Get access token from  dictionary
	data = json.loads(results)
	auth_token = data["access_token"]

	return auth_token

class BearerAuth(requests.auth.AuthBase):
	token = None
	def __init__(self, token):
		self.token = token
	def __call__(self, r):
		r.headers["authorization"] = "Bearer " + self.token
		return r

class TelemetryClient(object):

	API_NAME = 'telemetry-api'
	API_VERSION = 'v1'
	ENDPOINT = 'kafka'
	RECONNECT_DELAY_SECS = 60

	def __init__(self, hostname, batch_size, count, topic_name):

		self._url = 'https://' + hostname + '/' + self.API_NAME + '/' + self.API_VERSION + "/kafka/%s?batchsize=%d&count=%d" % \
			(topic_name, batch_size, count)

		self._ping_api = 'https://' + hostname + '/' + self.API_NAME+ '/' + self.API_VERSION + '/ping'

		self._batch_size = batch_size
		self._count = count
		self._topic = topic_name
		self._total_metrics = 0
		self._total_events = 0
		self._auth = BearerAuth(get_auth_token())

		self._disable_request_warnings()

	def _disable_request_warnings(self):
		""" prevent 'Insecure Request Warning' messages from being sent to stdout for each request """

		version = requests.__version__.split('.')
		if int(version[0]) == 2:
			from requests.packages.urllib3.exceptions import InsecureRequestWarning
			requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

	def get_time_str(self):
		return str(datetime.datetime.now())

	def unpack_data(self, messages):
		""" Unpack message batch, count metrics """

		num_metrics = 0
		try:
			json_data = json.loads(messages)
		except ValueError:
			print('Failed to parse event: %s', messages)
			sys.exit(1)
        
		for metric in json_data['metrics']['messages']:
			num_metrics += 1
			if Verbose:
 				print json.dumps(metric, sort_keys=True, indent=4)

		return num_metrics

	def get_version(self):
		""" ping endpoint to get api version """

		return None

	def is_alive(self):
		""" check if endpoint is alive """

		state = "endpoint ping FAILED"
		try:
			session = requests.Session()
			session.headers.update({"Content-Type": "application/json"})
			session.headers.update(self._get_header)
			response = session.get(self._ping_api, auth=self._auth, verify=False, timeout=5)
			response.raise_for_status()
			if Verbose:
				print(response)
		except requests.exceptions.HTTPError as e:
			print ("[%s] %s %s" % (self.get_time_str(), state, str(e)))
			return False
		except requests.exceptions.RequestException as e:
			print ("[%s] %s %s" % (self.get_time_str(), state, str(e)))
			return False

		if response.status_code == requests.codes.ok:
			state = "endpoint ping is OK"
		print ("[%s] %s %s" % (self.get_time_str(), state, str(response.status_code)))

		return response.status_code == requests.codes.ok

	def run(self):
		""" Consume messages """

		print "ENTER consume messages"
		while True:

			try:

				print "SSEClient request " + self._url
				response = requests.get(self._url, stream=True, headers=self._get_header, verify=False)
				if response.status_code != requests.codes.ok:
					print ("[%s] Connect failed %d: '%s'" % (self.get_time_str(), response.status_code, self._url))
					sys.exit(1)

				client = sseclient.SSEClient(response)
				for event in client.events():
					num_metrics = self.unpack_data(event.data)
					self._total_metrics += num_metrics
 					print ("[%s] %s %d metrics" % (self.get_time_str(), event, num_metrics))
					if self._batch_size != num_metrics:
						print 'Expected %d metrics got %d' % (self._count, num_metrics)
						sys.exit(1)
					self._total_events += 1
					if self._count > 0 and self._total_events == self._count:
						print "count finished"
						raise APIError()

			except APIError, e:
				break

			except Exception as exc:
				print ("[%s] metrics event FAILED" % (self.get_time_str()))
				while self.is_alive() == False:
					time.sleep(self.RECONNECT_DELAY_SECS)
				print ("[%s] attempting reconnect" % (self.get_time_str()))
# 				continue

#			finally:
#				break

		print "EXIT consume messages"
		return

class APIError(Exception):
	pass

class LoopCountExhausted(Exception):
	pass

fqdn = socket.getfqdn()

parser = argparse.ArgumentParser(description='Telemetry API SSE Kafka client')
parser.add_argument('-b', '--batchsize',
	type=int, dest='batch_size', help='Number of metrics per response',
	required=True)

parser.add_argument('-c', '--count',
	type=int, dest='count', help='Count of responses before done', 
	required=True)

parser.add_argument('-s', '--server',
	type=str, dest='hostname',
	default=fqdn, help='View Server Hostname (Use FQDN)')

parser.add_argument('-t', '--topic',
	type=str, dest='topic',
	default='metrics', help='Kafka topic name')

parser.add_argument('-v', '--verbose',
	action='store_true', dest='verbose',
	default=False, help='enable verbose mode' )

args = parser.parse_args()
pprint.pprint("{}".format(args))

batch_size = args.batch_size
count = args.count
hostname = args.hostname
topic = args.topic
Verbose = args.verbose

# expected number of metrics
total_metrics = count * batch_size

metrics = APIClient(hostname, batch_size, count, topic)
metrics.is_alive()
metrics.run()
metrics.is_alive()

if count != 0:
	if count != metrics._total_events or total_metrics != metrics._total_metrics:
		print "FAILED"
		print 'Expected %d events got %d' % (count, metrics._total_events)
		print 'Expected %d metrics got %d' % (total_metrics, metrics._total_metrics)
		sys.exit(1)

sys.exit(0)

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
