#!/usr/bin/env python3


class Config:
	ApiKey = "2C9BB45EFB08AD3B"
	ProductName = "SaneRenamix for OTR v1.0"
	DefaultLanguage = "de"

importErrors = []
import argparse
import logging
import re
import pickle
import os
import csv
import sys
import requests
from datetime import datetime
try:
	import urllib
except ModuleNotFoundError:
	importErrors.append("urllib")
try:
	import tvdbsimple as tvdb
	tvdb.keys.API_KEY = "a76ca23091901c5bf5c32de77c29a52a"
except ModuleNotFoundError:
	importErrors.append("tvdbsimple")
if importErrors:
	raise ModuleNotFoundError('please pip install these modules: ' + ', '.join(importErrors))


workingDir = os.path.dirname(os.path.realpath(__file__))


class ExitCode:
	GeneralError = 1		# invalid argument option, missing parameter
	WrongArguments = 2
	Aborted = 3				# Ctrl+C
	SeriesNotFoundInTvDB = 10
	SeriesNotFoundInEPG = 11
	SeveralPossibleSeriesFound = 12
	NoInfoForThisEpisode = 20
	NoEpisodeTitleFoundInEPG = 21
	DownloadingEPGFailed = 40
	DownloadingListFromTvDBFailed = 41

def parseArgs():
	parser = argparse.ArgumentParser(description = "Create a sane name for OTR media files\nby Leroy Foerster & Jonny007-MKD")
	parser.add_argument("--file",     "-f", type=str, required=True, help="Name of the file that shall be renamed")
	parser.add_argument("--nocache",  "-c", action="store_true", help="Disables the usage of the local cache")
	parser.add_argument("--silent",   "-s", action="store_true", help="Output only the new filename")
	parser.add_argument("--language", "-l", type=str, help="Language code for TvDB (de, en, fr, ...)", default=Config.DefaultLanguage)
	return parser.parse_args()

class EpisodeInfo:
	def __init__(self):
		self.season = None				# int
		self.episode = None				# int
		self.seriesName = None			# str
		self.episodeTitle = None		# str
		self.maybeEpisodeTitle = None	# str
		self.datetime = None			# datetime
		self.sender = None				# str
		self.description = None 		# str
		self.fileSuffix = None			# str

	def __str__(self):
		result = ""
		if self.seriesName: result += self.seriesName + " "
		if self.season:  result += f"S{self.season:02d}"
		if self.episode: result += f"E{self.episode:02d}"
		if result: result += " "
		if self.episodeTitle: result += self.episodeTitle
		if result: return result
		return f"{self.datetime} {self.sender} {self.description}"


def analyzeFilename(filename: str):
	logging.debug(f"analyzeFilename({filename})")

	result = EpisodeInfo()

	def makeDatetime(date: str, time: str):
		yy, mm, dd = date.split('.')
		HH, MM = time.split('-')
		return datetime(int(yy)+2000, int(mm), int(dd), int(HH), int(MM))

	# S00_E00_Series
	found = re.search(r"^S(\d\d)_E(\d\d)_", filename)
	if found:
		result.season = int(found.group(1))
		result.episode = int(found.group(2))
		filename = filename[len("S00_E00_"):]
		logging.debug(f"  found info at beginning: S{result.season:02d}E{result.episode:02d}. filename = {filename}")

	found = re.search(r"^(.*?)(_S(\d\d)E(\d\d))?_(\d\d.\d\d.\d\d)_(\d\d-\d\d)_([^_]+)_(\d+)_.+?\.(.+)", filename)
	if not found:
		raise Exception("Regex did not match filename")
	result.seriesName  = found.group(1).replace("_", " ")
	result.datetime = makeDatetime(found.group(5), found.group(6))
	result.sender = found.group(7)
	result.fileSuffix = found.group(9)
	if found.group(2):
		result.season  = int(found.group(3))
		result.episode = int(found.group(4))
	logging.info(f"  found info: {result.seriesName}, {result.datetime}, {result.sender}, S{result.season}E{result.episode}, {result.fileSuffix}")
	return result

def convertTitle(title: str, lang: str):
	title = title.replace(" s ", "'s ")
	if title.endswith(" s"): title = title[0:-2] + "'s"

	if lang == "de":
		title = title.replace("Ae", "Ä").replace("Oe", "Ö").replace("Ue", "Ü")
		title = title.replace("ae", "ä").replace("oe", "ö").replace("ue", "ü")
	return title

