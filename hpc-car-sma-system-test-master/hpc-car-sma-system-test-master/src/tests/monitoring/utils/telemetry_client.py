#!/usr/bin/python

# Install SSE package on external server.
# pip install requests==2.18.4
# pip install sseclient-py==1.7
# pip install urllib3==1.22

# Generate Bearer Token on Shasta BIS node (ncn-w001)
# . /tmp/sma-sos/sma_tools
# sma_get_auth_token > auth_token
# Move Bearer Token to external server.
 
# Access Telemetry API from a server external to Shasta cluster.
# export ACCESS_TOKEN=$(cat auth_token)
# curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" https://thanos-ncn-w001:30443/apis/sma-telemetry-api/v1/ping | jq
# curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" https://thanos-ncn-w001:30443/apis/sma-telemetry-api/v1/stream | jq
# telemetry_client.py -g https://thanos-ncn-w001:30443 -n cray-node -a auth_token -c 512 -v
# telemetry_client.py -g https://thanos-ncn-w001:30443 -n cray-telemetry-temperature -a auth_token -c 512 -v
# telemetry_client.py -g https://thanos-ncn-w001:30443 -n cray-fabric-perf-telemetry -a auth_token -c 512 -v
 
# Access Telemetry API from inside the Shasta cluster.
# export ACCESS_TOKEN=$(cat auth_token)
# curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" api-gw-service-nmn.local/apis/sma-telemetry-api/v1/ping | jq
# curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" api-gw-service-nmn.local/apis/sma-telemetry-api/v1/stream | jq
# telemetry_client.py -g api-gw-service-nmn.local -n cray-node -a auth_token -c 512

import argparse
import sys
import json
import time
import datetime
import signal
import sseclient
import requests
import urllib3

class BearerAuth(requests.auth.AuthBase):
	token = None
	def __init__(self, token):
		self.token = token
	def __call__(self, r):
		r.headers["authorization"] = "Bearer " + self.token
		return r

class TelemetryClient(object):

	SERVICE_NAME = 'apis/sma-telemetry-api/v1'
	RECONNECT_DELAY_SECS = 60

	def __init__(self, gateway, batch_size, count, stream_name, stream_id, auth_token, verbose):

		self._batch_size = batch_size
		self._count = count
		self._stream_name = stream_name
		self._auth = BearerAuth(auth_token)
		self._verbose = verbose

		self._start_time = 0
		self._total_metrics = 0
		self._total_count = 0
		self._parameters = []

		self._url = gateway + '/' + self.SERVICE_NAME + "/stream/%s" % stream_name
		self._ping_api = gateway + '/' + self.SERVICE_NAME + "/ping"
        
		self._parameters.append('batchsize=%s' % batch_size)
		self._parameters.append('count=%s' % count)
		if stream_id is not None:
			self._parameters.append('stream_id=%s' % stream_id)

		# Build url
		for i in range(0,len(self._parameters)): 
			if i == 0:
				self._url += '?'
			else:
				self._url += '&'
			self._url += self._parameters[i]

		self._disable_request_warnings()

	def _disable_request_warnings(self):
		"""
		Prevent 'Insecure Request Warning' messages from being sent to
		stdout for each request().
		"""

		urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

	def get_time_str(self):
		return str(datetime.datetime.now())

	def is_alive(self):
		""" check if endpoint is alive """

		state = "ping failed"
		try:
			session = requests.Session()
			session.headers.update({"Content-Type": "application/json"})
			response = session.get(self._ping_api, auth=self._auth, verify=False, timeout=5)
			response.raise_for_status()
		except requests.exceptions.HTTPError as e:
			print ("[%s] %s %s" % (self.get_time_str(), state, str(e)))
			return False
		except requests.exceptions.RequestException as e:
			print ("[%s] %s %s" % (self.get_time_str(), state, str(e)))
			return False

		if response.status_code == requests.codes.ok:
			state = "ping is ok"
		print ("[%s] %s %s" % (self.get_time_str(), state, str(response.status_code)))
		return True

	def unpack_data(self, messages):
		""" Unpack batch, count metrics """

		num_metrics = 0
		try:
			json_data = json.loads(messages)
		except ValueError:
			print('Failed to parse event: %s', messages)
			return 0

		for metric in json_data['metrics']['messages']:
			num_metrics += 1
			if self._verbose:
				print json.dumps(metric, sort_keys=True, indent=4)

		return num_metrics

	def run(self):
		""" Consume metrics """

