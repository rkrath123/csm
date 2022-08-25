#!/usr/bin/python

# curl -s -XGET 'http://venom-sms.us.cray.com:30200/_cluster/stats?human&pretty&pretty'
# curl -s -XGET 'http://venom-sms.us.cray.com:30200/_cluster/stats' | json_pp

import argparse
import sys
import json
from elasticsearch import Elasticsearch

try:
	es = Elasticsearch(['venom-sms.us.cray.com'], port=30200) 
	print ("Connected: ", es.info())
	print ("Health: ", es.cluster.health()) 
	print ("Stats: ", es.cluster.stats()) 
	stats = es.cluster.stats()
	print stat['os']
	print stat['fs']
except Exception as e:
	print "Error:", e

# json_data = sys.stdin.read()
# data = json.loads(json_data)

# print "Total log messages:", data['hits']['total']

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
