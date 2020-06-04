# AnalyseCommutes
Analyse CommuteAggregator data.

Please note that these scripts are mere helper tools that
do not make much sense independently:
* PrepAnalysis.R needs a DB with [CommuteAggregator](https://github.com/pinjaliina/CommuteAggregator) output tables.
* PlotMaps.py needs output tables of PrepAnalysis.R.
* TTests.R for running some statistical tests.

For some output files of previous runs, see https://pinjaliina.github.io/AnalyseCommutes.

Please also note that all the scripts are meant to run from within an IDE; in particular, RStudio for the R scripts. PrepAnalysis.R currently includes plotting code that is non-functional.
