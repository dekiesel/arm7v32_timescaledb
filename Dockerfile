#ARG PG_VERSION=11
ARG PG_VERSION=${PG_VERSION}
FROM arm32v7/golang:1.14-alpine AS tools
MAINTAINER David Kesselheim
############################
# Build tools binaries in separate image
############################
#FROM golang:${GO_VERSION}-alpine AS tools

ENV TOOLS_VERSION 0.7.0

RUN set -ex && apk update && apk add --no-cache git \
    && mkdir -p ${GOPATH}/src/github.com/timescale/ \
    && cd ${GOPATH}/src/github.com/timescale/ \
    && git clone https://github.com/timescale/timescaledb-tune.git \
    && git clone https://github.com/timescale/timescaledb-parallel-copy.git \
    # Build timescaledb-tune
    && cd timescaledb-tune/cmd/timescaledb-tune \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && go build -o /go/bin/timescaledb-tune \
    # Build timescaledb-parallel-copy
    && cd ${GOPATH}/src/github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && go build -o /go/bin/timescaledb-parallel-copy

############################
# Now build image and copy in tools
############################
FROM arm32v7/postgres:${PG_VERSION}-alpine
ARG PG_VERSION
ARG TIMESCALEDB_VERSION

ENV TIMESCALEDB_VERSION ${TIMESCALEDB_VERSION}

COPY --from=tools /go/bin/* /usr/local/bin/

RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
                krb5-dev \
    && mkdir -p /build/ \
    && git clone https://github.com/timescale/timescaledb /build/timescaledb \
    \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                dpkg-dev dpkg \
                gcc \
                libc-dev \
                make \
                cmake \
                util-linux-dev \
    \
    # Build current version \
    && cd /build/timescaledb && rm -fr build \
    && git checkout ${TIMESCALEDB_VERSION} \
    && ./bootstrap -DREGRESS_CHECKS=OFF -DPROJECT_INSTALL_METHOD="docker" \
    && cd build && make install \
    && cd ~ \
    \
    #&& apk del .fetch-deps .build-deps \
    && rm -rf /build \
    && sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" /usr/local/share/postgresql/postgresql.conf.sample

######POSTGIS SECTION

# Setup build env for PROJ
RUN apk add --no-cache clang llvm tar gzip wget curl unzip -q make libtool autoconf automake pkgconfig g++ sqlite sqlite-dev \
    linux-headers \
    curl-dev tiff-dev \
    zlib-dev zstd-dev \
    libjpeg-turbo-dev libpng-dev openjpeg-dev libwebp-dev expat-dev \
    py3-numpy-dev python3-dev py3-numpy \
    openexr-dev \
    # For spatialite (and GDAL)
    libxml2-dev \
    && mkdir -p /build_thirdparty/usr/lib

RUN \
    mkdir -p /build_projgrids/usr/share/proj \
    && curl -LOs http://download.osgeo.org/proj/proj-datumgrid-latest.zip \
    && unzip -q -j -u -o proj-datumgrid-latest.zip  -d /build_projgrids/usr/share/proj \
    && rm -f *.zip


#Build PROJ
ARG PROJ_VERSION
ENV PROJ_VERSION ${PROJ_VERSION}
RUN set -ex \
    &&	mkdir proj\
    && wget -q https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz -O - \
        | tar xz -C proj --strip-components=1 \
    && cd proj\
    && mkdir build\
    && cd build\
    && cmake ..\
    && cmake --build .\
    && cmake --build . --target install\
    && ./configure --prefix=/usr --disable-static --enable-lto \
    && make -j$(nproc) \
    && make install \
    && make install DESTDIR="/build_proj" \
    && if test "${RSYNC_REMOTE}" != ""; then \
        ccache -s; \
        echo "Uploading cache..."; \
        rsync -ra --delete $HOME/.ccache ${RSYNC_REMOTE}/proj/; \
        echo "Finished"; \
        rm -rf $HOME/.ccache; \
        unset CC; \
        unset CXX; \
    fi \
    && cd ../.. \
haven't continued with anything f.o.m here. Timescaledb now seems to publish arm containers. I haven't checked though!
    && rm -rf proj \
    && for i in /build_proj/usr/lib/*; do strip -s $i 2>/dev/null || /bin/true; done \
    && for i in /build_proj/usr/bin/*; do strip -s $i 2>/dev/null || /bin/true; done

#Build GDAL
ARG GDAL_VERSION
ENV GDALVERSION ${GDAL_VERSION}
RUN set -ex && \
  apk update && \
  apk add --virtual build-dependencies \
    # to reach GitHub's https
    openssl ca-certificates \
    build-base cmake musl-dev linux-headers \
    # for libkml compilation
    zlib-dev minizip-dev expat-dev uriparser-dev boost-dev && \
  apk add \
    # libkml runtime
    zlib minizip expat uriparser boost && \
  update-ca-certificates 
ENV GDAL_VERSION ${GDAL_VERSION}
RUN set -ex \ && \
	mkdir gdal && cd gdal &&\
	wget -O gdal.tar.gz "http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" &&\
  tar --extract --file gdal.tar.gz --strip-components 1 && \
  ./configure --prefix=/usr \
    --with-libkml \
    --without-bsb \
    --without-dwgdirect \
    --without-ecw \
    --without-fme \
    --without-gnm \
    --without-grass \
    --without-grib \
    --without-hdf4 \
    --without-hdf5 \
    --without-idb \
    --without-ingress \
    --without-jasper \
    --without-mrf \
    --without-mrsid \
    --without-netcdf \
    --without-pcdisk \
    --without-pcraster \
    --without-webp \
   # --with-proj=/usr/local \
  && make && make install \
  && cd .. && rm -rf gdal

#Build POSTGIS
ARG POSTGIS_VERSION
ENV POSTGIS_VERSION ${POSTGIS_VERSION}
RUN set -ex \
    #&& apk add --no-cache --virtual .fetch-deps \
    && apk add --no-cache --virtual \
                ca-certificates \
                openssl \
                tar \
    # add libcrypto from (edge:main) for gdal-2.3.0
    && apk add --no-cache --virtual .crypto-rundeps \
                --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
                #libressl2.7-libcrypto \
                libressl \
                libcrypto1.1 \
    && apk add --no-cache --virtual .postgis-deps --repository http://nl.alpinelinux.org/alpine/edge/testing --repository  http://dl-cdn.alpinelinux.org/alpine/edge/main \
        geos \
        #gdal \
        #proj \
        protobuf-c \
    && apk add --no-cache --virtual .build-deps --repository http://nl.alpinelinux.org/alpine/edge/testing \
        postgresql-dev \
        perl \
        file \
        geos-dev \
        libxml2-dev \
        #gdal-dev \
        #proj-dev \
        protobuf-c-dev \
        json-c-dev \
        gcc g++ \
        make \
    && cd /tmp \
    && wget http://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz -O - | tar -xz \
    && chown root:root -R postgis-${POSTGIS_VERSION} \
    && cd /tmp/postgis-${POSTGIS_VERSION} \
    && ./configure \
    && echo "PERL = /usr/bin/perl" >> extensions/postgis/Makefile \
    && echo "PERL = /usr/bin/perl" >> extensions/postgis_topology/Makefile \
    && make -s \
    && make -s install \
    && apk add --no-cache --virtual .postgis-rundeps \
        json-c \
    && cd / \
    \
    && rm -rf /tmp/postgis-${POSTGIS_VERSION} \
    && apk del .fetch-deps .build-deps
