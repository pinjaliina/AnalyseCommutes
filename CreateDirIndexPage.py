#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon May 18 17:01:26 2020

@author: Pinja-Liina Jalkanen (pinjaliina@iki.fi)
"""

""" Build index from directory listing

make_index.py </path/to/directory> [--header <header text>] --imgpage

Credits: https://stackoverflow.com/questions/39048654/how-to-enable-directory-indexing-on-github-pages

Note: I improved this script so that it can be used to create image
      grids as well, but the pages created by the script are not complete and
      need manual post-processing. You've been warned!
"""

INDEX_TEMPLATE = r"""
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>${header}</title>
    <style type="text/css" charset="utf-8">
      body {
        font-family: sans-serif;
      }
    </style>
  </head>
<body>
<h2>${header}</h2>
<ul>
% for name in names:
    <li><a href="${name}">${name}</a></li>
% endfor
</ul>
</body>
</html>
"""

IMGPAGE_TEMPLATE = r"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>${header}</title>
    <style type="text/css" charset="utf-8">
      body {
        font-family: sans-serif;
      }
      div.row > div.element {
        float: left;
        min-width: 450px;
        padding: 10px;
      }
      div.element > p {
        padding: 100px 100px 100px 190px;
      }
      .row:after {
        content: "";
        display: table;
        clear: both;
      }
    </style>
  </head>
<body>
<h2>${header}</h2>
% for name in names:
    <div class = "row">
        <div class="element"><img src="${name}"></img></div>
    </div>
% endfor
</body>
</html>
"""

EXCLUDED = ['index.html', '.DS_Store', 'robots.txt']

import os
import argparse

# May need to do "pip install mako"
from mako.template import Template


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("--header")
    parser.add_argument("--imgpage", action="store_true")
    args = parser.parse_args()
    fnames = [fname for fname in sorted(os.listdir(args.directory))
              if fname not in EXCLUDED]
    header = (args.header if args.header else os.path.basename(args.directory))
    if not args.imgpage:
        print(Template(INDEX_TEMPLATE).render(names=fnames, header=header))
    else:
        print(Template(IMGPAGE_TEMPLATE).render(names=fnames, header=header))

if __name__ == '__main__':
    main()