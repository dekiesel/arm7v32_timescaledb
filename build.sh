docker build --build-arg POSTGIS_VERSION=3.0.2 \
             --build-arg GDAL_VERSION=3.2.0 \
             --build-arg PROJ_VERSION=7.0.1 \
             --build-arg TIMESCALEDB_VERSION=1.7.4 \
	     --build-arg PG_VERSION=12 \
	     -t timescaledb-postgis:1.7.4-pg12 .
