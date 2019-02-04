# DOWNLOAD BASE IMAGE OF CENTOS7
FROM centos:centos7

MAINTAINER alexis rapin

# CREATE APP USER
RUN adduser -m genocrunch_user
WORKDIR /home/genocrunch_user

# MISC
RUN yum -y update && yum clean all
RUN yum -y install nano \
    sudo

# INSTALL RUBY WITH RBENV

# Install dependencies
RUN yum -y install git-core \
    zlib \
    zlib-devel \
    gcc \
    gcc-c++ \
    patch \
    readline \
    readline-devel \
    libyaml-devel \
    libffi-devel \
    openssl-devel \
    make \
    bzip2 \
    bzip2-devel \
    autoconf \
    automake \
    libtool \
    bison \
    curl \
    sqlite-devel \
    epel-release \
    nodejs && yum clean all

# Install rbenv from github
USER genocrunch_user
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv
RUN echo 'export PATH="~/.rbenv/bin:$PATH"' >> ~/.bashrc \
    && echo 'eval "$(~/.rbenv/bin/rbenv init -)"' >> ~/.bashrc
RUN git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
USER root
RUN cd /home/genocrunch_user/.rbenv/plugins/ruby-build && ./install.sh

# Install ruby
USER genocrunch_user
RUN source ~/.bashrc \
  && rbenv install 2.3.1 \
  && rbenv global 2.3.1

# Install rails
RUN echo "gem: --no-document" > ~/.gemrc
RUN source ~/.bashrc \
    && gem install bundler \
    && gem install rails -v 5.0.1 \
    && rbenv rehash
RUN echo 'export PATH="~/.rbenv/versions/2.3.1/bin:$PATH"' >> .bashrc

# INSTALL POSTGRESQL
USER root
RUN yum -y install postgresql \
    postgresql-contrib \
    postgresql-devel \
    postgresql-libs
#RUN postgresql-setup initdb
#RUN sed -i 's/^\(host.*\)ident$/\1md5/g;' /var/lib/pgsql/data/pg_hba.conf
#RUN systemctl start postgresql
#RUN systemctl enable postgresql

# INSTALL PYTHON2.7
#RUN yum install -y python-pip
#RUN pip install numpy
#RUN yum -y groupinstall 'Development Tools'

# INSTALL R
RUN yum install -y R-core \
    R-base \
    R-devel \
    libcurl-devel \
    libxml2-devel

# Install R packages
RUN echo "options(repos=structure(c(CRAN='https://stat.ethz.ch/CRAN')))" >> .Rprofile
RUN echo ".libPaths('/usr/share/R/library')" >> .Rprofile
RUN Rscript -e "install.packages('ineq')"
RUN Rscript -e "install.packages('rjson')"
RUN Rscript -e "install.packages('fpc')"
RUN Rscript -e "install.packages('multcomp')"
RUN Rscript -e "install.packages('FactoMineR')"
RUN Rscript -e "install.packages('colorspace')"
RUN Rscript -e "install.packages('vegan')"
RUN Rscript -e "install.packages('optparse')"
RUN Rscript -e "install.packages('gplots')"
RUN Rscript -e "install.packages('fossil')"
RUN Rscript -e "install.packages('coin')"
RUN Rscript -e "install.packages('SNFtool')"
RUN Rscript -e "install.packages('devtools')"
RUN Rscript -e "library(devtools); install_github('igraph/rigraph')"
RUN Rscript -e "source('https://bioconductor.org/biocLite.R'); biocLite('sva')"

# INSTALL GENOCRUNCH
USER genocrunch_user

# Create a new Rails project
WORKDIR /home/genocrunch_user
RUN source ~/.bashrc \
    && rails new genocrunch -d postgresql -B
RUN GIT_CURL_VERBOSE=1 git clone https://github.com/genocrunch/genocrunch.git /tmp/genocrunch
WORKDIR /home/genocrunch_user/genocrunch
RUN rsync -r /tmp/genocrunch/ ./
RUN rm -r /tmp/genocrunch

# Install R/python scripts
#RUN chmod 755 install.sh && ./install.sh

# Install gems
RUN source ~/.bashrc \
    && bundle install
RUN table_fp=$(cd ~/.rbenv/versions/*/lib/ruby/gems/*/gems/jquery-datatables-rails-*/app/assets/javascripts/dataTables/ && pwd) \
    && cp "${table_fp}"/jquery.dataTables.js "${table_fp}"/jquery.dataTables.js.bkp \
    && sed -i -e 's/No data available in table/This table is empty/g' "${table_fp}"/jquery.dataTables.js

# Get versions (print a json file with versions of R packages)
RUN lib/genocrunch_console/bin/get_version.py

# CONFIGURE GENOCRUNCH
USER root
EXPOSE 3000
USER genocrunch_user

RUN cp config/config.yml.keep config/config.yml
RUN sed -i 's/data_dir:.*$/data_dir: \/home\/genocrunch_user\/genocrunch/g' config/config.yml

RUN cp config/initializers/devise.rb.keep config/initializers/devise.rb

RUN cp config/environments/development.rb.keep config/environments/development.rb

RUN cp config/database.yml.keep config/database.yml
RUN sed -i 's/^.*host:.*$/  host: hostaddress/g' config/database.yml

RUN cp db/seeds.rb.keep db/seeds.rb

RUN cp public/app/TERMS_OF_SERVICE.txt.keep public/app/TERMS_OF_SERVICE.txt

# RUN GENOCRUNCH WEB SERVER
CMD source ~/.bashrc \
    && RAILS_ENV=development ruby bin/delayed_job -n 2 start; /home/genocrunch_user/genocrunch/bin/rails server

