data "aws_lb" "this" {
  arn = var.nlb_arn
}

resource "aws_api_gateway_vpc_link" "this" {
  name        = "soat-vpc-link"
  description = "VPC Link for SOAT Tech Challenge"
  target_arns = [var.nlb_arn]
}
