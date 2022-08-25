#!/usr/bin/python

# Telemetry-API client to stream and store logs from SMF

# Install SSE package on log server
# pip install requests==2.18.4
# pip install sseclient-py==1.7
# pip install urllib3==1.22

# Generate Bearer Token on Shasta BIS node (ncn-w001)
# . /tmp/sma-sos/sma_tools
# sma_get_auth_token > auth_token
# Move Bearer Token to log server.

# Access Telemetry API from a log server
# export ACCESS_TOKEN=$(cat auth_token)
# logger.py -g https://thanos-ncn-w001:30443 -a auth_token -l containers 2>containers.out
# logger.py -g https://thanos-ncn-w001:30443 -a auth_token -l syslog 2>syslog.out

# log counts - total, stderr
# cat containers.out |  awk '{ print $1 " " $2 }' | sort --reverse --key 2 --numeric
# cat containers.out |  awk '{ print $1 " " $3 }' | sort --reverse --key 2 --numeric

import argparse
import sys
import json
import time
import signal
import sseclient
import requests
import urllib3
import datetime
import re
import pprint
import gzip
import os
import shutil
import errno
import sys
import logging

DEFAULT_LOG_DIR="/var/log/sma-test/log"

CONTAINERS_LOGNAME = "containers"
SYSLOG_LOGNAME = "syslog"
CLUSTERSTOR_LOGNAME = "clusterstor"

start_time = 0

num_json_load_errors = 0
num_unicode_errors = 0

container_messages = {}
container_stderr = {}
syslog_messages = {}
clusterstor_messages = {}

def print_to_stderr(*args):
	sys.stderr.write(' '.join(map(str,args)) + '\n')

def summary(total_logs=0):
	global start_time

	global num_json_load_errors
	global num_unicode_errors

	global container_messages
	global container_stderr
	global syslog_messages
	global clusterstor_messages

	logging.warning("summary at {}".format(str(datetime.datetime.now())))
	if total_logs > 0:
		logging.warning('%d logs' % (total_logs))

	if len(container_messages) > 0:
		print ""
		for pod in container_messages:
			stderr = 0
			if pod in container_stderr:
				stderr = container_stderr[pod]
			logging.warning("%-100s %d %d stderr" % (pod, container_messages[pod], stderr))

	if len(syslog_messages) > 0:
		logging.warning("")
		for node in syslog_messages:
			logging.warning("%-20s %d" % (node, syslog_messages[node]))

	if len(clusterstor_messages) > 0:
		print ""
		for host in clusterstor_messages:
			logging.warning("%-20s %d" % (host, clusterstor_messages[host]))

	logging.warning("")
	logging.warning("json load errors= {}".format(num_json_load_errors))
	logging.warning("unicode errors= {}".format(num_unicode_errors))

	return

class BearerAuth(requests.auth.AuthBase):
	token = None
	def __init__(self, token):
		self.token = token
	def __call__(self, r):
		r.headers["authorization"] = "Bearer " + self.token
		return r

class Logger(object):

	SERVICE_NAME = 'apis/sma-telemetry-api/v1'
	RECONNECT_DELAY_SECS = 60
	BATCHSIZE = 2048
	COUNT = 0
 	LOG_ROTATE_SIZE = 1<<30   # 1 GB

	def __init__(self, gateway, auth_token, topic, log_type, log_dir, verbose):

		self._auth = BearerAuth(auth_token)
		self._verbose = verbose
		self._topic = topic
		self._log_type = log_type

		self._total_logs = 0

		request = '/stream/{}?batchsize={}&count={}'.format(self._topic, self.BATCHSIZE, self.COUNT)
		self._url = gateway + '/' +  self.SERVICE_NAME + request
		self._ping_api = gateway + '/' + self.SERVICE_NAME + "/ping"
		print self._url

		if log_type == 'containers':
			self._log_path = log_dir + "/" + CONTAINERS_LOGNAME
		elif log_type == 'syslog':
			self._log_path = log_dir + "/" + SYSLOG_LOGNAME
		elif log_type == 'clusterstor':
			self._log_path = log_dir + "/" + CLUSTERSTOR_LOGNAME
		else:
			print("unknown or unsupported topic")
			sys.exit(1)

		self._log_file = open(self._log_path, "a+")

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

	def log_rotate(self):

		b = self._log_file.tell()
		if b > self.LOG_ROTATE_SIZE:
			self._log_file.close()
			now = datetime.datetime.now()
			timestamp = now.strftime("%Y%m%d.%H%M")
			log_gz = self._log_path + "-" + timestamp + ".gz"
			print ("[%s] Rotating log file %s to %s" % (self.get_time_str(), self._log_path, log_gz))

			# rotate and gzip log file
			in_data = open(self._log_path, "rb").read()
			f_out = gzip.open(log_gz, "wb")
			f_out.write(in_data)
			f_out.close()

			os.unlink(self._log_path)
	 		self._log_file = open(self._log_path, "a+")
			summary(self._total_logs)

	def container_logit(self, log):
		global container_messages
		global num_unicode_errors

		timestamp = log.get('timereported', '')
 		logfile = log.get('hostname', '')
 		apname = log.get('tag', '')
		pod = re.sub(r'\-[a-zA-Z0-9]*.log$', '', logfile)
		message = log.get('message', '').encode('utf-8')
 		message = message.rstrip("\n\r")
		stream = log.get('stream', '')
		try:
   			self._log_file.write('%-32s %-8s [%s] %s\n' % (timestamp, stream, pod, message.encode('utf-8')))
