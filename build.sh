docker build --build-arg POSTGIS_VERSION=3.0.0 \
             --build-arg GDAL_VERSION=3.0.4 \
             --build-arg PROJ_VERSION=7.0.0 \
             --build-arg TIMESCALEDB_VERSION=1.6.0 \
	     --build-arg PG_VERSION=11 \
	     --build-arg PREV_TS_VERSION=1.6.0 \
	     -t timescaledb_postgis:1.0 .
