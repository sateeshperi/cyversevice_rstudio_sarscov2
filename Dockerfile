FROM cyversevice/rstudio-verse:4.0.0-ubuntu18.04

USER root 

WORKDIR /usr/local/src
ENV PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV TERM=xterm
ENV DEBIAN_FRONTEND=noninteractive

# install conda
RUN apt-get update

RUN apt-get install -y wget && rm -rf /var/lib/apt/lists/*

RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash Miniconda3-latest-Linux-x86_64.sh -p /opt/conda -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh 
ENV PATH=/opt/conda/bin:${PATH}
RUN conda update -y conda

# install conda packages
COPY ./environment.yml /usr/local/src
RUN conda update -n base -c defaults conda
RUN conda env update -n base -f environment.yml && \
    conda clean --all

# Copy source files
RUN export PATH=${PATH}
RUN export TERM=${TERM}
RUN export DEBIAN_FRONTEND=${DEBIAN_FRONTEND}

COPY "./src_files/trimmomatic/*" "./trimmomatic/"
COPY "./src_files/plotcov3/*" "./plotcov3/"
COPY "./src_files/report_to_excel_v3/*" "./report_to_excel_v3/"
COPY "./src_files/scripts/*" "./scripts/"
COPY "./src_files/py_pip3/*" "./py_pip3/"
COPY "./src_files/dot_config/*" "./dot_config/"
COPY "./src_files/dot_config/tz_seed.txt" "/debconf_preseed.txt"
COPY "./src_files/pangolin/requirements.txt" "./pangolin/"
COPY "./src_files/entry.sh" "/bin"
COPY "./src_files/.bashrc" "${HOME}/.bashrc"

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN debconf-set-selections /debconf_preseed.txt

# install 

# Preinstall packages
RUN apt-get update && apt-get install -y \
     apt-utils \
     autoconf \
     automake \
     bc \
     build-essential \
     cmake \
     ed \
     fonts-texgyre \
     git \
     gosu \
     libbz2-dev \
     libcurl4-openssl-dev \
#     libgit2-dev \
     libfindbin-libs-perl \
     libexpat1 \
     fonts-dejavu-core \
     fontconfig-config \
     libfontconfig1 \
     libfreetype6 \
     libpng16-16 \
     liblzma-dev \
     libncurses5 \
     libncurses5-dev \
     libssl-dev \
     libxml2-dev \
     locales \
     libtool \
     openjdk-8-jre \
     parallel \
     sudo \
     meson \
     ninja-build \
     nodejs \
     libvcflib-tools \
     util-linux \
     vim-tiny \
     curl \
     zlib1g-dev \
     make \
     gcc \
     perl \
     libssl-dev

# Install core python3 dependencies through pip
RUN python3 -m pip install -r ./py_pip3/requirements.txt

RUN ln -s /usr/local/src/plotcov3/plotcov3 /usr/local/bin/
RUN ln -s /usr/local/src/report_to_excel_v3/report_to_excel_v3 /usr/local/bin/

RUN bash -c "mkdir ./pangolin/build"
RUN bash -c "cd ./pangolin/build && git clone https://github.com/cov-lineages/pangolin.git"

RUN bash -c "python3 -m pip install -r ./pangolin/requirements.txt"
RUN bash -c "cd ./pangolin/build/pangolin && python setup.py install"

# Rstudio
# Add gomplate
ADD https://github.com/hairyhenderson/gomplate/releases/download/v3.9.0/gomplate_linux-amd64 /usr/bin/gomplate
RUN chmod a+x /usr/bin/gomplate

# provide read and write access to Rstudio users for default R library location
RUN chmod -R 777 /usr/local/lib/R/site-library

ENV PASSWORD "rstudio1"
RUN bash /etc/cont-init.d/userconf

COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

COPY nginx.conf.tmpl /nginx.conf.tmpl
COPY rserver.conf /etc/rstudio/rserver.conf
COPY supervisor-nginx.conf /etc/supervisor/conf.d/nginx.conf
COPY supervisor-rstudio.conf /etc/supervisor/conf.d/rstudio.conf

ENV REDIRECT_URL "http://localhost/"

ARG LOCAL_USER=rstudio
ARG PRIV_CMDS='/bin/ch*,/bin/cat,/bin/gunzip,/bin/tar,/bin/mkdir,/bin/ps,/bin/mv,/bin/cp,/usr/bin/apt*,/usr/bin/pip*,/bin/yum'

RUN if [ -x /usr/bin/apt ]; then \
      apt-get update && apt-get -y install sudo && rm -rf /var/lib/apt/lists/*; \
    elif [ -x /bin/yum ]; then \
      yum -y update && yum -y install sudo && yum clean all; \
    fi

RUN echo "$LOCAL_USER ALL=NOPASSWD: $PRIV_CMDS" >> /etc/sudoers

RUN echo 'export PS1="[\u@cyverse] \w $ "' >> /home/rstudio/.bash_profile

# install R-packages
RUN /usr/local/bin/Rscript -e "install.packages('tidyverse')"
RUN /usr/local/bin/Rscript -e "install.packages('openxlsx')"

USER rstudio

ENTRYPOINT ["/usr/local/bin/run.sh"]

WORKDIR /data
