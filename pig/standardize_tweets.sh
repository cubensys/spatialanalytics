#!/bin/sh
# Run as follows:
# $ bash standardize_tweets.sh
# or:
# $ bash standardize_tweets.sh s3://MYBUCKET/parsed-tweets-2010* s3://MYBUCKET/mystandardized_locations.txt 
# $ bash standardize_tweets.sh s3://where20/parsed-tweets-20100210-19


INPUTFILES=s3://where20demo/sample-tweets
if [ -n "$1" ]; then 	# -n tests to see if the argument is non empty
	echo "tweet input path provided, using for tweet source instead of sample data"
	INPUTFILES=$1
fi

STANDARDLOCATIONS=s3://where20demo/standard_locations.txt
if [ -n "$2" ]; then 	# -n tests to see if the argument is non empty
	echo "location mapping input path provided, using for standardized location instead of sample data"
	STANDARDLOCATIONS=$2
fi

echo ----- Running US location counts
pig -p INPUT=$INPUTFILES -l /mnt locationcounts/us_location_counts.pig

echo ----- Running Exact Match to Geonames "City, State"
pig -l /mnt standardization/city_state_exactmatch.pig

echo ----- Running Exact Match to Geonames "City"
pig -l /mnt standardization/city_exactmatch.pig

echo ----- Running Turk Match to Geonames location strings
pig -l /mnt standardization/turk_exactmatch.pig

echo ----- Merging Standardized location strings
pig -l /mnt standardization/standardize_locations.pig
rm /mnt/standard_locations.txt 
hadoop fs -getmerge /standard_locations /mnt/standard_locations.txt
## result is 'standard_locations' 
# location:chararray, std_location:chararray, user_count:int, geonameid:int, population:int, fips:chararray

echo ----- Checking county level user counts...
pig -p INPUT=$STANDARDLOCATIONS -l /mnt countyheatmaps/county_counts.pig
rm /mnt/county_counts.txt 
hadoop fs -getmerge /county_counts /mnt/county_counts.txt

echo ----- Generating list of unknown locations for turkers
pig -p INPUT=$INPUTFILES -l /mnt standardization/locations_timezones.pig
rm /mnt/locations_timezones.csv
hadoop fs -getmerge /user/hadoop/locations_timezones /mnt/locations_timezones.csv
# need to remove UT iphone strings then limit to top 8k for turkers...
grep -i 'ÜT:' -v /mnt/locations_timezones.csv | head -8000 > /mnt/top_8k_us_locations.txt
## TODO: remove any exact matches for countries, states, or state abbrev from turk files
# we can do this with python post-processing


# echo Running tweet standardization...
# echo --------------------------
# pig -p INPUT=$INPUTFILES -l /mnt standardized_tweets.pig