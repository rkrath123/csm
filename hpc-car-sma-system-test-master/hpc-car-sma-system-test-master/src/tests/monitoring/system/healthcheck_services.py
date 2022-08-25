#!/usr/bin/env python

import os
import sys
import json
import time

import avocado
from avocado import Test
from avocado import main
from avocado.utils import process
from avocado.utils import astring

sys.path.append(os.path.join(os.path.dirname(__file__), '../lib'))
from system.whiteboard import Whiteboard

class Services(Test):

	"""
	:avocado: tags=funct,health
	SMA services health checks.
	"""

	EXPECTED_PV_CLAIMS = [
		'sma-mysql-pvc',
		'pgdata-craysma-postgres-cluster-0',
		'pgdata-craysma-postgres-cluster-1',
		'data-cluster-kafka-0',
		'data-cluster-kafka-1',
		'data-cluster-kafka-2',
		'data-cluster-zookeeper-0',
		'data-cluster-zookeeper-1',
		'data-cluster-zookeeper-2',
		'elasticsearch-persistent-storage-data-elasticsearch-data-0',
		'elasticsearch-persistent-storage-data-elasticsearch-0',
#		'elasticsearch-persistent-storage-master-elasticsearch-master-0'
	]

	EXPECTED_PV_CAPACITY = {
		'sma-mysql-pvc' : '5Gi',
		'pgdata-craysma-postgres-cluster-0' : '500Gi',
		'pgdata-craysma-postgres-cluster-1' : '500Gi',
		'elasticsearch-persistent-storage-data-elasticsearch-data-0' : '4Gi',
# FIXME - will not work on bigger systems
 		'elasticsearch-persistent-storage-data-elasticsearch-0' : '100Gi',
#		'elasticsearch-persistent-storage-master-elasticsearch-master-0' : '4Gi',
		'data-cluster-kafka-0' : '50Gi',
		'data-cluster-kafka-1' : '50Gi',
		'data-cluster-kafka-2' : '50Gi',
		'data-cluster-zookeeper-0' :    '10Gi',
		'data-cluster-zookeeper-1' :    '10Gi',
		'data-cluster-zookeeper-2' :    '10Gi',
	}

	EXPECTED_PV_KIND = 'PersistentVolume'
	EXPECTED_PV_NAMESPACE = 'sma'
	EXPECTED_PV_ACCESSMODE = 'ReadWriteOnce'
	EXPECTED_PV_PHASE = 'Bound'

	def setUp(self):
		self.log.debug(Services.__doc__)

		if "SMA_TEST_CONTAINER" in os.environ:
			self.sma_status = '/tools/monitoring/sma_status.sh'
		else:
			self.sma_status = '/root/sma-sos/sma_status.sh'

	def tearDown(self):
		self.log.debug("tearDown")

	def test_sma_services(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_sma_services", 108572).get()

		r = process.run(self.sma_status, ignore_status=True)
		self.assertEqual(r.exit_status, 0, "not all SMA services are healthy")

	def test_pvc_claims(self):
		# TestRail's test case ID
		self.whiteboard = Whiteboard("test_pvc_claims", 108666).get()

		cmd = 'kubectl -n sma get pv -o json'
		r = process.run(cmd)
		self.assertEqual(r.exit_status, 0)
		json_data = json.loads(r.stdout_text)
 		self.log.debug(json_data)

		for expected_name in self.EXPECTED_PV_CLAIMS:
			self.log.debug(expected_name)

			foundit = False

			for item in json_data.get('items'):

 				spec = item.get('spec')
				if spec.get('claimRef') is not None:
					name = spec.get('claimRef').get('name')
					if expected_name == name:
						self.log.debug('Found %s', name)
						foundit = True

						kind = item.get('kind')
						self.log.debug('kind %s', kind)
						phase = item.get('status').get('phase')
						self.log.debug('phase %s', phase)

						namespace = spec.get('claimRef').get('namespace')
						accessmode = spec.get('accessModes')[0]
						capacity = spec.get('capacity').get('storage')
						storageclassname = spec.get('storageClassName')

						self.assertEqual(kind, self.EXPECTED_PV_KIND, 'invalid pv kind: %s' % (kind))
						self.assertEqual(namespace, self.EXPECTED_PV_NAMESPACE, 'invalid pv namespace: %s' % (namespace))
						self.assertEqual(capacity, self.EXPECTED_PV_CAPACITY.get(name), 'invalid pv capacity: %s' % (capacity))
						self.assertEqual(phase, self.EXPECTED_PV_PHASE, 'invalid pv phase: %s' % (phase))
						self.assertEqual(accessmode, self.EXPECTED_PV_ACCESSMODE, 'invalid pv accessmode: %s' % (accessmode))
						break

			self.assertTrue(foundit, 'missing pv claim %s' % (expected_name))

if __name__ == "__main__":
	main()

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