def getSeriesId(info: EpisodeInfo, args: dict):
	logging.debug(f"getSeriesId()")

	def loadCache():
		if args.nocache: return None
		logging.debug(f"  loadCache()")
		path = os.path.join(workingDir, "series.cache")
		if not os.path.isfile(path): return None
		try:
			with open(path, 'rb') as f:
				cache = pickle.load(f)
			logging.debug(f"    {len(cache)} entries loaded")
			return cache
		except Exception as e:
			logging.debug(f"    pickle load failed: {e}")
			return None

	def fromCache(cache):
		logging.debug(f"  fromCache()")
		if not cache: return (None, None)

		words = info.seriesName.split(' ')
		for i in range(len(words), 0, -1):
			title2 = " ".join(words[0:i])
			titles = set([title2, convertTitle(title2, args.language)])
			logging.debug("    trying '" + "' and '".join(titles) + "'")

			for title3 in titles:
				if title3 in cache:
					(id, niceName) = cache[title3]
					logging.debug(f"    found {id} as {niceName}")
					return (id, niceName)
		logging.debug(f"    found nothing")
		return (None, None)

	def fromTvdb():
		logging.debug(f"  fromTvdb()")

		words = info.seriesName.split(' ')
		regex = re.compile("[^a-zA-Z0-9 ]")
		allResults = []
		for i in range(len(words), 0, -1):
			title2 = " ".join(words[0:i])
			titles = set([title2, convertTitle(title2, args.language)])
			logging.debug("    trying '" + "' and '".join(titles) + "'")

			for title3 in titles:
				try:
					responses = None
					responses = tvdb.Search().series(title3, language=args.language)
				except requests.exceptions.HTTPError as e:
					logging.debug(f"    Exception {type(e)}: {e}")
				if not responses: continue
				allResults.extend(responses)
				for r in responses:
					if r["seriesName"].strip() == title3:
						logging.debug(f'    found {r["id"]} as {r["seriesName"]}')
						return r["id"], r["seriesName"]
				title3 = regex.sub("", title3).lower()
				for r in responses:
					if regex.sub("", r["seriesName"]).lower().strip() == title3:
						logging.debug(f'    found {r["id"]} as {r["seriesName"]}')
						return r["id"], r["seriesName"]

			allIds = set([ r["id"] for r in allResults ])
			if len(allIds)  > 1:
				uniqueResults = {}
				for r in allResults:
					if r["id"] in uniqueResults: continue
					uniqueResults[r["id"]] = r
				logging.debug(f'    found several series: {[ r["seriesName"]+" ("+str(r["id"])+")" for r in uniqueResults.values()]}')
				sys.exit(ExitCode.SeveralPossibleSeriesFound)
			if len(allIds) == 1:
				r = allResults[0]
				logging.debug(f'    found {r["id"]} as {r["seriesName"]}')
				return r["id"], r["seriesName"]

		logging.debug(f"    nothing found")
		sys.exit(ExitCode.SeriesNotFoundInTvDB)

	def writeCache(id: int, names: list, cache: dict):
		if args.nocache: return
		logging.debug(f"  writeCache({id}, {names})")
		if not cache:
			cache = {}
		for name in names:
			cache[name] = (id, niceName)

		path = os.path.join(workingDir, "series.cache")
		with open(path, 'wb') as f:
			pickle.dump(cache, f)

	def checkWhetherSeriesNameContainsEpisodeName(niceName: str):
		regex = re.compile("[^a-zA-Z0-9 ]")
		niceNames = set([niceName.lower(), regex.sub("", niceName.lower())])
		seriesNames = []
		for n in [info.seriesName, convertTitle(info.seriesName, args.language)]:
			seriesNames.append(n.lower())
			seriesNames.append(regex.sub("", n.lower()))
		seriesNames = set(seriesNames)

		for niceName2 in niceNames:
			for seriesName in seriesNames:
				if seriesName.startswith(niceName2):
					numWordsNiceName = len(niceName2.split(" "))
					seriesNameWords = info.seriesName.split(" ")
					info.maybeEpisodeTitle = " ".join(seriesNameWords[numWordsNiceName:])
					return " ".join(seriesNameWords[:numWordsNiceName])



	# Load good series name. First from cache, then from TvDB
	cache = loadCache()
	(id, niceName) = fromCache(cache)
	if id:
		checkWhetherSeriesNameContainsEpisodeName(niceName)
	else:
		(id, niceName) = fromTvdb()
		if id:
			names = [ niceName ]
			thirdName = checkWhetherSeriesNameContainsEpisodeName(niceName)
			if thirdName: names.append(thirdName)
			else: names.append(info.seriesName)
			writeCache(id, names, cache)

	if not id: return None

	if id:
		info.seriesName = niceName


	return id

