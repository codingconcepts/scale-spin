output "alb_urls" {
  description = "Public ALB DNS names per region"
  value = {
    us_east_1      = "http://${aws_lb.alb_us.dns_name}"
    eu_west_2      = "http://${aws_lb.alb_eu.dns_name}"
    ap_southeast_1 = "http://${aws_lb.alb_ap.dns_name}"
  }
}