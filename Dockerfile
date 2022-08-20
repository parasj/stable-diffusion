FROM pytorch/pytorch:1.11.0-cuda11.3-cudnn8-runtime

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    sudo \
    && rm -rf /var/lib/apt/lists/*

COPY environment.yaml /install/environment.yaml
RUN conda env update -n base -f /install/environment.yaml

# Create a non-root user and switch to it
WORKDIR /app
RUN adduser --disabled-password --gecos '' --shell /bin/bash user \
 && chown -R user:user /app \
 && echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-user
USER user

# All users can use /home/user as their home directory
ENV HOME=/home/user
RUN chmod 777 /home/user

RUN chmod -R 777 /app
COPY --chown=user:user . /app

# fix volume permissions
RUN sudo chmod -R 777 /app && sudo chown -R user:user /app
RUN mkdir -p /home/user/.cache/
RUN chmod -R 777 /home/user && sudo chown -R user:user /home/user
RUN sudo mkdir -p /results && sudo chmod -R 777 /results && sudo chown -R user:user /results
VOLUME /home/user/.cache/
CMD "/bin/bash"