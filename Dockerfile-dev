FROM elixir:1.6

# Install dependencies
RUN apt-get update && \
    apt-get install --yes git curl inotify-tools

# Create app directory
ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
ENV MIX_ENV=prod

# Install hex package manager
RUN mix local.hex --force

# Install rebar
RUN mix local.rebar --force

# Install dependencies
ADD mix* $APP_HOME/
RUN mix deps.get
RUN mix deps.compile

# Copy working directory
ADD . $APP_HOME
