# Builder stage
FROM ubuntu:24.04 AS build-stage

RUN apt-get update
RUN apt-get upgrade -y

RUN mkdir -p /etc/sudoers.d && \
    echo "theia ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/theia && \
    chmod 0440 /etc/sudoers.d/theia

RUN apt-get install -y python3 python3-pip python3-dev python3-psycopg2 python3-ldap python3-psutil
RUN apt-get install -y git nano virtualenv gcc libxml2-dev libxslt1-dev libevent-dev libsasl2-dev libldap2-dev libpq-dev libpng-dev libjpeg-dev node-less node-clean-css xfonts-75dpi xfonts-base wget xz-utils nodejs npm vim openssh-client
RUN apt-get install -y lsb-base lsb-release

RUN git config --global alias.co checkout
RUN git config --global alias.br branch
RUN git config --global alias.ci commit
RUN git config --global alias.st status

RUN export VISUAL=vim
RUN export EDITOR="$VISUAL"
RUN echo $EDITOR
RUN . ~/.bashrc

# Install python 3.10.8, 3.11.8, 3.12.2
RUN apt update
RUN apt upgrade -y
RUN apt install -y wget build-essential lib32readline-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev

RUN cd ~
RUN wget https://www.python.org/ftp/python/3.10.8/Python-3.10.8.tgz
RUN tar xzf Python-3.10.8.tgz
RUN cd Python-3.10.8 && ./configure --enable-optimizations
RUN cd Python-3.10.8 && make altinstall

RUN cd ~
RUN wget https://www.python.org/ftp/python/3.11.8/Python-3.11.8.tgz
RUN tar xzf Python-3.11.8.tgz
RUN cd Python-3.11.8 && ./configure --enable-optimizations
RUN cd Python-3.11.8 && make altinstall

RUN cd ~
RUN wget https://www.python.org/ftp/python/3.12.2/Python-3.12.2.tgz
RUN tar xzf Python-3.12.2.tgz
RUN cd Python-3.12.2 && ./configure --enable-optimizations
RUN cd Python-3.12.2 && make altinstall


# Install pew
RUN pip3 install pew --break-system-packages
RUN pip3 install pew[pythonz] --break-system-packages

RUN apt install -y xfonts-base fontconfig libjpeg-turbo8 libxrender1 xfonts-75dpi
RUN apt install wkhtmltopdf -y

RUN apt install sudo -y

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list

RUN apt-get update
RUN apt-get install -y postgresql-16 postgresql-client-16
RUN su - postgres -c "createuser -s abc with password 'abc'" 2> /dev/null || true
RUN service postgresql start && sudo -u postgres psql -d postgres -c "CREATE ROLE abc SUPERUSER LOGIN REPLICATION CREATEDB CREATEROLE;"

# Install Node.js 22 and required build tools
RUN apt-get update && apt-get install -y \
    curl \
    sudo \
    ca-certificates \
    gnupg \
    libxkbfile-dev \
    libsecret-1-dev \
    build-essential \
    git \
    python3 \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/theia

# Copy repository files
COPY .  .

# Remove unnecessary files for the browser application
# Download plugins and build application production mode
# Use yarn autoclean to remove unnecessary files from package dependencies
ENV NODE_OPTIONS=--max-old-space-size=4096
RUN yarn config set network-timeout 600000 -g && \
    yarn --pure-lockfile && \
    yarn build:extensions && \
    yarn download:plugins && \
    yarn browser build && \
    yarn && \
    yarn autoclean --init && \
    echo *.ts >> .yarnclean && \
    echo *.ts.map >> .yarnclean && \
    echo *.spec.* >> .yarnclean && \
    yarn autoclean --force && \
    yarn cache clean && \
    rm -rf .git applications/electron theia-extensions/launcher theia-extensions/updater node_modules

# Production stage uses Ubuntu 24.04 base image
FROM ubuntu:24.04 AS production-stage

