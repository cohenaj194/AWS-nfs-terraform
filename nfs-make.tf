provider "aws" {
  # these are declared in a separate var.tf file
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.region}"
}

variable "keypair" {
  default="/home/ubuntu/.ssh/id_rsa.pub"
}

#uploads the key pair if it doesnt already exist as terra
resource "aws_key_pair" "deployer" {
  key_name = "terra" 
  public_key = "${file(var.keypair)}"
}

resource "aws_instance" "nfs-server" {
	ami = "ami-2d39803a"
	instance_type = "t2.micro"
	key_name = "terra"
	tags {
	  Name = "nfs-server"
	}

  connection {
    user = "ubuntu"
    private_key="${file("/home/ubuntu/.ssh/id_rsa")}"
    agent = false
    timeout = "3m"
  } 

  provisioner "remote-exec" {
    inline = [<<EOF

      sudo apt-get update
      echo "gotta sleep for some reason" && sleep 5
      sudo apt-get update
      sudo apt-get install -y nfs-kernel-server
      sudo mkdir -p /export/files
      sudo chmod 777 /etc/exports /etc/hosts.allow /export/files
      echo "/export/files *(rw,no_root_squash)" >>  /etc/exports
      echo "rspbind = ALL
      portmap = ALL
      nfs = ALL" >> /etc/hosts.allow
      sudo chmod 755 /etc/exports /etc/hosts.allow
      sudo /etc/init.d/nfs-kernel-server restart
      sudo showmount -e
      echo "hi there this is the server $(hostname)" > /export/files/test.txt
      
    EOF
    ]
  }

}

resource "aws_instance" "nfs-client" {
  count = 2
  ami = "ami-2d39803a"
  instance_type = "t2.micro"
  key_name = "terra"
  tags {
    Name = "nfs-client"
  }

  connection {
    user = "ubuntu"
    private_key="${file("/home/ubuntu/.ssh/id_rsa")}"
    agent = false
    timeout = "3m"
  } 

  provisioner "remote-exec" {
    inline = [<<EOF

      sudo apt-get update
      echo "gotta sleep for some reason" && sleep 5
      sudo apt-get update
      sudo apt-get install -y nfs-common
      sudo mkdir -p /export/files
      sudo chmod 777 /export/files
      sudo mount ${aws_instance.nfs-server.private_ip}:/export/files /export/files 
      echo "this is $(hostname)" >> /export/files/test.txt
      
    EOF
    ]
  }

}