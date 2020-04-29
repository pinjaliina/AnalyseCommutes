#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Loop through selected (hardcoded!) RunAnalysis.R output tables and plot
chosen parts of the data on Bokeh maps.

Created on Wed Apr 15 15:26:30 2020

@author: Pinja-Liina Jalkanen (pinjaliina@iki.fi)
"""

# Import necessary modules
import pandas
import geopandas as gpd   # geopandas is usually shortened as gpd
# from shapely.geometry import Point
import mapclassify as mc
from fiona.crs import from_epsg
# from bokeh.models.glyphs import Circle
from bokeh.plotting import figure
from bokeh.layouts import gridplot
from bokeh.io import save
from bokeh.tile_providers import get_provider, Vendors
from bokeh.models import \
    GeoJSONDataSource, LinearColorMapper, HoverTool, Legend, LegendItem
import bokeh.palettes as palettes
import psycopg2
from os import path
#import pandas.io.sql as psql

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
         'host': 'vm0448.kaj.pouta.csc.fi', # Cut off
         'user': 'pinjaliina',              # these three rows
         'sslmode': 'verify-full',          # before commit!
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
    
    # Classify data (manual classes based on outputs of previous runs!)
    breaks = [-10.1, 10, 101]
    classifier = mc.UserDefined.make(bins=breaks)
    classes = df[['Change']].apply(classifier)
    classes.columns = ['Class']
    df = df.join(classes)
 
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
        x_axis_type="mercator",
        y_axis_type="mercator",
        height=450,
        width=600,
        title = desc + ', ' + first + '–' + last)
    plot.add_tile(tiles)
    
    # Create the colour mapper
    colourmapper = LinearColorMapper(
        low = 1,
        high = 1,
        palette=[palettes.RdYlBu[9][4]],
        low_color=palettes.RdYlBu[9][0],
        high_color=palettes.RdYlBu[9][8])
    
    # Create a map source from the DB results table and plot it
    mapsource = GeoJSONDataSource(geojson=df.to_json())
    # print(mapsource.geojson)
    # sys.exit()
    plot.patches('xs', 'ys',
                 fill_color={'field': 'Class', 'transform': colourmapper},
                 line_color='gray', source=mapsource, line_width=1)
    
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
    hoverinfo.tooltips = [('Region', '@nimi'), ('Change, %-point', '@Change')]
    plot.add_tools(hoverinfo)
    
    return plot, df['Change'].min(), df['Change'].max()


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

# Get a DB connection object
pg = get_db_conn()

modes = {'car': 'Car', 'pt': 'PT'}

series = ('2013', '2015', '2018')

for modeid, mode in modes.items():
    plots = list()
    plot_stats = list()
    
    for field, desc in industry_list().items():
        query = 'SELECT * FROM (SELECT CASE WHEN r.nimi<>\'\' THEN r.nimi \
    ELSE \'Kauniainen\' END AS nimi,r.geom,j1."MunID",j1."AreaID",j1."DistID",\
    j1."Count" AS "C1",j1."' + field +'" AS "T1",\
    j2."Count" AS "C2",j2."' + field + '" AS "T2",\
    ROUND(CAST(j2."' + field + '"-j1."' + field + '" AS NUMERIC), 2\
        ) AS "Change" \
    FROM hcr_subregions r \
    LEFT JOIN res_agg_j_ic_reg_' + modeid + '_icfreq_mun j1 ON \
    r.kokotun=j1."RegID" AND j1."TTM" = {} \
    LEFT JOIN res_agg_j_ic_reg_' + modeid + '_icfreq_mun j2 ON \
    r.kokotun=j2."RegID" AND j2."TTM" = {}) AS Q WHERE "Change" IS NOT NULL'
    
        for i, item in enumerate(series):
            if(i<=len(series)-2):
                q = query.format(item, series[i+1])
                plot = get_plot(
                    q, pg, mode + ': Change of the share of the total \
                        time: ' + desc, item, series[i+1])
                plots.append(plot[0])
                plot_stats.append([field, str(item) + '–' + str(series[i+1]),
                                   plot[1], plot[2]])
        
    # Print stats
    print('Descriptives for Mode: ' + mode)
    psdf = pandas.DataFrame(plot_stats, columns=['Ind','Period','Min','Max'])
    print(psdf.describe())
    print(psdf[psdf['Period']=='2013–2015'].describe())
    print(psdf[psdf['Period']=='2015–2018'].describe())
                
    # Save the map
    outfp = path.join(path.dirname(path.realpath(__file__)),
                      'docs/icfreq_reg_maps_' + modeid + '.html')
    save(gridplot(plots, ncols=2), outfp, title='IC frequency plots, ' + mode)