#		self._start_time = int(time.time())
		self._start_time = datetime.datetime.now()

		while True:

			try:

				print ("[%s] SSE client request '%s'" % (self.get_time_str(), self._url))
				response = requests.get(self._url, stream=True, auth=self._auth, verify=False)
				if response.status_code != requests.codes.ok:
					print ("[%s] Connect failed %d: '%s'" % (self.get_time_str(), response.status_code, self._url))
					sys.exit(1)

				client = sseclient.SSEClient(response)
				for event in client.events():
					num_metrics = self.unpack_data(event.data)
					self._total_metrics += num_metrics
					self._total_count += 1
					print ("[%s] %s %d metrics (%d of %d)" % (self.get_time_str(), event, num_metrics, self._total_count, self._count))
					if self._count > 0 and self._total_count == self._count:
						secs = (datetime.datetime.now() - self._start_time).seconds
 						rate = float(self._total_metrics) / float(secs)
 						print ("{} metrics in {} secs rate= {}".format(self._total_metrics, secs, rate))
						raise APIError()

			except APIError, e:
				break

			except Exception as exc:
				print ("[%s] metrics event FAILED" % (self.get_time_str()))
				while self.is_alive() == False:
					time.sleep(self.RECONNECT_DELAY_SECS)
				print ("[%s] attempting reconnect" % (self.get_time_str()))

		return

class APIError(Exception):
	pass

class LoopCountExhausted(Exception):
	pass

def shutdown(signum, frame):
	print 'shutting down....'
	sys.exit(0)
	return

parser = argparse.ArgumentParser(description='Telemetry API streaming client')

parser.add_argument('-g', '--gateway',
	type=str, help='API gateway service "https://api-gw-service-nmn.local" if internal to Shasta cluster or "https://ncn-w001:30443" if external.', required=True)

parser.add_argument('-c', '--batch_count',
	type=int, help='Batch count. Number of total batches. Default=4 (0 for continuous).',
	default=4, required=False)

parser.add_argument('-b', '--batch_size',
	type=int, help='Batch size. Number of metrics per batch. Default=8.',
	default=8, required=False)

parser.add_argument('-n', '--stream_name',
	type=str, help="Stream name/Kafka topic.", required=True)

parser.add_argument('-a', '--auth_token',
	type=str, help="File containing Bearer Token to set in the Authorization header for every HTTP request", required=True)

parser.add_argument('-i', '--stream_id',
	type=str, help='Stream ID for horizontal scaling.', required=False, default=None)

parser.add_argument('-v', '--verbose',
	action='store_true', help='Enable for verbose modes.', required=False, default=False)

args = parser.parse_args()

print "\nGateway: %s" % args.gateway
print "Batch size: %s" % args.batch_size
print "Batch count:  %s" % args.batch_count
print "Stream id: %s" % args.stream_id
print "Stream name (topic): %s" % args.stream_name
try:
	f = open(args.auth_token, "r")
	auth_token = f.readline()
	f.close()
	print "Bearer token: %s" % auth_token
except IOError:
	print "failed to open Bearer Token file"
	sys.exit(1)

signal.signal(signal.SIGINT, shutdown)

print 'Test streaming access through Telemetry API'
metrics = TelemetryClient(args.gateway, args.batch_size, args.batch_count, args.stream_name, args.stream_id, auth_token, args.verbose)
print "URL is '%s'\n" % metrics._url

if metrics.is_alive():
	metrics.run()
	print '%d/%d events/metrics' % (metrics._total_count, metrics._total_metrics)
else:
	print "ping failed"
	sys.exit(1)

sys.exit(0)

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
