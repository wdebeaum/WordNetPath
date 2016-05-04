# WordNetPath #

WordNetPath is a Ruby library for selecting subsets of [WordNet](http://wordnet.princeton.edu/) based on pointer and gloss tag path traversal. It requires the `wn.db` SQLite3 database file made by [WordNetSQL](http://github/wdebeaum/WordNetSQL). It does not require the library code from WordNetSQL.

The main documentation is in [README.html](README.html), and is written in the context of TRIPS. For reference, `$TRIPS_BASE` is `trips/`, and in TRIPS the rest of this repository would live in `$TRIPS_BASE/src/WordNetPath/`.

WordNet is © Princeton University

WordNet ™® is a registered tradename.
Princeton University makes WordNet available to research and commercial users free of charge provided the terms of the [license](http://wordnet.princeton.edu/wordnet/license/) are followed, and proper reference is made to the project using an appropriate citation. WordNetPath does not include WordNet itself, so that license does not apply to this code; see the licensing section below.

## Build instructions ##

    ./configure
    make install-needed-gems # downloads and installs Ruby gems
    make install # installs to trips/etc/WordNetPath/

## Licensing ##

WordNetPath is licensed using the [GPL 2+](http://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html) (see `LICENSE.txt`):

WordNetPath - Ruby library for selecting subsets of WN based on path traversal  
Copyright (C) 2016  Institute for Human & Machine Cognition

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
