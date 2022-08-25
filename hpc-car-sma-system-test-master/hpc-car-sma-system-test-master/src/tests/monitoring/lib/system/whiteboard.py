#!/usr/bin/env python

import json

class Whiteboard:

	def __init__(self, id, case_id):
		self.whiteboard = {}
		self.tests = []

		test = { "id": id, "case_id": case_id }
		self.tests.append(test)

		self.whiteboard['tests'] = self.tests

	# add another testrail case id
	def add_test(self, id, case_id):
		test = { "id": id, "case_id": case_id }
		self.tests.append(test)

	# add a key:value pair to whiteboard
	def add_value(self, key, value):
		self.whiteboard[key] = value

	# get values
	def get(self):
 		serialized = json.dumps(self.whiteboard)
		return serialized

	# pretty values for logging
	def log(self):
		serialized = json.dumps(self.whiteboard, sort_keys=True, indent=3)
		return serialized

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
