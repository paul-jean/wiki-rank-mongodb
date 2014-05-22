# Prototype

The uncompressed file contains 5.5 million lines:

```bash
[rule146@rule146: data]$ wc -l pagecounts-20120101-000000.txt
 5596068 pagecounts-20120101-000000.txt
```
A bunch of lines need to be filtered out. Pages with prefixes like "Special:", "User:", and "File:" need to be filtered out.

Get a random sample of lines, to mess with:

```bash
[rule146@rule146: data]$ awk 'BEGIN {srand()} !/^$/ { if (rand() <= .01) print $0}' pagecounts-20120101-000000.txt > rand-sample.txt
[rule146@rule146: data]$ wc -l rand-sample.txt
   56254 rand-sample.txt
```

The top 10 languages in the random sample:

```bash
[rule146@rule146: data]$ awk '{print $1}' rand-sample.txt | awk '{a[$1]+=1} END {for (val in a) printf "%s\t%s\n", a[val], val}' | sort -r -n | head -10
21875   en
2705    es
2696    ja
2392    fr
2330    pl
2327    de
2089    ru
1959    commons.m
1345    it
1328    pt
```

The top 10 pageviews by language in the random sample:

```bash
[rule146@rule146: data]$ awk '{printf "%s\t%d\n", $1, $3}' rand-sample.txt | awk '{a[$1]+=$2} END {for (val in a) printf "%s\t%s\n", a[val], val}' | sort -r -n | head -10
1680652 en.mw
77002   en
7808    es
7067    de
6662    fr
6322    ja
4646    ru
3904    pl
2900    pt
2703    it
```

## Filtering

