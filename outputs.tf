output "elb_dns_name" {
  value = "${aws_elb.rk-example1.dns_name}"
}