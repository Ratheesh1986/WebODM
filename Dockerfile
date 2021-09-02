FROM ubuntu:20.04
MAINTAINER Piero Toffanin <pt@masseranolabs.com>

ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH $PYTHONPATH:/webodm
ENV PROJ_LIB=/usr/share/proj

# Prepare directory
RUN mkdir /webodm
WORKDIR /webodm

RUN apt-get -qq update && apt-get install -y software-properties-common tzdata
RUN add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable

# Install Node.js
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends wget curl
RUN wget --no-check-certificate https://deb.nodesource.com/setup_12.x -O /tmp/node.sh && bash /tmp/node.sh
RUN apt-get -qq update && apt-get -qq install -y nodejs

# Install Python3, GDAL, nginx, letsencrypt, psql
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends python3 python3-pip python3-setuptools python3-wheel git g++ python3-dev python2.7-dev libpq-dev binutils libproj-dev gdal-bin libgdal-dev python3-gdal nginx certbot grass-core gettext-base cron postgresql-client-12 gettext
RUN update-alternatives --install /usr/bin/python python /usr/bin/python2.7 1 && update-alternatives --install /usr/bin/python python /usr/bin/python3.8 2

# Force usage of proj.db version 6
RUN rm -fr /usr/share/proj && mkdir /usr/share/proj && wget --no-check-certificate https://github.com/OpenDroneMap/WebODM/releases/download/v1.9.2/proj-data_6.3.1-1.tar.xz -O - | tar -Jx

# Install pip reqs
ADD requirements.txt /webodm/
RUN pip install -r requirements.txt

ADD . /webodm/

# Setup cron
RUN ln -s /webodm/nginx/crontab /var/spool/cron/crontabs/root && chmod 0644 /webodm/nginx/crontab && service cron start && chmod +x /webodm/nginx/letsencrypt-autogen.sh

#RUN git submodule update --init

WORKDIR /webodm/nodeodm/external/NodeODM
RUN npm install --quiet

WORKDIR /webodm
RUN npm install --quiet -g webpack@4.16.5 && npm install --quiet -g webpack-cli@4.2.0 && npm install --quiet && webpack --mode production
RUN echo "UTC" > /etc/timezone
RUN python manage.py collectstatic --noinput
RUN python manage.py rebuildplugins
RUN python manage.py translate build --safe

# Cleanup
RUN apt-get remove -y g++ python3-dev libpq-dev && apt-get autoremove -y
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

RUN rm /webodm/webodm/secret_key.py

VOLUME /webodm/app/media
