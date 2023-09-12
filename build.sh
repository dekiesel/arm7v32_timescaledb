docker build --build-arg POSTGIS_VERSION=3.2.1 \
             --build-arg GDAL_VERSION=3.5.1 \
             --build-arg PROJ_VERSION=9.0.1 \
             --build-arg TIMESCALEDB_VERSION=2.7.x \
	     --build-arg PG_VERSION=14 \
	     -t timescaledb-postgis:2.7.x-pg14 .
