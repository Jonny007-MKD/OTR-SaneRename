import os
import pickle
import sys

workingDir = os.path.dirname(os.path.realpath(__file__))
path = os.path.join(workingDir, "series.cache")

def loadCache():
	if not os.path.isfile(path): return None
	try:
		with open(path, 'rb') as f:
			cache = pickle.load(f)
		return cache
	except Exception as e:
		return None

def writeCache(cache):
	with open(path, 'wb') as f:
		pickle.dump(cache, f)

cache = loadCache()
print(cache)
sys.exit()
if cache:
	cache.pop("Ein Fall für TKKG (2014)", None)
	cache.pop("Ein Fall für TKKG", None)
	cache.pop("Ein Fall fuer TKKG", None)
	writeCache(cache)
