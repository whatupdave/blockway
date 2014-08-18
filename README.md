# Blockway

Deploy bitcoind to AWS.

We'll depend on python/boto until terraform supports EBS: https://github.com/hashicorp/terraform/issues/28

## Getting started

First, install python, pip and [http://www.terraform.io](http://www.terraform.io).

    $ pip install awscli
    $ aws configure

In AWS, create an EBS volume to hold the blockchain (At least 30GB), create an ssh key and download the pem file.

    $ cd tf
    $ cp terraform.tfvars.sample terraform.tfvars

Edit your terraform.tfvars appropriately.

    $ terraform plan
    $ terraform apply
