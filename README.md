# arm7v32_timescaledb

A `timescaledb-postgis` docker-container that runs on raspberry pi's/arm7v32-processors. 

# Usage

The build script `build.sh` is all you should need, but if you want different versions of the used packages edit it and then execute it:

>bash build.sh

If you don't want to wait the ~2h it takes to build this on a rpi you can download the image from [docker hub](https://hub.docker.com/repository/docker/dekiesel/timescaledb-postgis/general).

# Improvements

The image is quite big. If anybody knows a way to improve it please let me know.

