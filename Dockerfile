FROM ruby:3.3.8-alpine3.21 AS ruby-builder

RUN apk --no-cache add build-base cmake git glib-dev postgresql17-dev gcompat ragel yaml-dev

COPY lib/dtext_rb/ lib/dtext_rb/

RUN <<EOS
  cd lib/dtext_rb
  bin/install
EOS

COPY Gemfile Gemfile.lock ./
RUN gem i foreman && BUNDLE_IGNORE_CONFIG=true bundle install -j$(nproc)
RUN rm -rf /usr/local/bundle/cache/*.gem
RUN find /usr/local/bundle/gems/ -name "*.c" -delete
RUN find /usr/local/bundle/gems/ -name "*.o" -delete

FROM node:20-alpine3.21 AS node-builder
RUN apk --no-cache add git
WORKDIR /app
COPY package.json yarn.lock ./
RUN corepack enable && corepack prepare --activate && yarn install


FROM ruby:3.3.8-alpine3.21
RUN apk --no-cache add ffmpeg vips \
  postgresql17-client \
  git jemalloc tzdata \
  sudo xz gcompat

WORKDIR /app

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1

# Setup node and yarn
COPY --from=node-builder /usr/lib /usr/lib
COPY --from=node-builder /usr/local/share /usr/local/share
COPY --from=node-builder /usr/local/lib /usr/local/lib
COPY --from=node-builder /usr/local/include /usr/local/include
COPY --from=node-builder /usr/local/bin /usr/local/bin
# Copy yarn to both root and the user created below to support running as both
COPY --from=node-builder /root/.cache/node /root/.cache/node
COPY --from=node-builder /root/.cache/node /home/femboyfans/.cache/node

# Copy gems and js packages
COPY --from=node-builder /app/node_modules node_modules
COPY --from=ruby-builder /usr/local/bundle /usr/local/bundle

# Create a user with (potentially) the same id as on the host
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN addgroup --gid ${HOST_GID} femboyfans && \
  adduser -S --shell /bin/sh --uid ${HOST_UID} femboyfans && \
  addgroup femboyfans wheel && \
  echo "femboyfans ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Ignore warnings from git about .git permission differences when running as root
RUN git config --global --add safe.directory $(pwd)

CMD ["foreman", "start"]
