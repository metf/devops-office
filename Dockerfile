# Dockerfile pro DevOps/Cloud/SRE univerzální nástrojový kontejner s webovým terminálem gotty
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Prague

# Prerekvizity a základní balíčky
RUN apt-get update && \
    apt-get install -y \
    curl wget git unzip gnupg2 lsb-release \
    python3-pip python3-venv \
    nodejs npm \
    docker.io \
    netcat tcpdump dnsutils \
    make build-essential \
    zsh fonts-powerline \
    jq \
    software-properties-common \
    sudo \
    golang-go \
    ruby ruby-dev build-essential \
    openssh-client \
    locales \
    gss-ntlmssp \
    libicu70 \
    libssl3 \
    libc6 \
    libgcc1 \
    libgssapi-krb5-2 \
    liblttng-ust1 \
    libstdc++6 \
    zlib1g \
    && apt-get clean

# Oh My Zsh & pluginy
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting

# Oh My Zsh pluginy pro DevOps/Cloud
RUN git clone https://github.com/ohmyzsh/ohmyzsh.git /tmp/omz-tmp && \
    cp -r /tmp/omz-tmp/plugins/{docker,git,kubectl,terraform,aws,helm,ansible,vault,pip,python,npm,node,jenkins,gh,gcloud,azure} ~/.oh-my-zsh/plugins/ || true

# Nastavení zshrc (pluginy)
RUN rm -rf ~/.zshrc && touch ~/.zshrc && \
    echo "export ZSH=\"\$HOME/.oh-my-zsh\"" >> ~/.zshrc && \
    echo "ZSH_THEME=\"robbyrussell\"" >> ~/.zshrc && \
    echo "plugins=(docker git kubectl terraform aws helm ansible vault pip python npm node gh gcloud azure zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting)" >> ~/.zshrc && \
    echo "source \$ZSH/oh-my-zsh.sh" >> ~/.zshrc

# Programové nástroje
## AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

## Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

## Google Cloud CLI
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-471.0.0-linux-x86_64.tar.gz && \
    tar zxvf google-cloud-cli-471.0.0-linux-x86_64.tar.gz && \
    ./google-cloud-sdk/install.sh --quiet && \
    mv google-cloud-sdk /opt/ && \
    rm google-cloud-cli-471.0.0-linux-x86_64.tar.gz

## kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && mv kubectl /usr/local/bin/

## k9s
RUN curl -L https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar xz && \
    mv k9s /usr/local/bin/

## Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

## Kustomize
RUN curl -s "https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest" | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4 | wget -i - && \
    mv kustomize_*_linux_amd64 /usr/local/bin/kustomize && chmod +x /usr/local/bin/kustomize

## Terraform
RUN wget https://releases.hashicorp.com/terraform/1.8.4/terraform_1.8.4_linux_amd64.zip && unzip terraform_1.8.4_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && rm terraform_1.8.4_linux_amd64.zip

## Pulumi
RUN curl -fsSL https://get.pulumi.com | bash

## Ansible
RUN pip3 install ansible

## Packer
RUN wget https://releases.hashicorp.com/packer/1.10.2/packer_1.10.2_linux_amd64.zip && unzip packer_1.10.2_linux_amd64.zip && \
    mv packer /usr/local/bin/ && rm packer_1.10.2_linux_amd64.zip

## Argo CD CLI
RUN curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    chmod +x /usr/local/bin/argocd

## Tekton CLI
RUN wget https://github.com/tektoncd/cli/releases/latest/download/tkn_amd64.deb && \
    apt-get install -y ./tkn_amd64.deb && rm tkn_amd64.deb

## Prometheus promtool
RUN wget https://github.com/prometheus/prometheus/releases/latest/download/prometheus-*-amd64.tar.gz -O prometheus.tar.gz && \
    tar xzf prometheus.tar.gz && mv prometheus-*/promtool /usr/local/bin/ && rm -rf prometheus*

## Grafana CLI
RUN wget https://dl.grafana.com/oss/release/grafana-10.3.3.linux-amd64.tar.gz && \
    tar -xzf grafana-10.3.3.linux-amd64.tar.gz && \
    mv grafana-10.3.3/bin/grafana-cli /usr/local/bin/ && rm -rf grafana-10.3.3*

## Fluentd (gem)
RUN gem install fluentd

## HashiCorp Vault
RUN wget https://releases.hashicorp.com/vault/1.15.3/vault_1.15.3_linux_amd64.zip && \
    unzip vault_1.15.3_linux_amd64.zip && \
    mv vault /usr/local/bin/ && rm vault_1.15.3_linux_amd64.zip

## Trivy
RUN wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.51.3_Linux-64bit.tar.gz && \
    tar -xzf trivy_0.51.3_Linux-64bit.tar.gz && mv trivy /usr/local/bin/ && rm trivy_0.51.3_Linux-64bit.tar.gz

## OPA
RUN wget https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static && \
    mv opa_linux_amd64_static /usr/local/bin/opa && chmod +x /usr/local/bin/opa

## GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh

## Postman CLI (newman)
RUN npm install -g newman

## Gemini CLI, Qwen Code, Claude Code CLI, Aider
RUN npm install -g @qwen-code/qwen-code @google-gemini/gemini-cli && \
    pip3 install aider-cli

# aws-shell (alternativa)
RUN pip3 install aws-shell

# Set defaults for every important env variable
ENV GEMINI_API_KEY="" \
    QWEN_API_KEY="" \
    AWS_ACCESS_KEY_ID="" \
    AWS_SECRET_ACCESS_KEY="" \
    AWS_DEFAULT_REGION="" \
    AZURE_SUBSCRIPTION_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_SECRET="" \
    AZURE_TENANT="" \
    GOOGLE_APPLICATION_CREDENTIALS="" \
    VAULT_TOKEN="" \
    VAULT_ADDR="" \
    GITHUB_TOKEN="" \
    PULUMI_ACCESS_TOKEN="" \
    ARCODES_SERVER="" \
    OPA_POLICY_PATH=""

# Oprava PATH pro gcloud, pulumi, lint IDE
ENV PATH="$PATH:/opt/google-cloud-sdk/bin:$HOME/.pulumi/bin"

# Instalace gotty (webový terminál)
RUN go install github.com/yudai/gotty@latest

# Expose port pro gotty
EXPOSE 8765

# Vytvoření uživatele devops s home dir
RUN useradd -ms /bin/zsh devops && echo "devops ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER devops
WORKDIR /home/devops

# Překopírovat .zshrc do home pro uživatele devops
RUN cp /root/.zshrc /home/devops/.zshrc

# Spuštění gotty se zsh na portu 8765 bez autentizace, s možností zápisu
CMD ["gotty", "--port", "8765", "--permit-write", "--random-url=false", "--no-auth", "zsh"]

