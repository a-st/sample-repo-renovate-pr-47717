FROM docker.io/library/node:26-alpine AS base

ARG NPM_VERSION=12.0.1

RUN npm install --global "npm@${NPM_VERSION}" \
    && npm cache clean --force

###############################################################################

FROM base AS build

WORKDIR /build
RUN apk upgrade --no-cache \
    && apk add --no-cache git \
    && git clone https://github.com/a-st/renovate.git -b feat/dependency-dashboard-pin renovate \
    && cd renovate \
    && npx pnpm install \
    && npx pnpm build \
    && npx pnpm prune --prod

###############################################################################

FROM base AS final

ENV RENOVATE_X_IGNORE_RE2=true

COPY Containerfile /
COPY container-entrypoint.sh /
COPY container-entrypoint.d /container-entrypoint.d
COPY --from=build /build/renovate /usr/local/renovate

RUN apk upgrade --no-cache \
    && apk add --no-cache bash git \
    && chmod +x /container-entrypoint.sh /container-entrypoint.d/*.sh \
    && ln -sf /usr/local/renovate/dist/renovate.js /usr/local/bin/renovate \
    && ln -sf /usr/local/renovate/dist/config-validator.js /usr/local/bin/renovate-config-validator

# fix ENOGITREPO Not running from a git repository.
RUN git config --global --add safe.directory '*'

WORKDIR /data

ENV NODE_OPTIONS="--use-openssl-ca"

ENTRYPOINT [ "/container-entrypoint.sh" ]
CMD [ "--help" ]