def getEpgData(info: EpisodeInfo):
	logging.debug("getEpgData()")
	filename = f"epg-{info.datetime.strftime('%y.%m.%d')}.csv"
	filepath = os.path.join(workingDir, filename)

	def downloadEpg():
		url = f"https://www.onlinetvrecorder.com/epg/csv/epg_{info.datetime.strftime('%Y_%m_%d')}.csv"
		logging.debug(f"  downloadEpg(): {url}")
		try:
			request = urllib.request.urlopen(url)
		except requests.exceptions.HTTPError as e:
			logging.error(f"  failed: {e}")
			sys.exit(ExitCode.DownloadingEPGFailed)
		if request.getcode() == 200:
			data = request.read().decode('latin-1')
			with open(filepath, 'w') as f:
				f.write(data)
			return data.split('\n')
		else:
			raise Exception(f"Downloading EPG data failed: {request.getcode()}")

	def loadEpgFromFile():
		if os.path.isfile(filepath):
			logging.debug(f"  loadEpgFromFile()")
			with open(filepath) as f:
				return f.readlines()
		return None

	def findEpgEntry(data: list):
		logging.debug(f"  findEpgEntry()")
		regex = re.compile("[^a-zA-Z0-9]")
		beginn = info.datetime.strftime('%d.%m.%Y %H:%M:%S')
		sender = regex.sub("", info.sender).lower()

		reader = csv.DictReader(data, delimiter=';')
		for entry in reader:
			#logging.debug(f'    {entry["beginn"]} == {beginn} && {entry["sender"]} == {sender}?')
			if not entry["beginn"] == beginn: continue
			if not regex.sub("", entry["sender"]).lower() == sender: continue
			logging.debug(f'    found entry: {entry["text"]}')
			return entry
		return None

	data = loadEpgFromFile()
	if not data: data = downloadEpg()
	entry = findEpgEntry(data)
	if entry:
		def removePrefix(complete: str, prefix: str):
			return complete[len(prefix):].strip(" \t-_,.") if complete.startswith(prefix) else complete
		entry["text"] = entry["text"].strip(" \t-_,.")
		entry["text"] = removePrefix(entry["text"], entry["titel"])
		entry["text"] = removePrefix(entry["text"], info.seriesName)

		info.title = entry["titel"]
		info.description = entry["text"]
		logging.debug("  set: {info.description}")

class Episodes:
	def __init__(self, seriesID: int, args: dict):
		self.seriesID = seriesID
		self.args = args
		self.path = os.path.join(workingDir, f"episode-{seriesID}.cache")
		self.fromCache = None

	def _loadCache(self):
		if args.nocache: return None
		logging.debug(f"  loadCache()")
		if not os.path.isfile(self.path): return None
		try:
			with open(self.path, 'rb') as f:
				cache = pickle.load(f)
			return cache
		except Exception as e:
			logging.debug(f"    pickle load failed: {e}")
			return None

	def _fromTvdb(self):
		logging.debug(f"  fromTvdb()")

		try:
			episodes = tvdb.series.Series_Episodes(self.seriesID, language=self.args.language).all()
			return episodes
		except Exception as e:
			logging.error(f"    Exception: {e}")
			return None

	def _writeCache(self, episodes):
		if args.nocache: return
		with open(self.path, 'wb') as f:
			pickle.dump(episodes, f)

	def get(self):
		episodes = None
		# First call: try to load from cache
		if not self.fromCache:
			self.fromCache = True
			episodes = self._loadCache()
		if self.fromCache == True:
			# Second call or if cache does not exist: try to load from TvDB
			if not episodes:
				episodes = self._fromTvdb()
				if episodes:
					self.fromCache = False
					self._writeCache(episodes)
		return episodes


