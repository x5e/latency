FROM ubuntu:16.04
RUN apt-get update
RUN apt-get install -y vim-tiny ssh python3-numpy python3-psycopg2 python3-tz
RUN apt-get install -y git wget curl postgresql-client python3-boto3 awscli
RUN apt-get install -y unzip
WORKDIR /opt
RUN wget -O forker-master.zip https://codeload.github.com/darinmcgill/forker/zip/master
RUN unzip forker-master.zip
RUN ln -s forker-master forker
RUN mkdir -p /opt/latency
WORKDIR /opt/latency
COPY . .
