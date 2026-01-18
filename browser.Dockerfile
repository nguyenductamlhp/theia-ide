# Builder stage
FROM ubuntu:24.04 AS build-stage

RUN apt-get update
RUN apt-get upgrade -y

RUN mkdir -p /etc/sudoers.d && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu

# Combine all apt operations and clean up in one layer
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    python3-pip python3-dev python3-psycopg2 python3-ldap python3-psutil \
    git nano virtualenv gcc libxml2-dev libxslt1-dev libevent-dev libsasl2-dev \
    libldap2-dev libpq-dev libpng-dev libjpeg-dev node-less node-clean-css \
    xfonts-75dpi xfonts-base wget xz-utils nodejs npm vim openssh-client \
    lsb-base lsb-release curl ca-certificates gnupg libxkbfile-dev libsecret-1-dev \
    build-essential sudo fontconfig libjpeg-turbo8 libxrender1 wkhtmltopdf \
    lib32readline-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev \
    libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Git configuration
USER ubuntu
RUN git config --global alias.co checkout && \
    git config --global alias.br branch && \
    git config --global alias.ci commit && \
    git config --global alias.st status

# Switch back to root for installations
USER root

# Environment variables in Dockerfile (RUN export doesn't persist)
ENV VISUAL=vim \
    EDITOR=vim

# Install python 3.10.8
# Install multiple Python versions in parallel using WORKDIR
WORKDIR /tmp/python-builds

# Download all Python versions first (can be cached)
RUN wget -q https://www.python.org/ftp/python/3.10.8/Python-3.10.8.tgz && \
    tar xzf Python-3.10.8.tgz && \
    rm -f *.tgz

# Build Python 3.10.8
RUN cd Python-3.10.8 && \
    ./configure --enable-optimizations --with-ensurepip=install && \
    make altinstall && \
    cd ..  && rm -rf Python-3.10.8

# Install pew
RUN pip3 install pew pew[pythonz] --break-system-packages

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list

RUN apt-get update
RUN apt-get install -y postgresql-16 postgresql-client-16
RUN su - postgres -c "createuser -s ubuntu with password 'ubuntu'" 2> /dev/null || true
RUN service postgresql start && sudo -u postgres psql -d postgres -c "CREATE ROLE ubuntu SUPERUSER LOGIN REPLICATION CREATEDB CREATEROLE;"

# Install Node.js 22 and required build tools
RUN apt-get update \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup ubuntu home directory
RUN mkdir -p /home/ubuntu && \
    chown -R ubuntu:ubuntu /home/ubuntu && \
    chmod -R 755 /home/ubuntu
WORKDIR /home/ubuntu

# Copy repository files and set ownership
COPY --chown=ubuntu:ubuntu .  .

# Switch to ubuntu user for building
USER ubuntu

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
    rm -rf .git applications/electron ubuntu-extensions/launcher ubuntu-extensions/updater node_modules

# Production stage uses Ubuntu 24.04 base image
FROM ubuntu:24.04 AS production-stage

RUN apt-get update
RUN apt-get upgrade -y

# Create ubuntu user with password support
RUN chown -R ubuntu:ubuntu /home/ubuntu && \
    chmod -R 755 /home/ubuntu

RUN mkdir -p /etc/sudoers.d && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu

# Combine all apt operations and clean up in one layer
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    python3-pip python3-dev python3-psycopg2 python3-ldap python3-psutil \
    git nano virtualenv gcc libxml2-dev libxslt1-dev libevent-dev libsasl2-dev \
    libldap2-dev libpq-dev libpng-dev libjpeg-dev node-less node-clean-css \
    xfonts-75dpi xfonts-base wget xz-utils nodejs npm vim openssh-client \
    lsb-base lsb-release curl ca-certificates gnupg libxkbfile-dev libsecret-1-dev \
    build-essential sudo fontconfig libjpeg-turbo8 libxrender1 wkhtmltopdf \
    lib32readline-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev \
    libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Git configuration
USER ubuntu
RUN git config --global alias.co checkout && \
    git config --global alias.br branch && \
    git config --global alias.ci commit && \
    git config --global alias.st status

USER root

# Environment variables in Dockerfile (RUN export doesn't persist)
ENV VISUAL=vim \
    EDITOR=vim

# Install python 3.10.8
# Install multiple Python versions in parallel using WORKDIR
WORKDIR /tmp/python-builds

# Download all Python versions first (can be cached)
RUN wget -q https://www.python.org/ftp/python/3.10.8/Python-3.10.8.tgz && \
    tar xzf Python-3.10.8.tgz && \
    rm -f *.tgz

# Build Python 3.10.8
RUN cd Python-3.10.8 && \
    ./configure --enable-optimizations --with-ensurepip=install && \
    make altinstall && \
    cd ..  && rm -rf Python-3.10.8

# Install pew
RUN pip3 install pew pew[pythonz] --break-system-packages

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list

RUN apt-get update
RUN apt-get install -y postgresql-16 postgresql-client-16
RUN su - postgres -c "createuser -s ubuntu with password 'ubuntu'" 2> /dev/null || true
RUN service postgresql start && sudo -u postgres psql -d postgres -c "CREATE ROLE ubuntu SUPERUSER LOGIN REPLICATION CREATEDB CREATEROLE;"

# Install Node.js 22 (runtime only)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create ubuntu user and directories
# Application will be copied to /home/ubuntu
# Default workspace is located at /home/ubuntu/workspace
RUN mkdir -p /home/ubuntu/workspace && \
    chown -R ubuntu:ubuntu /home/ubuntu && \
    chmod -R 755 /home/ubuntu/workspace


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

# Create workspace directory with proper permissions
RUN mkdir -p /home/ubuntu/workspace && \
    chown -R ubuntu:ubuntu /home/ubuntu && \
    chmod -R 755 /home/ubuntu

ENV HOME=/home/ubuntu
WORKDIR /home/ubuntu

# Copy application from builder-stage
COPY --from=build-stage --chown=ubuntu:ubuntu /home/ubuntu /home/ubuntu

COPY --chown=root:root docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Ensure all permissions are correct after copy
RUN chown -R ubuntu:ubuntu /home/ubuntu && \
    chmod -R 755 /home/ubuntu

EXPOSE 3000

# Specify default shell for Theia and the Built-In plugins directory
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/ubuntu/plugins

# Use installed git instead of dugite
ENV USE_LOCAL_GIT=true

# Switch to Theia user
USER ubuntu
WORKDIR /home/ubuntu/applications/browser

# Launch the backend application via node
USER ubuntu
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh", "node", "/home/ubuntu/applications/browser/lib/backend/main.js"]

# Arguments passed to the application
CMD [ "/home/ubuntu/workspace", "--hostname=0.0.0.0" ]
