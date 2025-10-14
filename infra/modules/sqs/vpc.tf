######
# US #
######

data "aws_availability_zones" "available_us" {
  state = "available"
}

resource "aws_vpc" "public_us" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "public_us" {
  vpc_id = aws_vpc.public_us.id

  tags = {
    Name = "${var.cluster_name_prefix}-igw"
  }
}

resource "aws_subnet" "public_us" {
  count                   = 3
  vpc_id                  = aws_vpc.public_us.id
  cidr_block              = "10.1.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available_us.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name_prefix}-public-subnet-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_route_table" "public_us" {
  vpc_id = aws_vpc.public_us.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_us.id
  }

  tags = {
    Name = "${var.cluster_name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public_us" {
  count          = 3
  subnet_id      = aws_subnet.public_us[count.index].id
  route_table_id = aws_route_table.public_us.id
}

######
# AP #
######

data "aws_availability_zones" "available_ap" {
  provider = aws.ap_southeast_1
  state    = "available"
}

resource "aws_vpc" "public_ap" {
  provider             = aws.ap_southeast_1
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "public_ap" {
  provider = aws.ap_southeast_1
  vpc_id   = aws_vpc.public_ap.id

  tags = {
    Name = "${var.cluster_name_prefix}-igw"
  }
}

resource "aws_subnet" "public_ap" {
  provider                = aws.ap_southeast_1
  count                   = 3
  vpc_id                  = aws_vpc.public_ap.id
  cidr_block              = "10.2.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available_ap.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name_prefix}-public-subnet-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_route_table" "public_ap" {
  provider = aws.ap_southeast_1
  vpc_id   = aws_vpc.public_ap.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_ap.id
  }

  tags = {
    Name = "${var.cluster_name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public_ap" {
  provider       = aws.ap_southeast_1
  count          = 3
  subnet_id      = aws_subnet.public_ap[count.index].id
  route_table_id = aws_route_table.public_ap.id
}

######
# EU #
######

data "aws_availability_zones" "available_eu" {
  provider = aws.eu_west_2
  state    = "available"
}

resource "aws_vpc" "public_eu" {
  provider             = aws.eu_west_2
  cidr_block           = "10.3.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "public_eu" {
  provider = aws.eu_west_2
  vpc_id   = aws_vpc.public_eu.id

  tags = {
    Name = "${var.cluster_name_prefix}-igw"
  }
}

resource "aws_subnet" "public_eu" {
  provider                = aws.eu_west_2
  count                   = 3
  vpc_id                  = aws_vpc.public_eu.id
  cidr_block              = "10.3.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available_eu.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name_prefix}-public-subnet-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_route_table" "public_eu" {
  provider = aws.eu_west_2
  vpc_id   = aws_vpc.public_eu.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_eu.id
  }

  tags = {
    Name = "${var.cluster_name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public_eu" {
  provider       = aws.eu_west_2
  count          = 3
  subnet_id      = aws_subnet.public_eu[count.index].id
  route_table_id = aws_route_table.public_eu.id
}
