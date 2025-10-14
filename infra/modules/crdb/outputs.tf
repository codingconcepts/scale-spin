output "global_lb" {
  sensitive = true
  value = format(
    "postgres://%s:%s@%s:26257?sslmode=verify-full",
    var.user,
    random_password.rob.result,
    replace(
      cockroach_cluster.standard.regions[0].sql_dns,
      "/aws-[[:word:]]+-[[:word:]]+-[[:word:]]./",
      ""
    )
  )
}