#			self._log_file.write('%-32s %-8s [%-100s] %s\n' % (timestamp, stream, pod, message.encode('utf-8')))
		except (UnicodeDecodeError, UnicodeEncodeError), e:
 			self._log_file.write('{} {} {} {}\n'.format(timestamp, stream, pod, message))
			num_unicode_errors += 1

		# number of messages for each container
		num = 0
		if pod in container_messages:
			num = container_messages[pod]
		num += 1
		container_messages[pod] = num

		num = 0
		if stream == 'stderr':
			if pod in container_stderr:
				num = container_stderr[pod]
			num += 1
			container_stderr[pod] = num


	def syslog_logit(self, log):
		global syslog_messages
		global num_unicode_errors

 		timestamp = log.get('timereported', '')
		priority = log.get('priority', '')
		severity = log.get('severity', '')
		hostname = log.get('hostname', '')
		tag = log.get('tag', '')
		message = log.get('message', '')
		try:
			self._log_file.write('%-25s %-8s %-5s [%-9s] %s%s\n' % (timestamp, severity, priority, hostname, tag, message))
		except (UnicodeDecodeError), e:
			self._log_file.write('{} {} {} {} {}\n'.format(timestamp, severity, hostname, tag, message.decode('utf-8')))
			num_unicode_errors += 1
		except (UnicodeEncodeError), e:
			self._log_file.write('{} {} {} {} {}\n'.format(timestamp, severity, hostname, tag, message.encode('utf-8')))
			num_unicode_errors += 1

		# number of messages for each node(hostname)
		num = 0
		if hostname in syslog_messages:
			num = syslog_messages[hostname]
		num += 1
		syslog_messages[hostname] = num

	def clusterstor_logit(self, log):
		global clusterstor_messages

		timestamp = log.get('timereported', '')
		severity = log.get('severity', '')
		hostname = log.get('hostname', '')
		message = log.get('message', '')
		self._log_file.write('%-25s %-10s %-12s %s\n' % (timestamp, severity, hostname, message))

		# number of messages for each hostname
		num = 0
		if hostname in clusterstor_messages:
			num = clusterstor_messages[hostname]
		num += 1
		clusterstor_messages[hostname] = num

	def run(self):
		""" Consume logs and write to ascii text file """

		global num_json_load_errors

		while True:

			try:
				response = requests.get(self._url, stream=True, auth=self._auth, verify=False)
				if response.status_code != requests.codes.ok:
					print ("[%s] Connect failed %d: '%s'" % (self.get_time_str(), response.status_code, self._url))
					sys.exit(1)

				client = sseclient.SSEClient(response)
				for event in client.events():
					try:
						data = json.loads(event.data)
					except ValueError:
						print('unable to load json data')
						print event.data.encode('utf-8')
						num_json_load_errors += 1
						continue

					num_logs = 0
					for log in data['metrics']['messages']:
						if self._verbose:
							pprint.pprint("{}".format(log))
						num_logs += 1
						if self._log_type == 'containers': 
							if log.get('tag', '') == 'docker_container':
								self.container_logit(log)
							else:
								pprint.pprint("ill-formed log message: {}".format(log))

						elif self._log_type == 'syslog':
							self.syslog_logit(log)

						elif self._log_type == 'clusterstor': 
							self.clusterstor_logit(log)


					self._total_logs += num_logs
					print ("[%s] %s %d logs (total= %d)" % (self.get_time_str(), event, num_logs, self._total_logs))
					self.log_rotate()

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

def shutdown(signum, frame):
	global num_json_load_errors

# FIXME close log file
	summary()
	print "stopped at {}".format(str(datetime.datetime.now()))
	sys.exit(num_json_load_errors)

	return

parser = argparse.ArgumentParser(description='Telemetry API client to stream and store logs from SMF')

parser.add_argument('-g', '--gateway',
	type=str, help='API gateway service "https://api-gw-service-nmn.local" if internal to Shasta cluster or "https://ncn-w001:30443" if external.', required=True)

parser.add_argument('-a', '--auth_token',
	type=str, help="File containing Bearer Token to set in the Authorization header for every HTTP request", required=True)

parser.add_argument('-l', '--log_type',
	type=str, help='log type (containers, syslog, clusterstor)', required=True)

parser.add_argument('-d', '--log_dir',
	type=str, help='log directory', required=False, default=DEFAULT_LOG_DIR)

parser.add_argument('-v', '--verbose',
	action='store_true', help='Enable for verbose modes.', required=False, default=False)

args = parser.parse_args()

try:
	f = open(args.auth_token, "r")
	auth_token = f.readline()
	f.close()
except IOError:
	print "failed to open Bearer Token file"
	sys.exit(1)

log_dir = args.log_dir
log_type = args.log_type

if not os.path.exists(log_dir):
	try:
		os.mkdir(log_dir)
	except OSError as e:
		if e.errno != errno.EEXIST:
			raise

signal.signal(signal.SIGINT, shutdown)

if log_type == 'containers':
	topic = 'cray-logs-containers'
elif log_type == 'syslog':
	topic = 'cray-logs-syslog'
elif log_type == 'clusterstor':
	topic = 'cray-logs-clusterstor'
else:
	print "unknown log type: %s" % (log_type)

# Use logging as a simple way to write to stderr.
logging.basicConfig(format='%(message)s')

# print "Consume '%s' logs from SMF and write to an ascii text file" % log_type
print "Gateway: %s" % args.gateway
print "Log directory: %s" % log_dir
print "Stream name (topic): %s" % topic
print "Bearer token: %s" % auth_token

start_time = datetime.datetime.now()
print "started at {}".format(str(start_time))

logs = Logger(args.gateway, auth_token, topic, log_type, log_dir, args.verbose)
logs.run()

sys.exit(num_json_load_errors)

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
