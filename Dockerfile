FROM electronuserland/builder:16-wine as builder

WORKDIR /lens

ENV ELECTRON_BUILDER_EXTRA_ARGS=--win
ENV ELECTRON_CACHE="/root/.cache/electron"
ENV ELECTRON_BUILDER_CACHE="/root/.cache/electron-builder"

ENTRYPOINT ["make", "build"]