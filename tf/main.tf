
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "key_path" {}
variable "key_name" {}

variable "domain" {
  default = "asm.co"
}
variable "subdomain" {
  default = "blockway"
}
variable "volume_id" {}
variable "instance_type" {
  default = "m1.small"
}
variable "availability_zone" {
  default = "us-east-1c"
}

variable "rpcuser" {}
variable "rpcpassword" {}

variable "dnsimple_token" {}
variable "dnsimple_email" {}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "us-east-1"
}

provider "dnsimple" {
    token = "${var.dnsimple_token}"
    email = "${var.dnsimple_email}"
}

resource "aws_security_group" "ssh" {
  name = "ssh"
  description = "Allow SSH traffic"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssl" {
  name = "ssl"
  description = "Allow SSL"

  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bitcoind" {
  ami = "ami-4cb10524"
  availability_zone = "${var.availability_zone}"
  instance_type = "${var.instance_type}"
  security_groups = ["${aws_security_group.ssh.name}", "${aws_security_group.ssl.name}"]
  key_name = "${var.key_name}"

  connection {
    user = "core"
    key_file = "${var.key_path}"
  }

  # mount EBS
  provisioner "local-exec" {
    command = "aws ec2 attach-volume --volume-id=${var.volume_id} --instance-id=${aws_instance.bitcoind.id} --device=/dev/xvdf"
  }
  provisioner "remote-exec" {
    inline = [
      "while [ ! -e /dev/xvdf ]; do sleep 1; done",
      "sudo mkfs.ext4 /dev/xvdf",
      "sudo mkdir -pm 000 /vol",
      "echo '/dev/xvdf /vol auto noatime 0 0' | sudo tee -a /etc/fstab",
      "sudo mount /vol"
    ]
  }

  # mount ephemeral
  # user_data = "${file("cloud-init-mount-ephemeral.txt")}"

  provisioner "remote-exec" {
    inline = [
      "sudo useradd -p '*' -U -m bitcoin",
      "sudo mkdir -p /vol/.bitcoin",
      "sudo openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj '/C=US/ST=CA/L=San Francisco/O=Dis/CN=${var.domain}' -keyout /vol/.bitcoin/server.pem -out /vol/.bitcoin/server.cert",
      "sudo chown --recursive bitcoin /vol",
      "docker run --name=bitcoind-node --restart always -d -p 443:8332 -v /vol:/bitcoin kylemanna/bitcoind bitcoind -server -rpcuser=${var.rpcuser} -rpcpassword=${var.rpcpassword} -disablewallet -rpcssl -rpcallowip=* -txindex=1"
    ]
  }
}

resource "aws_eip" "ip" {
    instance = "${aws_instance.bitcoind.id}"
}

resource "dnsimple_record" "blockway" {
    domain = "${var.domain}"
    name = "${var.subdomain}"
    value = "${aws_eip.ip.public_ip}"
    type = "A"
    ttl = 60
}

# curl --insecure -X POST -d '{"jsonrpc": "1.0", "id":"curltest", "method": "getinfo", "params": [] }'
output "endpoint" {
  value = "https://${var.rpcuser}:${var.rpcpassword}@${var.subdomain}.${var.domain}"
}
