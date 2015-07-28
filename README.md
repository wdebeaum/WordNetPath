# WordNetPath #

WordNetPath is a Ruby library for selecting subsets of [WordNet](http://wordnet.princeton.edu/) based on pointer and gloss tag path traversal. It requires the `wn.db` SQLite3 database file made by [WordNetSQL](http://github/wdebeaum/WordNetSQL).

The main documentation is in [README.html](README.html), and is written in the context of TRIPS. For reference, `$TRIPS_BASE` is `trips/`, and in TRIPS the rest of this repository would live in `$TRIPS_BASE/src/WordNetPath/`.

WordNet is © Princeton University

WordNet ™® is a registered tradename.
Princeton University makes WordNet available to research and commercial users free of charge provided the terms of the [license](http://wordnet.princeton.edu/wordnet/license/) are followed, and proper reference is made to the project using an appropriate citation.

## Build instructions ##

    ./configure
    make install-needed-gems # downloads and installs Ruby gems
    make install # installs to trips/etc/WordNetPath/

