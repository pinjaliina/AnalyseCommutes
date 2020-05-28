#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Loop through selected (hardcoded!) RunAnalysis.R output tables and plot
chosen parts of the data on Bokeh maps.

Created on Wed Apr 15 15:26:30 2020

@author: Pinja-Liina Jalkanen (pinjaliina@iki.fi)
"""

# Silence FutureWarnings of Pandas
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)
# Import necessary modules
import pandas
import geopandas as gpd   # geopandas is usually shortened as gpd
import mapclassify as mc
from fiona.crs import from_epsg
from bokeh.plotting import figure
from bokeh.layouts import gridplot
from bokeh.io import save
from bokeh.tile_providers import get_provider, Vendors
from bokeh.models import \
    GeoJSONDataSource, \
    LinearColorMapper, \
    HoverTool, \
    Legend, \
    LegendItem, \
    LabelSet, \
    Label
import bokeh.palettes as palettes
import psycopg2
from os import path, mkdir
from scipy import stats
import matplotlib.pyplot as plt
# Silence max_open_warnings of matplotlib
plt.rcParams.update({'figure.max_open_warning': 0})
from textwrap import wrap

def get_db_conn():
    """Define DB connection params.
    
    If successful, return a psycopg2 DB cursor.
    
    On localhost just dbname will usually suffice, but over remote
    connections e.g. the following can be defined as well:
        * host
        * user
        * sslmode (please use "verify-full"!)
        * password (if using password authentication instead of a client cert).
    """
    
    conn_params = {
         'dbname': 'tt'
        }
    
    try:
        dbconn = psycopg2.connect(**conn_params)
        dbconn.autocommit = True
        return dbconn
    except psycopg2.OperationalError:
        print('Failed to establish a DB connection!\n')
        raise

def get_plot(query, conn, desc, first, last):
    # Get one of the results tables
    df = gpd.GeoDataFrame.from_postgis(
        query, conn, geom_col='geom',
        crs=from_epsg(3067)).to_crs("EPSG:3857")
    # A point source for labels. df.set_geometry() fails, but this works!
    df_centroids = gpd.GeoDataFrame.from_postgis(
        query, conn, geom_col='geom_centroid',
        crs=from_epsg(3067)).to_crs("EPSG:3857")
    
    # Classify data (manual classes based on outputs of previous runs!)
    breaks = [-10.1, 10, 101]
    classifier = mc.UserDefined.make(bins=breaks)
    classes = df[['RFChange']].apply(classifier)
    classes.columns = ['Class']
    df = df.join(classes)
 
    # Collect some statistics:
    # For practical help how to do this in Python:
    # https://pythonfordatascience.org/independent-t-test-python/
    statistics = {
        'min_rfchg': df['RFChange'].min(),
        'max_rfchg': df['RFChange'].max(),
        'min_abschg': df['AbsChange'].min(),
        'max_abschg': df['AbsChange'].max(),
        'mean_rfchg': df['RFChange'].mean(),
        'mean_abschg': df['AbsChange'].mean(),
        'median_abschg': df['AbsChange'].median(),
        'stdev_abschg': df['AbsChange'].std(),
        'mean_T1': df['T1'].mean(),
        'mean_T2': df['T2'].mean(),
        'stdev_T1': df['T1'].std(),
        'stdev_T2': df['T2'].std(),
        'levenestat_abschg': None,
        'levenepval_abschg': None,
        'shapirostat_abschg': None,
        'shapiropval_abschg': None,
        't-stat_abschg': None,
        't-pval_abschg': None,
        't-df_abschg': None}
    # None of this makes sense unless both variables have data:
    reshist = None
    resqq = None
    if not ((df['T1'] == 0).all() or (df['T2'] == 0).all()):
        # Null hypothesis for Levene test: both inputs have equal variances.
        statistics['levenestat_abschg'], \
            statistics['levenepval_abschg'] = stats.levene(df['T1'], df['T2'])
        # Null hypothesis for Shapiro-Wilk: normal distribution of residuals.
        diff = df['T2']-df['T1']
        statistics['shapirostat_abschg'], \
            statistics['shapiropval_abschg'] = stats.shapiro(diff)
        plot_title = 'Residuals for ' + desc + ', ' + first + '–' + last
        reshist = diff.plot(kind = 'hist',
                            title = "\n".join(wrap(plot_title, 60)),
                            figure=plt.figure())
        plt.figure()
        stats.probplot(diff, plot=plt)
        plt.title("\n".join(wrap(plot_title, 60)))
        resqq = plt.gca()
        statistics['t-stat_abschg'], \
            statistics['t-pval_abschg'] = stats.ttest_ind(df['T1'], df['T2'])
        statistics['t-df_abschg'] = df['T1'].count() + df['T2'].count() - 2
        # Do not use researchpy; it outputs a dataframe, and digging results
        # out of that just adds complexity.
        # statistics['descriptives_abs'], statistics['ttest_abs'] = rp.ttest(
        #     df['T1'], df['T2'])

    # Define class names
    cnames = [
        '[-100…-10[',
        '[-10…10]',
        ']10…100]']
    
    # Adding labels doesn't make sense as legend plotting does not work
    # (see below).
    # for i in range(len(cnames)):
    # df['Label'] = None
    #     df.loc[df['Class'] == i, 'Label'] = cnames[i]
    
    # Get the tile provider. Ideally I should define my own and use
    # an NLS bkg map, but defining an own WTMS source is painstaking!
    tiles = get_provider(Vendors.CARTODBPOSITRON_RETINA)
    # tiles = get_provider(Vendors.STAMEN_TERRAIN_RETINA)
    
    # Try to plot a map
    plot = figure(
        x_range=(2725000,2815000),
        y_range=(8455000,8457000),
        # x_range=(2725000,2815000),
        # y_range=(8355000,8457000),
        x_axis_type="mercator",
        y_axis_type="mercator",
        height=450,
        width=600,
        title = desc + ', ' + first + '–' + last)
    plot.add_tile(tiles, level='underlay')
    
    # Create the colour mapper
    colourmapper = LinearColorMapper(
        low = 1,
        high = 1,
        palette=[palettes.RdYlBu[9][4]],
        low_color=palettes.RdYlBu[9][0],
        high_color=palettes.RdYlBu[9][8])
    
    # Create a map source from the DB results table and plot it
    mapsource = GeoJSONDataSource(geojson=df.to_json())
    plot.patches('xs',
                 'ys',
                  fill_color={'field': 'Class', 'transform': colourmapper},
                  line_color='gray',
                  source=mapsource,
                  line_width=1,
                  level='underlay')
    
    # Plot labels from centroids
    labsource = GeoJSONDataSource(geojson=df_centroids.to_json())
    # DEBUG: mark centroids on maps
    # plot.circle('x', 'y', source=labsource, color='red', size=10, level='underlay')
    labels = LabelSet(x='x',
                      y='y',
                      text='RFChange',
                      text_font_size='8pt',
                      x_offset=-4,
                      y_offset=-7,
                      source=labsource,
                      level='glyph')
    plot.add_layout(labels)

    # Cite map sources
    citation = Label(
        x=3,
        y=0,
        x_units='screen',
        y_units='screen',
        text='Map data: Statistics Finland, UH / Accessibility Research Group',
        render_mode='css',
        text_font_size='7.25pt',
        text_color='black',
        border_line_color='white',
        border_line_alpha=0.1,
        border_line_width=1.0,
        background_fill_color='white',
        background_fill_alpha=0.4)
    plot.add_layout(citation)
    bkg_map_head = Label(
        x=298,
        y=0,
        x_units='screen',
        y_units='screen',
        text='Background map: ',
        render_mode='css',
        text_font_size='7.25pt',
        text_color='black',
        border_line_color='white',
        border_line_alpha=0.1,
        border_line_width=1.0,
        background_fill_color='white',
        background_fill_alpha=0.4)
    plot.add_layout(bkg_map_head)

    # Create a legend. Of course it does NOT work automatically, see
    # https://github.com/bokeh/bokeh/issues/9398, but MUST still be defined
    # by data. :(
    # The easiest way is to create fake elements and position them so that
    # they're invisible, but draw a legend for them anyway.
    xq = list()
    yq = list()
    for i in range(3):
        xq.append(2800000+1000*i)
    for i in range(3):
        xq.append(8500000+1000*i)
    colours = [palettes.RdYlBu[9][0],
               palettes.RdYlBu[9][4],
               palettes.RdYlBu[9][8]]
    legend_renderer = plot.multi_line(
        [xq, xq, xq], [yq, yq, yq], color=colours, line_width=20)
    legend = [
        LegendItem(label=cnames[0], renderers=[legend_renderer], index=0),
        LegendItem(label=cnames[1], renderers=[legend_renderer], index=1),
        LegendItem(label=cnames[2], renderers=[legend_renderer], index=2)]    
    plot.add_layout(Legend(items=legend, location='top_right',
                           title='Change, %-p.'))
    
    hoverinfo = HoverTool()
    hoverinfo.tooltips = [('Region', '@nimi'),
                          ('Mean time ' + first,'@T1'),
                          ('Mean time ' + last,'@T2'),
                          ('Mean time change', '@AbsChange'),
                          ('Change, %-point of the industry total',
                           '@RFChange')]

    plot.add_tools(hoverinfo)
    
    return plot, statistics, reshist, resqq

def industry_list():
    return {
        'PriProd': 'Agriculture, forestry and fishing',
        'Mining': 'Mining and quarrying',
        'Manuf': 'Manufacturing',
        'ElAC': 'Electricity, gas, steam and A/C',
        'WaterEnv': 'Water supply, sewage and environment',
        'Construct': 'Construction',
        'Trade': 'Wholesale and retail trade',
        'Logistics': 'Transportation and storage',
        'HoReCa': 'Hotels, restaurants and catering',
        'InfoComm': 'Information and communication',
        'FinIns': 'Financial and insurance activities',
        'RealEst': 'Real estate activities',
        'SpecProf': 'Speciality professions',
        'AdminSupp': 'Administrative and support services',
        'PubAdmDef': 'Public administration and defence',
        'Education': 'Education',
        'HealthSoc': 'Human health and social work',
        'ArtsEnt': 'Arts, entertainment and recreation',
        'OtherServ': 'Other service activities and NGOs',
        'HomeEmp': 'Households as employers',
        'IntOrgs': 'International organisations',
        'UnknownInd': 'Unknown industry'}

# Get a DB connection object.
pg = get_db_conn()

modes = {'car': 'Car', 'pt': 'PT'}

series = ('2013', '2015', '2018')

plot_stats_ind = list()

reshists = dict()
resqqs = dict()
docs_path = path.join(path.dirname(path.realpath(__file__)), 'docs')

for modeid, mode in modes.items():
    plots = list()
    
    for field, desc in industry_list().items():
        query=(
            'SELECT * FROM (SELECT '
                'CASE WHEN '
                'r.nimi<>\'\' THEN r.nimi ELSE \'Kauniainen\' END AS nimi, '
                'r.geom, '
                'rf1."RegID", '
                'CASE WHEN rf1."RegID" '
                'NOT IN (\'0911102000\', \'0916603000\') THEN '
                    'ST_PointOnSurface(r.geom) '
                'ELSE '
                    'CASE WHEN rf1."RegID" = \'0911102000\' THEN '
                        'ST_Translate(ST_PointOnSurface(r.geom), 0, 4000) '
                    'ELSE '
                        'ST_Translate(ST_PointOnSurface(r.geom), 0, 8000) '
                    'END '
                'END  AS geom_centroid, '
                'rf1."MunID", '
                'rf1."AreaID", '
                'rf1."DistID", '
                'rf1."Count" AS "C1", '
                'rf1."' + field +'" AS "RF_T1", '
                'abs1."' + field +'" AS "T1", '
                'CASE WHEN abs1."' + field +'" <> 0 THEN '
                'ROUND(CAST('
                    'abs1."' + field +'"/(abs1."' + field +\
                    '"/abs1."Total")/abs1."Count" AS NUMERIC), 2) '
                'ELSE 0 END AS "M1", '
                'rf2."Count" AS "C2",rf2."' + field + '" AS "RF_T2", '
                'abs2."' + field +'" AS "T2", '
                'CASE WHEN abs2."' + field +'" <> 0 THEN '
                'ROUND(CAST('
                    'abs2."' + field +'"/(abs2."' + field + \
                    '"/abs2."Total")/abs2."Count" AS NUMERIC), 2) '
                'ELSE 0 END AS "M2", '
                'ROUND(CAST(rf2."' + field + '"-rf1."' + field + \
                    '" AS NUMERIC), 2) AS "RFChange", '
                'ROUND(CAST(abs2."' + field + '"-abs1."' + field + \
                    '" AS NUMERIC), 2) AS "AbsChange" '
                'FROM hcr_subregions r '
                'LEFT JOIN res_agg_j_ic_reg_' + modeid + '_icfreq_mun rf1 ON '
                    'r.kokotun=rf1."RegID" AND rf1."TTM" = {} '
                'LEFT JOIN res_agg_j_ic_reg_' + modeid + '_icfreq_mun rf2 ON '
                    'r.kokotun=rf2."RegID" AND rf2."TTM" = {} '
                'LEFT JOIN res_agg_j_ic_reg_' + modeid + '_mun abs1 ON '
                    'r.kokotun=abs1."RegID" AND abs1."TTM" = {} '
                'LEFT JOIN res_agg_j_ic_reg_' + modeid + '_mun abs2 ON '
                    'r.kokotun=abs2."RegID" AND abs2."TTM" = {} '
            ') AS Q WHERE "AbsChange" IS NOT NULL')
    
        for i, item in enumerate(series):
            if(i<=len(series)-2):
                q = query.format(item, series[i+1], item, series[i+1])
                plot = get_plot(
                    q, pg,
                    mode + ': Change of the share of the total time: ' + desc,
                    item, series[i+1])
                plots.append(plot[0])
                period = str(item) + '–' + str(series[i+1])
                reshists[mode + '_' + field + '_' + period] = plot[2]
                resqqs[mode + '_' + field + '_' + period] = plot[3]
                statsdic = {'mode': mode,
                            'indcode': field,
                            'ind_desc': desc,
                            'period': str(item) + '–' + str(series[i+1])}
                statsdic.update(plot[1])
                plot_stats_ind.append(statsdic)

    # Save the map.
    outfp = path.join(docs_path, 'icfreq_reg_maps_' + modeid + '.html')
    save(gridplot(plots, ncols=2), outfp, title='IC frequency plots, ' + mode)
    #         break #DEBUG: to save but one map, intend the above two lines
    #     break     #       to the level of the innermost of these three and
    # break         #       uncomment these three.

# Save residual plots
dirpath = path.join(docs_path, 'plots_hist')
if not path.exists(dirpath):
    mkdir(dirpath)
for key, plot in reshists.items():
    outfp = path.join(dirpath, key.replace('–','-') + '_residuals.png')
    if(plot):
        plot.get_figure().savefig(outfp)
dirpath = path.join(docs_path, 'plots_qq')
if not path.exists(dirpath):
    mkdir(dirpath)
for key, plot in resqqs.items():
    outfp = path.join(dirpath, key.replace('–','-') + '_residuals.png')
    if(plot):
        plot.get_figure().savefig(outfp)

# Write all statistics to an xlsx file.
# The file will be located in a temporary directory, which on some platforms
# is under a funny path. But the script will print the full path to the file.
plot_stats_dict = dict()
for k in plot_stats_ind[0].keys():
    plot_stats_dict[k] = tuple(
        plot_stats_dict[k] for plot_stats_dict in plot_stats_ind)
plot_stats = pandas.DataFrame(plot_stats_dict)
statsfp = path.join(docs_path, 'ic_maps_stats.xlsx')
plot_stats.to_excel(statsfp)
print('Output files written under "' + docs_path + '".')