#!/bin/sh
#find  -type f | xargs du -bs | awk '{print NR":", $1"bytes", $2}'
ls -ARl | sed -n '/^[-d]/p' | sort --key 5 --reverse --numeric-sort | awk 'BEGIN{fc=dc=sz=0} /^-/{fc+=1; sz+=$5; if (fc <= 5) print fc ": " $5 "bytes " $9} /^d/{dc+=1} END{print "File Count: " fc "\nDir Count: " dc "\nTotal Size: " sz "bytes"}'
