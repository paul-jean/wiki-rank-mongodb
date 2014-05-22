#! /bin/sh -x

wiki_url="http://dumps.wikimedia.org/other/pagecounts-raw/2012/2012-01/pagecounts-20120101-000000.gz"
wiki_file="./data/pagecounts-20120101-000000.gz"
uncompressed_file="./data/pagecounts-20120101-000000.txt"

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

mainspace_file="mainspace.txt"
filtered_dir="by_lang_filtered"
counts_dir="counts"
if [ ! -e $mainspace_file ]
then
  log "Filtering pageviews to include only mainspace pages ..."
  awk '{if ($2 !~ /:/) printf "%s\t%s\t%s\n", $1, $2, $3}' $uncompressed_file > $mainspace_file
fi
if [ ! -e $filtered_dir ]
then
  mkdir $filtered_dir
  log "Breaking down pageviews by language ..."
  awk '{lang=split($1, l, "."); file="by_lang_filtered/lang_"l[1]".txt"; print $0 >> file; close(file)}' $mainspace_file
fi
if [ ! -e $counts_dir ]
then
  mkdir $counts_dir
  log "Tallying and ranking pageviews by language ..."
  for file in $(ls -1 by_lang_filtered);
  do
    awk '{a[$2]+=$3} END {for (page in a) printf "%d\t%s\n", a[page], page}' by_lang_filtered/$file | sort -nr > counts/counts_$file; log $file;
  done
fi

rank_file=top_pages_by_lang.txt
if [ ! -e $rank_file ]
then
  log "Creating rank file ..."
  head -10 $(ls -1S counts/*)  > $rank_file
fi

log "Pageview rankings written to file $rank_file"
