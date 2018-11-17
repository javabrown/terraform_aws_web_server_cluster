provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "all" {}


resource "aws_autoscaling_group" "rk-example1" {
  launch_configuration = "${aws_launch_configuration.rk-example1.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  
  min_size = 2
  max_size = 10
  
  load_balancers = ["${aws_elb.rk-example1.name}"]
  health_check_type = "ELB"
  
  tag {
     key = "Name"
	 value = "terraform_asg-rk-example1"
	 propagate_at_launch = true
  }
}

# -------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# -------------------------------------------------------------------------
resource "aws_launch_configuration" "rk-example1" {
  # Ubuntu Server 14.04 LTS (HVM), SSD Volume Type in us-east-1
  image_id = "ami-2d39803a"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "instance" {
  name = "terraform-rk-example1-instance"
  
  ingress {
    from_port = "${var.server_port}"
	to_port = "${var.server_port}"
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
  }
  
  lifecycle {
     create_before_destroy = true
  }
}


# ------------------------------------------------------------
# CREATE AN ELB TO ROUTE TRAFFIC ACROSS THE AUTO SCALING GROUP
# ------------------------------------------------------------

resource "aws_elb" "rk-example1" {
  name = "terraform-asg-rk-example1"
  security_groups = ["${aws_security_group.elb.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }

  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }
}


#-------------------------------------------------------------------------------
# CREATE A SECURITY GROUP THAT CONTROLS WHAT TRAFFIC AN GO IN AND OUT OF THE ELB
#-------------------------------------------------------------------------------

resource "aws_security_group" "elb" {
  name = "terraform-rk-example1-elb"

  # Allow all outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
