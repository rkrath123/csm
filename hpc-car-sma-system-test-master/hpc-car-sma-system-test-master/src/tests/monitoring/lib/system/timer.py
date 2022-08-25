#!/usr/bin/env python

import time

class Timer:
	def __init__(self):
		self.start = time.time()

	def restart(self):
		self.start = time.time()

	def get_time_hhmmss(self):
		end = time.time()
		m, s = divmod(end - self.start, 60)
		h, m = divmod(m, 60)
		time_str = "%02dm%02ds" % (m, s)
		return time_str

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