I want to know what [namespaces](http://en.wikipedia.org/wiki/Wikipedia:Namespace) need to be filtered out, in addition to the ones mentioned: "Special:", "User:", "File:", etc.

Grab the top prefixes (stuff before the colon) in the page names:

```bash
[rule146@rule146: data]$ awk '{print $2}' pagecounts-20120101-000000.txt | grep -E ".*:.*" | perl -pe 's|([^:]+):.*|\1|' | sort | uniq -c | sort -nr > prefixes.txt
[rule146@rule146: data]$ head -20 prefixes.txt
322531 File
188953 Special
99427 Category
34703 %E7%89%B9%E5%88%A5
27437 Talk
24193 Template
22307 User
20928 Fichier
20398 Archivo
20027 %D0%A4%D0%B0%D0%B9%D0%BB
16543 Template_talk
15716 Sp%C3%A9cial
13440 Spezial
12365 Wikipedia
11405 Kategori
11131 Especial
11106 %E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB
10546 User_talk
9754 Categoria
8105 Kategoria
```

It looks like everything outside of the [mainspace](http://en.wikipedia.org/wiki/Wikipedia:Main_namespace) can safely be ignored.
The mainspace wiki page states that pages outside of the mainspace are not considered articles:

"Disambiguation pages, templates, navboxes, user pages, discussion pages, file pages, category pages, help pages and Wikipedia policy pages are not articles."

There are 1.2 million pages outside the mainspace, and need to be filtered out:

```bash
[rule146@rule146: data]$ awk '{print $2}' pagecounts-20120101-000000.txt | grep -E ".*:.*" | wc -l
 1240353
```

Keep only mainspace pageviews:

```bash
[rule146@rule146: data]$ awk '{if ($2 !~ /:/) printf "%s\t%s\t%s\n", $1, $2, $3}' pagecounts-20120101-000000.txt > mainspace.txt
[rule146@rule146: data]$ wc -l mainspace.txt
 4355715 mainspace.txt
[rule146@rule146: data]$ ls -lh mainspace.txt
-rw-r--r--+ 1 rule146  staff   136M May 20 21:36 mainspace.txt
```
Separate the pageviews by language, one language per file:

```bash
[rule146@rule146: data]$ mkdir by_lang_filtered; awk '{file="by_lang_filtered/lang_"$1".txt"; print $0 >> file; close(file)}' mainspace.txt
[rule146@rule146: data]$ ls -Shl by_lang_filtered | head
total 285496
-rw-r--r--+ 1 rule146  staff    42M May 20 21:43 lang_en.txt
-rw-r--r--+ 1 rule146  staff    14M May 20 21:44 lang_ru.txt
-rw-r--r--+ 1 rule146  staff    13M May 20 21:43 lang_ja.txt
-rw-r--r--+ 1 rule146  staff   5.1M May 20 21:43 lang_es.txt
-rw-r--r--+ 1 rule146  staff   5.0M May 20 21:44 lang_pl.txt
-rw-r--r--+ 1 rule146  staff   4.6M May 20 21:43 lang_fr.txt
-rw-r--r--+ 1 rule146  staff   4.5M May 20 21:42 lang_de.txt
-rw-r--r--+ 1 rule146  staff   2.7M May 20 21:44 lang_zh.txt
-rw-r--r--+ 1 rule146  staff   2.6M May 20 21:44 lang_pt.txt
```

There are 1091 languages:

```bash
[rule146@rule146: data]$ ls -1 by_lang_filtered | wc -l
    1091
```

Tally up the pageviews for the english language pages and show the top 10:

```bash
[rule146@rule146: data]$ mkdir counts; awk '{a[$2]+=$3} END {for (page in a) printf "%d\t%s\n", a[page], page}' by_lang_filtered/lang_en.txt | sort -nr > counts/counts_en.txt
[rule146@rule146: data]$ head counts/counts_en.txt
123670  Main_Page
28513   Auld_Lang_Syne
13403   Cyndi_Lauper
9166    2012_phenomenon
6929    Bee_Gees
6876    Nina_Simone
6705    Gregory_Porter
6150    404_error
5911    Jools_Holland
5583    New_Year%27s_Eve
```
These look like reasonable top pages to me. The main page would frequently be the first page viewed by people searching wikipedia (outside of Google), so it makes
sense it gets the most pageviews. And New Year's eve is a topic on people's minds on January 1st, so I'm willing to believe it's in the top 10. The 404 page
also probably gets shown a lot when people click old links that don't have redirects.

Do the pageview ranking for each individual language:

```bash
[rule146@rule146: data]$ bash
bash-3.2$ for file in $(ls -1 by_lang_filtered); do awk '{a[$2]+=$3} END {for (page in a) printf "%d\t%s\n", a[page], page}' by_lang_filtered/$file | sort -nr > counts/counts_$file; echo $file; done
```

Collect the top 10 pages for each language:

```bash
[rule146@rule146: data]$ head -10 $(ls -1S counts/*)  > top_pages_by_lang.txt
[rule146@rule146: data]$ head -100 top_pages_by_lang.txt
==> counts/counts_lang_en.txt <==
123670  Main_Page
28513   Auld_Lang_Syne
13403   Cyndi_Lauper
9166    2012_phenomenon
6929    Bee_Gees
6876    Nina_Simone
6705    Gregory_Porter
6150    404_error
5911    Jools_Holland
5583    New_Year%27s_Eve

==> counts/counts_lang_ja.txt <==
7959    %E3%83%A1%E3%82%A4%E3%83%B3%E3%83%9A%E3%83%BC%E3%82%B8
4681    %E5%B1%B1%E7%94%B0%E5%AD%9D%E4%B9%8B
2917    %E5%88%9D%E5%A4%A2
1993    %E5%B9%B3%E7%94%B0%E4%BF%A1
1666    AV%E5%A5%B3%E5%84%AA%E4%B8%80%E8%A6%A7
1627    %E7%8C%AA%E8%8B%97%E4%BB%A3%E6%B9%96%E3%82%BA
1624    %E6%B8%A9%E6%B0%B4%E6%B4%8B%E4%B8%80
1321    Chiho
1205    %E3%83%AD%E3%83%B3%E3%83%89%E3%83%B3%E3%82%AA%E3%83%AA%E3%83%B3%E3%83%94%E3%83%83%E3%82%AF_(2012%E5%B9%B4)
1197    %E3%83%AD%E3%83%B3%E3%83%89%E3%83%B3%E3%83%BB%E3%82%AA%E3%83%AA%E3%83%B3%E3%83%94%E3%83%83%E3%82%AF%E3%82%B9%E3%82%BF%E3%82%B8%E3%82%A2%E3%83%A0

==> counts/counts_lang_es.txt <==
12957   Alaska_(cantante)
4727    Anne_Igartiburu
4454    Ana_Torroja
3533    Pitingo
3296    Laura_Pausini
2497    2012
2148    Carlos_Baute
1680    Forrest_Gump
1646    David_Summers
1568    A%C3%B1o_Nuevo

==> counts/counts_lang_pl.txt <==
4289    Strona_g%C5%82%C3%B3wna
3201    w/index.php
2891    Co_si%C4%99_wydarzy%C5%82o_w_Madison_County
2380    D%C5%BCem_(grupa_muzyczna)
1419    Monika_Brodka
1224    Ryszard_Riedel
1083    Iwona_W%C4%99growska
1080    Blue_Caf%C3%A9
954     Nowy_Rok
832     Maryla_Rodowicz

==> counts/counts_lang_fr.txt <==
3188    Sim
3044    C._J%C3%A9r%C3%B4me
2333    2012
2078    Carlos_(chanteur)
1567    Michel_Berger
1486    Sophie_Thalmann
1352    Pr%C3%A9dictions_pour_d%C3%A9cembre_2012
1012    Aliz%C3%A9e
967     Patrick_Bruel
904     Cl%C3%A9mentine_C%C3%A9lari%C3%A9

==> counts/counts_lang_de.txt <==
3303    Take_That
2698    Dschinghis_Khan
2593    Hauptseite
2380    Andrea_Berg
2288    Leg_dich_nicht_mit_Zohan_an
2098    Bleigie%C3%9Fen
1888    Robbie_Williams
1773    Utopie
1772    Utopie%23Gesellschaftliche_Utopien
1602    Dinner_for_One

==> counts/counts_lang_zh.txt <==
342     null
335     %E6%9D%8E%E6%B4%AA%E5%BF%97
219     AV%E5%A5%B3%E5%84%AA
211     %E5%85%83%E6%97%A6
189     %E8%85%8A%E5%85%AB%E8%8A%82
186     %E5%88%87%E6%96%AF%E7%89%B9%C2%B7%E5%A8%81%E5%BB%89%C2%B7%E5%B0%BC%E7%B1%B3%E5%85%B9
144     %E7%99%BE%E5%BA%A6
138     favicon.ico
138     %E5%A4%A9%E8%88%87%E5%9C%B0_(%E7%84%A1%E7%B6%AB%E9%9B%BB%E8%A6%96%E5%8A%87)
133     Favicon.ico

==> counts/counts_lang_he.txt <==
1095    %D7%A2%D7%9E%D7%95%D7%93_%D7%A8%D7%90%D7%A9%D7%99
531     %D7%A1%D7%99%D7%9C%D7%91%D7%A1%D7%98%D7%A8
148     %D7%A1%D7%99%D7%9C%D7%91%D7%A1%D7%98%D7%A8_%D7%94%D7%A8%D7%90%D7%A9%D7%95%D7%9F
100     %D7%90%D7%95%D7%A8%D7%9F_%D7%9B%D7%94%D7%9F
84      %D7%A7%D7%A4%D7%94
68      2012
67      %D7%99%D7%94%D7%93%D7%95%D7%AA_%D7%97%D7%A8%D7%93%D7%99%D7%AA
61      %D7%9E%D7%A9%D7%9E%D7%A2%D7%95%D7%AA_%D7%94%D7%97%D7%99%D7%99%D7%9D
61      %D7%9E%D7%99%D7%96%D7%95%D7%A8%D7%99
49      %D7%9E%D7%90%D7%99%D7%94

==> counts/counts_lang_fa.txt <==
302     %D8%B5%D9%81%D8%AD%D9%87%D9%94_%D8%A7%D8%B5%D9%84%DB%8C
111     %D8%B7%D8%B1%D8%AD_%D8%A7%D8%B1%D8%AA%D9%82%D8%A7%DB%8C_%D8%A7%D9%85%D9%86%DB%8C%D8%AA_%D8%A7%D8%AC%D8%AA%D9%85%D8%A7%D8%B9%DB%8C
61      %D8%A2%D9%85%DB%8C%D8%B2%D8%B4_%D8%AC%D9%86%D8%B3%DB%8C
```

## MongoDB

```bash
+ mongoimport --db wiki --collection pageviews --type tsv --file ./data/pagecounts-20120101-000000.txt --fields lang,page,views,bytes
connected to: 127.0.0.1
2014-05-21T12:22:45.000-0500            Progress: 7511595/238658053     3%
2014-05-21T12:22:45.000-0500                    108300  36100/second
2014-05-21T12:22:48.000-0500            Progress: 14824744/238658053    6%
2014-05-21T12:22:48.000-0500                    248200  41366/second
2014-05-21T12:22:51.073-0500            Progress: 21161722/238658053    8%
2014-05-21T12:22:51.073-0500                    381600  42400/second
2014-05-21T12:22:54.024-0500            Progress: 25763025/238658053    10%
2014-05-21T12:22:54.024-0500                    525200  43766/second
2014-05-21T12:22:57.000-0500            Progress: 30263918/238658053    12%
2014-05-21T12:22:57.000-0500                    670400  44693/second
2014-05-21T12:23:00.007-0500            Progress: 35640807/238658053    14%
2014-05-21T12:23:00.007-0500                    809500  44972/second
2014-05-21T12:23:03.104-0500            Progress: 40114448/238658053    16%
2014-05-21T12:23:03.104-0500                    926800  44133/second
2014-05-21T12:23:06.021-0500            Progress: 44335216/238658053    18%
2014-05-21T12:23:06.021-0500                    1063500 44312/second
2014-05-21T12:23:09.058-0500            Progress: 48851190/238658053    20%
2014-05-21T12:23:09.058-0500                    1206300 44677/second
2014-05-21T12:23:12.012-0500            Progress: 53522280/238658053    22%
2014-05-21T12:23:12.012-0500                    1345800 44860/second
2014-05-21T12:23:15.026-0500            Progress: 58197933/238658053    24%
2014-05-21T12:23:15.026-0500                    1485300 45009/second
2014-05-21T12:23:18.000-0500            Progress: 64498020/238658053    27%
2014-05-21T12:23:18.000-0500                    1627400 45205/second
2014-05-21T12:23:21.055-0500            Progress: 68408788/238658053    28%
2014-05-21T12:23:21.055-0500                    1748400 44830/second
2014-05-21T12:23:24.031-0500            Progress: 72562288/238658053    30%
2014-05-21T12:23:24.031-0500                    1883900 44854/second
2014-05-21T12:23:27.000-0500            Progress: 77004514/238658053    32%
2014-05-21T12:23:27.000-0500                    2019400 44875/second
2014-05-21T12:23:30.056-0500            Progress: 81238222/238658053    34%
2014-05-21T12:23:30.056-0500                    2156600 44929/second
2014-05-21T12:23:33.018-0500            Progress: 85425154/238658053    35%
2014-05-21T12:23:33.018-0500                    2294200 44984/second
2014-05-21T12:23:36.000-0500            Progress: 89699454/238658053    37%
2014-05-21T12:23:36.000-0500                    2433700 45068/second
2014-05-21T12:23:39.522-0500            Progress: 93782610/238658053    39%
2014-05-21T12:23:39.522-0500                    2542000 44596/second
2014-05-21T12:23:42.000-0500            Progress: 99456141/238658053    41%
2014-05-21T12:23:42.000-0500                    2654500 44241/second
2014-05-21T12:23:45.001-0500            Progress: 104069362/238658053   43%
2014-05-21T12:23:45.001-0500                    2787400 44244/second
2014-05-21T12:23:48.112-0500            Progress: 108514673/238658053   45%
2014-05-21T12:23:48.112-0500                    2926700 44343/second
2014-05-21T12:23:51.073-0500            Progress: 113108360/238658053   47%
2014-05-21T12:23:51.073-0500                    3062500 44384/second
2014-05-21T12:23:54.088-0500            Progress: 118240713/238658053   49%
2014-05-21T12:23:54.088-0500                    3204600 44508/second
2014-05-21T12:23:57.094-0500            Progress: 122367040/238658053   51%
2014-05-21T12:23:57.094-0500                    3340600 44541/second
2014-05-21T12:24:00.000-0500            Progress: 129545686/238658053   54%
2014-05-21T12:24:00.000-0500                    3467800 44458/second
2014-05-21T12:24:03.026-0500            Progress: 134083565/238658053   56%
2014-05-21T12:24:03.026-0500                    3598700 44428/second
2014-05-21T12:24:06.000-0500            Progress: 138876312/238658053   58%
2014-05-21T12:24:06.000-0500                    3735900 44475/second
2014-05-21T12:24:09.000-0500            Progress: 146377700/238658053   61%
2014-05-21T12:24:09.000-0500                    3865900 44435/second
2014-05-21T12:24:12.115-0500            Progress: 150783096/238658053   63%
2014-05-21T12:24:12.115-0500                    4000600 44451/second
2014-05-21T12:24:15.013-0500            Progress: 159430400/238658053   66%
2014-05-21T12:24:15.013-0500                    4118900 44289/second
2014-05-21T12:24:18.047-0500            Progress: 170257531/238658053   71%
2014-05-21T12:24:18.047-0500                    4243200 44200/second
2014-05-21T12:24:21.425-0500            Progress: 177463586/238658053   74%
2014-05-21T12:24:21.425-0500                    4363500 44075/second
2014-05-21T12:24:24.110-0500            Progress: 182012003/238658053   76%
2014-05-21T12:24:24.110-0500                    4474200 43864/second
2014-05-21T12:24:27.023-0500            Progress: 185739249/238658053   77%
2014-05-21T12:24:27.023-0500                    4593300 43745/second
2014-05-21T12:24:30.009-0500            Progress: 187166454/238658053   78%
2014-05-21T12:24:30.009-0500                    4638000 42944/second
2014-05-21T12:24:33.014-0500            Progress: 191465027/238658053   80%
2014-05-21T12:24:33.014-0500                    4762800 42908/second
2014-05-21T12:24:36.162-0500            Progress: 195943015/238658053   82%
2014-05-21T12:24:36.162-0500                    4891900 42911/second
2014-05-21T12:24:39.000-0500            Progress: 204197167/238658053   85%
2014-05-21T12:24:39.000-0500                    5002300 42754/second
2014-05-21T12:24:42.063-0500            Progress: 216682579/238658053   90%
2014-05-21T12:24:42.063-0500                    5118400 42653/second
exception:Invalid UTF8 character detected
2014-05-21T12:24:45.005-0500            Progress: 221640689/238658053   92%
2014-05-21T12:24:45.005-0500                    5241699 42615/second
2014-05-21T12:24:48.113-0500            Progress: 227338582/238658053   95%
2014-05-21T12:24:48.113-0500                    5364999 42579/second
2014-05-21T12:24:51.062-0500            Progress: 233589837/238658053   97%
2014-05-21T12:24:51.062-0500                    5495199 42598/second
2014-05-21T12:24:53.361-0500 check 9 5596067
2014-05-21T12:24:53.456-0500 imported 5596067 objects
encountered 1 error(s)
```

Not sure what that UTF8 character exception is caused by ... The file
appears to be UTF-8 encoded:

```bash
[rule146@rule146: solution]$ file data/pagecounts-20120101-000000.txt
data/pagecounts-20120101-000000.txt: UTF-8 Unicode text, with very long lines
```

Ignoring this for now.

```bash
[rule146@rule146: solution]$ wc -l data/pagecounts-20120101-000000.tsv
 5596068 data/pagecounts-20120101-000000.tsv
```

There were 5,596,067 rows imported vs 5,569,068 lines in the tsv, so the import lost one row due to the invalid UTF-8 character error.

Here's the solution using MongoDB:

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


