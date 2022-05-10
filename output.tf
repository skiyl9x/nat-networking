output "vpc_public_sub" {
  value = aws_subnet.subnet_pb[*].id
}

output "vpc_private_subs" {
  value = aws_subnet.subnet_pv[*].id
}

output "vpc_private_sg_ids" {
  value = [aws_security_group.private.id]
}

output "vpc_public_sg_ids" {
  value = [aws_security_group.public.id]
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "pb_nic_id" {
  value = aws_network_interface.nic_pb[*].id
}

#output "pv_nic_id" {
#  value = aws_network_interface.nic_pv[*].id
#}

output "rt_pb_id" {
  value = aws_route_table.rt_pb.id
}

output "eip_ids" {
  value = aws_eip.nat[*].id
}