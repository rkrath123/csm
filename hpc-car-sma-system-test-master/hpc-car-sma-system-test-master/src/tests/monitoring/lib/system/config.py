#!/usr/bin/env python

import os
import sys
import random
import json

from avocado.utils import process
from avocado.utils import astring

def get_api_gateway():
	return "api-gw-service-nmn.local"

def get_kafka_pod():
	num=random.choice([0,2])
	return "cluster-kafka-" + str(num)

def get_postgres_pod():
	num=random.choice([0,1])
	return "craysma-postgres-cluster-" + str(num)

def get_keycloak_token_url():
	return get_api_gateway() + "/keycloak/realms/shasta/protocol/openid-connect/token"

def get_grafana_url():
	return get_api_gateway() + "/sma-grafana"

def get_kibana_url():
	return get_api_gateway() + "/sma-kibana"

def get_elasticsearch_url():
	url = None
	cmd = 'kubectl -n sma get services -o json'
	r = process.run(cmd)
	if r.exit_status == 0:
		cluster_ip = 0
		json_data = json.loads(r.stdout_text)
		for item in json_data.get('items'):
			meta = item.get('metadata')
			if meta.get('name') == 'elasticsearch':
				cluster_ip = meta.get('spec').get('clusterIP')
				break
		url = cluster_ip + ":9200"
	return url

def get_non_compute_node():
	ncn_node = None
	cmd = 'kubectl -n sma get nodes -o json'
	r = process.run(cmd)
	if r.exit_status == 0:
		data = json.loads(r.stdout_text)
		ncn_node = data.get('items')[0].get('metadata').get('name')
	return ncn_node

def get_kafka_topics(filter=None):
	expected_topics = [
		"cray-node",
		"cray-job",
		"cray-lustre",
		"cray-logs-containers",
		"cray-logs-syslog",
		"cray-logs-clusterstor",
	]
	return expected_topics

def get_kafka_topic_partitions():
	expected_partitions = {
		"cray-node" : "4",
		"cray-job" : "4",
		"cray-lustre" : "4",
		"cray-logs-containers" : "4",
		"cray-logs-syslog" : "4",
		"cray-logs-clusterstor" : "4",
	}
	return expected_partitions

def get_kafka_topic_replicas():
	expected_replicas = {
		"cray-node" : "2",
		"cray-job" : "2",
		"cray-lustre" : "2",
		"cray-logs-containers" : "2",
		"cray-logs-syslog" : "2",
		"cray-logs-clusterstor" : "2",
	}
	return expected_replicas

def get_telemetry_request_url():
	cluster_ip = None
	cmd = 'kubectl -n sma get services -o json'
	r = process.run(cmd)
	if r.exit_status == 0:
		data = json.loads(r.stdout_text)
		for item in data.get('items'):
			if item.get('metadata').get('name') == 'telemetry':
				cluster_ip = "https://" + item.get('spec').get('clusterIP') + ":8080"
	return cluster_ip

def get_telemetry_version():
	return "v1"

def get_telemetry_endpoints():
	version = get_telemetry_version()
	expected_endpoints = [
		'{}/'.format(version),
		'{}/stream'.format(version),
		'{}/stream/<name>'.format(version),
		'{}/ping'.format(version),
		'{}/unit_test'.format(version)
	]
	return expected_endpoints

def get_telemetry_streams():
	expected_streams = [
		{ 'name' : 'cray-node',             'scale_factor' : 4 },
		{ 'name' : 'cray-job',              'scale_factor' : 4 },
		{ 'name' : 'cray-lustre',           'scale_factor' : 4 },
		{ 'name' : 'cray-logs-clusterstor', 'scale_factor' : 4 },
		{ 'name' : 'cray-logs-containers',  'scale_factor' : 4 },
		{ 'name' : 'cray-logs-syslog',      'scale_factor' : 4 },
	]
	return expected_streams

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