RUN apt-get update
RUN apt-get upgrade -y

RUN mkdir -p /etc/sudoers.d && \
    echo "theia ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/theia && \
    chmod 0440 /etc/sudoers.d/theia

RUN apt-get install -y python3 python3-pip python3-dev python3-psycopg2 python3-ldap python3-psutil
RUN apt-get install -y git nano virtualenv gcc libxml2-dev libxslt1-dev libevent-dev libsasl2-dev libldap2-dev libpq-dev libpng-dev libjpeg-dev node-less node-clean-css xfonts-75dpi xfonts-base wget xz-utils nodejs npm vim openssh-client
RUN apt-get install -y lsb-base lsb-release

RUN git config --global alias.co checkout
RUN git config --global alias.br branch
RUN git config --global alias.ci commit
RUN git config --global alias.st status

RUN export VISUAL=vim
RUN export EDITOR="$VISUAL"
RUN echo $EDITOR
RUN . ~/.bashrc

# Install python 3.10.8, 3.11.8, 3.12.2
RUN apt update
RUN apt upgrade -y
RUN apt install -y wget build-essential lib32readline-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev

RUN cd ~
RUN wget https://www.python.org/ftp/python/3.10.8/Python-3.10.8.tgz
RUN tar xzf Python-3.10.8.tgz
RUN cd Python-3.10.8 && ./configure --enable-optimizations
RUN cd Python-3.10.8 && make altinstall

RUN cd ~
RUN wget https://www.python.org/ftp/python/3.11.8/Python-3.11.8.tgz
RUN tar xzf Python-3.11.8.tgz
RUN cd Python-3.11.8 && ./configure --enable-optimizations
RUN cd Python-3.11.8 && make altinstall

RUN cd ~
RUN wget https://www.python.org/ftp/python/3.12.2/Python-3.12.2.tgz
RUN tar xzf Python-3.12.2.tgz
RUN cd Python-3.12.2 && ./configure --enable-optimizations
RUN cd Python-3.12.2 && make altinstall


# Install pew
RUN pip3 install pew --break-system-packages
RUN pip3 install pew[pythonz] --break-system-packages

RUN apt install -y xfonts-base fontconfig libjpeg-turbo8 libxrender1 xfonts-75dpi
RUN apt install wkhtmltopdf -y

RUN apt install sudo -y

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list

RUN apt-get update
RUN apt-get install -y postgresql-16 postgresql-client-16
RUN su - postgres -c "createuser -s abc with password 'abc'" 2> /dev/null || true
RUN service postgresql start && sudo -u postgres psql -d postgres -c "CREATE ROLE abc SUPERUSER LOGIN REPLICATION CREATEDB CREATEROLE;"

# Install Node.js 22 (runtime only)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    sudo \
    git \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create theia user and directories
# Application will be copied to /home/theia
# Default workspace is located at /home/theia/workspace
RUN adduser --system --group theia
RUN chmod g+rw /home && \
    mkdir -p /home/theia/workspace && \
    chown -R theia:theia /home/theia && \
    chown -R theia:theia /home/theia/workspace

# Install required tools for application:  OpenJDK 17, Git, SSH, Bash, Maven
RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    openssh-server \
    bash \
    libsecret-1-0 \
    openjdk-17-jdk \
    maven \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV HOME=/home/theia
WORKDIR /home/theia

# Copy application from builder-stage
COPY --from=build-stage --chown=theia:theia /home/theia /home/theia

EXPOSE 3000

# Specify default shell for Theia and the Built-In plugins directory
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/theia/plugins

# Use installed git instead of dugite
ENV USE_LOCAL_GIT=true

# Switch to Theia user
USER theia
WORKDIR /home/theia/applications/browser

# Launch the backend application via node
ENTRYPOINT [ "node", "/home/theia/applications/browser/lib/backend/main.js" ]

# Arguments passed to the application
CMD [ "/home/theia/workspace", "--hostname=0.0.0.0" ]
