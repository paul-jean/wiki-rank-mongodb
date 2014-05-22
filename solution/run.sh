#! /bin/sh -x

wiki_url="http://dumps.wikimedia.org/other/pagecounts-raw/2012/2012-01/pagecounts-20120101-000000.gz"
wiki_file="./data/pagecounts-20120101-000000.gz"
uncompressed_file="./data/pagecounts-20120101-000000.txt"
tsv_file="./data/pagecounts-20120101-000000.tsv"
random_sample_file="./data/sample.tsv"

log() {
  message=$1
  d=$(date)
  echo "[$d] $message"
}

if [ ! -e data ]
then
  mkdir data
fi
if [ ! -e $wiki_file ]
then
  log "Downloading wiki file to $wiki_file ..."
  curl -o $wiki_file $wiki_url
fi

if [ ! -e $uncompressed_file ]
then
  log "Decompressinng to $uncompressed_file ..."
  gunzip -c $wiki_file > $uncompressed_file
fi

if [ ! -e $tsv_file ]
then
  awk '{printf "%s\t%s\t%d\t%d\n", $1, $2, $3, $4}' $uncompressed_file > $tsv_file
  mongoimport --db wiki --drop --collection pageviews --type tsv --file $tsv_file \
    --fields lang,page,views,bytes
fi

if [ ! -e $random_sample_file ]
then
  awk 'BEGIN {srand()} {if (rand() < 0.001) print $0}' $tsv_file > $random_sample_file
  mongoimport --db wiki --drop --collection pageviews_sample --type tsv --file $random_sample_file \
    --fields lang,page,views,bytes
fi

mongod

ranked_pages_file='top_pages_by_lang.csv'
if [ ! -e $ranked_pages_file ]
then
  mongo top_pages.js
  mongoexport --db wiki --collection 'lang_views_page' --fields '_id.lang','_id.totalViews','value' \
    --csv --out $ranked_pages_file
fi

#awk \
#  'BEGIN { FS = "," }
#  { count=$2; sub(/-/, "", count); sub(/\.0/, "", count);
#    if (NR != 1) printf "%s,%d,%s\n", $1, count, $3}' $ranked_pages_file  > $ranked_pages_file

top_ten_file='top_10_pages_by_lang.csv'
if [ ! -e $top_ten_file ]
then
  langs=$(awk  'BEGIN { FS = "," } {if (NR != 1) print $1}' $ranked_pages_file | uniq)
  for lang in $langs
  do
    echo "$lang ... " >> $top_ten_file
    grep -E "^$lang" $ranked_pages_file | head -10 | \
      awk 'BEGIN {FS=","} {print $3}' >> $top_ten_file
    echo "=========================================================" >> $top_ten_file
    echo "" >> $top_ten_file
  done
fi