def getEpisodeTitleFromEpgData(info: EpisodeInfo, seriesID: int, args: dict):
	logging.debug(f"getEpisodeTitleFromEpgData()")
	if not info.description:
		logging.debug(f"  no description")
		return # Nothing we can do about it :(
	E = Episodes(seriesID, args)
	regex = re.compile("[^a-zA-Z0-9 ]")

	def get(dct: dict, keys: list):
		for k in keys:
			if k in dct: return dct[k]
		return None

	def saveInfo(foundEpisode: dict):
		info.season  = get(foundEpisode, ["airedSeason", "dvdSeason"])
		info.episode = get(foundEpisode, ["airedEpisodeNumber", "dvdEpisodeNumber"])
		info.episodeTitle = foundEpisode["episodeName"]
		logging.info(f'  found: S{info.season:02d}E{info.episode:02d}')

	d = info.description
	def doSearch(searchFunc):
		for delims in [ (".",""), (".",","), (",", ""), (",",".") ]:
			if not delims[0] in d or not delims[1] in d: continue
			split = d.split(delims[0])
			if delims[1]: split = split[1].split(delims[1])
			split = split[0].strip()

			words = split.split(" ")
			for i in range(len(words)):                # cut off one word at a time from the end
				for j in range(len(words), i, -1):   # cut off one word at a time from the beginning
					title = " ".join(words[i:j])
					found = searchFunc(title)
					if found:
						saveInfo(found)
						return True
		return False


	for i in range(2): # Try once from cache and once from TvDB
		episodes = E.get()
		if not episodes: continue# Nothing we can do about it :(
		episodesByName = { e["episodeName"].strip(): e for e in episodes }

		if info.maybeEpisodeTitle and info.maybeEpisodeTitle in episodesByName:
			saveInfo(episodesByName[info.maybeEpisodeTitle])
			return


		logging.debug("  searching for a matching episode name (exactly)")
		def searchByName(title: str):
			logging.debug(f'    trying "{title}"')
			return episodesByName.get(title, None)
		found = doSearch(searchByName)
		if found: return

		logging.debug("  searching for a matching episode name more liberally")
		episodesByName2 = { regex.sub("", e["episodeName"]).lower().strip(): e for e in episodes }
		def searchByName2(title: str):
			title = regex.sub("", title).lower().strip()
			logging.debug(f'    trying "{title}"')
			return episodesByName2.get(title, None)
		found = doSearch(searchByName2)
		if found: return

		logging.debug("  searching for a matching description (startswith)")
		def searchByOverview(overview: str):
			logging.debug(f'    trying "{overview}"')
			results = [ e for e in episodes if e["overview"] and e["overview"].strip().startswith(overview) ]
			if len(results) == 1: return results[0]
			return None
		found = doSearch(searchByOverview)
		if found: return

		logging.debug("  searching for a matching description more liberally (startswith)")
		def searchByOverview2(overview: str):
			overview = regex.sub("", overview).lower().strip()
			logging.debug(f'    trying "{overview}"')
			results = [ e for e in episodes if e["overview"] and regex.sub("", e["overview"]).lower().strip().startswith(overview) ]
			if len(results) == 1: return results[0]
			return None
		found = doSearch(searchByOverview2)
		if found: return



def getEpisodeTitleFromTvdb(info: EpisodeInfo, seriesID: int, args: dict):
	logging.debug("getEpisodeTitleFromTvdb()")
	episodes = Episodes(seriesID, args).get()
	if not episodes: return # Nothing we can do :(

	def get(dct: dict, keys: list):
		for k in keys:
			if k in dct: return dct[k]
		return None

	for e in episodes:
		season  = get(e, ["airedSeason", "dvdSeason"])
		episode = get(e, ["airedEpisodeNumber", "dvdEpisodeNumber"])
		if season == info.season and episode == info.episode:
			info.episodeTitle = e["episodeName"]
			return


def printResult(info: EpisodeInfo):
	if info.seriesName and info.season and info.episode:
		episodeTitle = info.episodeTitle.replace(' ', '.') if info.episodeTitle else ""
		print(f"{info.seriesName.replace(' ', '.')}..S{info.season:02d}E{info.episode:02d}..{episodeTitle}.{info.fileSuffix}")
		sys.exit(0)
	else:
		sys.exit(ExitCode.NoEpisodeTitleFoundInEPG)


if __name__ == '__main__':
	logging.basicConfig(level=logging.DEBUG, format="%(asctime)s %(message)s")
	args = parseArgs()
	info = analyzeFilename(args.file)
	id = getSeriesId(info, args)
	if not id: sys.exit(ExitCode.SeriesNotFoundInTvDB)
	if not info.season or not info.episode:
		getEpgData(info)
		getEpisodeTitleFromEpgData(info, id, args)
	if not info.episodeTitle:
		getEpisodeTitleFromTvdb(info, id, args)
	printResult(info)

