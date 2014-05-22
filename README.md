# Problem Summary

Find the 10 most popular wikipedia pages, by language, during the first hour of 2012.

## Data

The wikipedia pageviews data is [here](http://dumps.wikimedia.org/other/pagecounts-raw/2012/2012-01/pagecounts-20120101-000000.gz).

## Problem

- Use some combination of: Storm, Hadoop, Cassandra, or MongoDB.
- Write a deploy script (Chef or Puppet or whatever).
- Import the wiki data into the db
- write a small app in favorite language to compute most popular pages by language

# Initial prototype

I wrote a simple ETL pipeline using `awk` scripts as a way to get familiar with the dataset.
It can be found in the [prototype](prototype) directory, along with some stream of consciousness
notes in the [prototype.md](prototype/prototype.md) file.

To run the prototype, cd into the `prototype` dir and run `run.sh`:

```bash
[rule146@rule146: solution]$ cd ../prototype/
[rule146@rule146: prototype]$ lt
total 279144
-rwxr-xr-x+   1 rule146  staff   1.5K May 21 01:10 run.sh*
drwxr-xr-x+   4 rule146  staff   136B May 21 01:11 data/
-rw-r--r--+   1 rule146  staff   136M May 21 01:11 mainspace.txt
drwxr-xr-x+ 310 rule146  staff    10K May 21 01:17 by_lang_filtered/
-rw-r--r--+   1 rule146  staff    90K May 21 01:19 top_pages_by_lang.txt
drwxr-xr-x+ 310 rule146  staff    10K May 21 01:19 counts/
-rw-r--r--+   1 rule146  staff    16K May 22 05:30 prototype.md
[rule146@rule146: prototype]$ ./run.sh
[... snip ...]
```

For example, the page rankings for English are:

```bash
[rule146@rule146: prototype]$ head -12 top_pages_by_lang.txt
==> counts/counts_lang_en.txt <==
1680659 en
124694  Main_Page
28520   Auld_Lang_Syne
13403   Cyndi_Lauper
9166    2012_phenomenon
6929    Bee_Gees
6876    Nina_Simone
6705    Gregory_Porter
6150    404_error
5911    Jools_Holland
```

While this prototype actually solves the problem, awk scripts are not a scalable solution!

# Solution using MongoDB

The MongoDB solution uses a two-stage MapReduce job in a single MongoDB instance to sum the
pageviews for a given language-page pair, and then aggregate by language.
The file [top_pages.js](solution/top_pages.js) contains the MapReduce code in Javascript.

To run the MongoDB solution, go to the `solution` directory and run `run.sh`:

```bash
[rule146@rule146: wiki-rank]$ cd solution/
[rule146@rule146: solution]$ ./run.sh
[... snip ...]
[rule146@rule146: solution]$ lt
total 664
drwxr-xr-x+ 6 rule146  staff   204B May 21 19:40 data/
-rw-r--r--+ 1 rule146  staff   101B May 21 20:51 install.sh
-rw-r--r--+ 1 rule146  staff   1.1K May 22 00:23 top_pages.js
-rw-r--r--+ 1 rule146  staff   232K May 22 01:43 top_pages_by_lang.csv
-rwxr-xr-x+ 1 rule146  staff   2.0K May 22 02:03 run.sh*
-rw-r--r--+ 1 rule146  staff    81K May 22 02:03 top_10_pages_by_lang.csv
```

For example, the page rankings for English are 

```bash
[rule146@rule146: solution]$ grep -E "^\"en\"" -A 10 top_10_pages_by_lang.csv
"en" ...
"en"
"Main_Page"
"Auld_Lang_Syne"
"Cyndi_Lauper"
"2012_phenomenon"
"Bee_Gees"
"Nina_Simone"
"Gregory_Porter"
"404_error"
"Jools_Holland"
=========================================================
```

... which has the same pages and ranking as the prototype above.

# Next steps

- Deploy to EC2 using chef
- Implement the MapReduce job on a _sharded_ MongoDB collection, as described [here](http://docs.mongodb.org/manual/core/map-reduce-sharded-collections/).
