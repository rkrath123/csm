#!/usr/bin/env python

import re
import json
import random
import time

from avocado.utils import process
from avocado.utils import astring

class HA:

	ZK_KAFKA = ["cluster-kafka-0", "cluster-zookeeper-0", "cluster-kafka-1", "cluster-zookeeper-1", "cluster-kafka-2", "cluster-zookeeper-2"]
	KAFKA = ["cluster-kafka-0", "cluster-kafka-1", "cluster-kafka-2"]
	ZOOKEEPER = ["cluster-zookeeper-0", "cluster-zookeeper-1", "cluster-zookeeper-2"]
	METRIC_DB = ["postgress-persister", "postgres"]
	SYSLOG = ["rsyslog-aggregator", "rsyslog-collector"]
	TELEMETRY = ["telemetry"]

	def __init__(self):
		self._deleted_pod = None

	def delete_pod(self, pods):
		if type(pods).__name__ == 'list':
			pod = random.choice(pods)
		else:
			# scalar 
			pod = pods
		uid = None
		if pod is not None:
			print "delete pod request %s" % (pod)
			cmd = 'kubectl -n sma get pods -o json'
			r = process.run(cmd)
			if r.exit_status == 0:
				data = json.loads(r.stdout_text)
				for item in data.get('items'):

					if item.get('metadata').get('name') == pod:
						uid = pod
						break

					if item.get('metadata').get('labels').get('app') == pod:
						uid = item.get('metadata').get('name')
						break

				if uid is not None:
# nodename describe pod spec.nodeName
					self._deleted_pod = pod
					print "deleting pod %s (%s)" % (pod, uid)
					cmd = 'kubectl -n sma delete pod {} --grace-period=0 --force'.format(uid)
					r = process.run(cmd)
					if r.exit_status != 0:
						uid = None

		return uid

	def wait_pod(self):

		ready = False
		pod = self._deleted_pod
		if pod is not None:
			print "wait for pod %s" % (pod)

			self._deleted_pod = None
			uid = None
# FIXME need a timer
			while True:
				cmd = 'kubectl -n sma get pods -o json'
				r = process.run(cmd)
				if r.exit_status == 0:
					data = json.loads(r.stdout_text)
					for item in data.get('items'):
						if item.get('metadata').get('name') == pod:
							uid = pod
							break

						if item.get('metadata').get('labels').get('app') == pod:
							uid = item.get('metadata').get('name')
							break

					if uid is not None:
						break

			if uid is not None:
				while True:
					print "checking if pod %s is ready" % (uid)
					cmd = 'kubectl -n sma get pod {} -o json'.format(uid)
					r = process.run(cmd)
					if r.exit_status == 0:
						data = json.loads(r.stdout_text)
						status = data.get('status')
						print "checking if pod %s is running %s" % (uid, status.get('phase'))
						if status.get('phase') == "Running":
							num_containers = 0
							num_ready = 0
							for status in status.get('containerStatuses'):
								num_containers += 1
								print "checking if container %s is ready %d" % (status.get('name'), status.get('ready'))
								if status.get('ready'):
									num_ready += 1
							if num_containers == num_ready:
								ready = True
								break
					time.sleep(5)

		return ready

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
