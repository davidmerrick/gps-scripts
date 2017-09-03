FROM perl:5

RUN apt-get update
RUN apt-get install -y libgd-gd2-perl

WORKDIR /usr/src/app/

COPY bin /usr/src/app/bin/

