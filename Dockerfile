# Dockerfile pro DevOps/Cloud/SRE univerzální nástrojový kontejner s webovým terminálem gotty
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Prague

# Verze nástrojů
ARG TERRAFORM_VERSION="1.8.4"
ARG PACKER_VERSION="1.10.2"
ARG VAULT_VERSION="1.15.3"
ARG TRIVY_VERSION="0.51.3"
ARG OPENTOFU_VERSION="1.7.2"
ARG EKSCTL_VERSION="0.177.0"
ARG GLAB_VERSION="1.41.0"
ARG SOPS_VERSION="3.8.1"
ARG GITLEAKS_VERSION="8.18.4"
ARG GRPCURL_VERSION="1.9.1"

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
    # Nové balíčky pro produktivitu a databáze
    postgresql-client mysql-client \
    httpie bat fd-find ripgrep \
    && apt-get clean

# Vytvoření symlinků pro bat a fd, aby byly dostupné pod krátkými názvy
RUN ln -s /usr/bin/batcat /usr/local/bin/bat && \
    ln -s /usr/bin/fdfind /usr/local/bin/fd

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
    echo "export ZSH=\"$HOME/.oh-my-zsh\"" >> ~/.zshrc && \
    echo "ZSH_THEME=\"robbyrussell\"" >> ~/.zshrc && \
    echo "plugins=(docker git kubectl terraform aws helm ansible vault pip python npm node gh gcloud azure zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting)" >> ~/.zshrc && \
    echo "source $ZSH/oh-my-zsh.sh" >> ~/.zshrc

# Python nástroje (včetně nového checkov)
RUN pip3 install ansible checkov aws-shell aider-cli

# Node.js nástroje (včetně nového fx a newman)
RUN npm install -g newman @qwen-code/qwen-code @google-gemini/gemini-cli fx

# Go nástroje (včetně nového lazygit a lazydocker)
RUN go install github.com/yudai/gotty@latest && \
    go install github.com/jesseduffield/lazydocker@latest && \
    go install github.com/jesseduffield/lazygit@latest

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
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

## Pulumi
RUN curl -fsSL https://get.pulumi.com | bash

## Packer
RUN wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip && unzip packer_${PACKER_VERSION}_linux_amd64.zip && \
    mv packer /usr/local/bin/ && rm packer_${PACKER_VERSION}_linux_amd64.zip

## Argo CD CLI
RUN curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    chmod +x /usr/local/bin/argocd

## Tekton CLI
RUN wget https://github.com/tektoncd/cli/releases/latest/download/tkn_amd64.deb && \
    apt-get install -y ./tkn_amd64.deb && rm tkn_amd64.deb

## Prometheus promtool
RUN wget https://github.com/prometheus/prometheus/releases/latest/download/prometheus-*-amd64.tar.gz -O prometheus.tar.gz && \
    tar xzf prometheus.tar.gz && mv prometheus-*/promtool /usr/local/bin/ && rm -rf prometheus*

## HashiCorp Vault
RUN wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && \
    unzip vault_${VAULT_VERSION}_linux_amd64.zip && \
    mv vault /usr/local/bin/ && rm vault_${VAULT_VERSION}_linux_amd64.zip

## Trivy
RUN wget https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz && \
    tar -xzf trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz && mv trivy /usr/local/bin/ && rm trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz

## OPA
RUN wget https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static && \
    mv opa_linux_amd64_static /usr/local/bin/opa && chmod +x /usr/local/bin/opa

## GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh

## OpenTofu
RUN wget https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.zip && \
    unzip tofu_${OPENTOFU_VERSION}_linux_amd64.zip -d /usr/local/bin && \
    rm tofu_${OPENTOFU_VERSION}_linux_amd64.zip

## eksctl
RUN curl -sL "https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin

## GitLab CLI (glab)
RUN curl -sL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_Linux_x86_64.tar.gz" | tar xz -C /tmp && \
    mv /tmp/bin/glab /usr/local/bin/glab && \
    rm -rf /tmp/bin

# --- Nová sada nástrojů ---
## k3d
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

## kubectx / kubens
RUN curl -L https://github.com/ahmetb/kubectx/releases/latest/download/kubectx -o /usr/local/bin/kubectx && \
    curl -L https://github.com/ahmetb/kubectx/releases/latest/download/kubens -o /usr/local/bin/kubens && \
    chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens

## sops
RUN wget https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64 -O /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops

## gitleaks
RUN wget https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz && \
    tar -xzf gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz && \
    mv gitleaks /usr/local/bin/ && \
    rm gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz

## grpcurl
RUN wget https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/grpcurl_${GRPCURL_VERSION}_linux_x86_64.tar.gz && \
    tar -xzf grpcurl_${GRPCURL_VERSION}_linux_x86_64.tar.gz && \
    mv grpcurl /usr/local/bin/ && \
    rm grpcurl_${GRPCURL_VERSION}_linux_x86_64.tar.gz

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

