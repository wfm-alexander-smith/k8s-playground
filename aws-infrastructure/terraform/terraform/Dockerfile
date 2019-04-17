# Dependency Image
FROM golang:1 as deps

RUN apt-get update && apt-get install -y --no-install-recommends unzip && rm -rf /var/lib/apt/lists/*

# Build Golang deps
RUN go get \
    github.com/gruntwork-io/terragrunt \
    github.com/ericchiang/terraform-provider-k8s
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' \
    github.com/gruntwork-io/terragrunt \
    github.com/ericchiang/terraform-provider-k8s

# Get precompiled deps
RUN wget -nv -P /bin \
    https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/bin/linux/amd64/kubectl \
    https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/bin/linux/amd64/aws-iam-authenticator
RUN wget -nv -P /tmp \
    https://releases.hashicorp.com/terraform-provider-aws/1.51.0/terraform-provider-aws_1.51.0_linux_amd64.zip \
    https://releases.hashicorp.com/terraform-provider-external/1.0.0/terraform-provider-external_1.0.0_linux_amd64.zip \
    https://releases.hashicorp.com/terraform-provider-kubernetes/1.5.1/terraform-provider-kubernetes_1.5.1_linux_amd64.zip \
    https://releases.hashicorp.com/terraform-provider-null/1.0.0/terraform-provider-null_1.0.0_linux_amd64.zip \
    https://releases.hashicorp.com/terraform-provider-postgresql/0.1.2/terraform-provider-postgresql_0.1.2_linux_amd64.zip \
    https://releases.hashicorp.com/terraform-provider-random/2.0.0/terraform-provider-random_2.0.0_linux_amd64.zip \
    https://releases.hashicorp.com/terraform-provider-template/1.0.0/terraform-provider-template_1.0.0_linux_amd64.zip \
    https://releases.hashicorp.com/terraform-provider-tls/1.2.0/terraform-provider-tls_1.2.0_linux_amd64.zip \
    https://releases.hashicorp.com/terraform-provider-helm/0.7.0/terraform-provider-helm_0.7.0_linux_amd64.zip \
    https://storage.googleapis.com/kubernetes-helm/helm-v2.10.0-linux-amd64.tar.gz
RUN unzip -d /bin '/tmp/terraform-provider-*.zip'
RUN tar -C /bin -xvf /tmp/helm-*.tar.gz

# Ensure all the various downloaded binaries are marked executable
RUN chmod +x /bin/*


# Run image
FROM alpine:latest

RUN apk add --no-cache --update bash ca-certificates libc6-compat postgresql-client openssl coreutils
RUN mkdir /terraform-plugins && chmod +x /terraform-plugins

# Copy in all the needed executables
COPY --from=hashicorp/terraform:0.11.7 /bin/terraform /bin/
COPY --from=deps /go/bin/terragrunt /bin/
COPY --from=stedolan/jq /usr/local/bin/jq /bin/
COPY --from=deps /bin/kubectl /bin/
COPY --from=deps /bin/aws-iam-authenticator /bin/
COPY --from=deps /bin/linux-amd64/helm /bin/
COPY --from=deps /go/bin/terraform-provider-k8s /terraform-plugins/
COPY --from=deps /bin/terraform-provider-* /terraform-plugins/

RUN chmod +r /terraform-plugins/*

# Tell Terraform to only use plugins in /terraform-plugins directory.
ENV TF_CLI_ARGS_init="-plugin-dir=/terraform-plugins"

WORKDIR /tf
ENV HOME=/tf

ENTRYPOINT ["/bin/sh"]
