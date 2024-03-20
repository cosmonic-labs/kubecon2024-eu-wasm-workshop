FROM rust:1-slim-buster

RUN apt update && apt install -y curl pkg-config libssl-dev git

ENTRYPOINT ["/bin/bash"]
