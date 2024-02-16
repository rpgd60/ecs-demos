locals {
  name_prefix                 = "${var.project}-${var.environment}"
  account_id                  = data.aws_caller_identity.current.account_id
  ecs_task_execution_role_arn = "arn:aws:iam::${local.account_id}:role/ecsTaskExecutionRole"
  ecs_task_execution_role     = "ecsTaskExecutionRole"
  ecs_cluster_name            = "${local.name_prefix}"
  user_data_rendered = templatefile("${path.module}/ecs.sh.tpl",
    {
      ecs_cluster_name      = local.ecs_cluster_name
    }
  )
}