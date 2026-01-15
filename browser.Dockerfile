# Builder stage
FROM ubuntu:24.04 AS build-stage

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

RUN mkdir -p /etc/sudoers.d && \
    echo "theia ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/theia && \
    chmod 0440 /etc/sudoers.d/theia

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