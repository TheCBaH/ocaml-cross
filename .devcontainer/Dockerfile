ARG OS_VER=bullseye
FROM debian:${OS_VER}
RUN set -eux;\
    apt-get update;\
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends\
  build-essential\
  ca-certificates\
  git\
  xz-utils\
;\
    apt-get clean; rm -rf /var/lib/apt/lists/*;\
    echo DONE
