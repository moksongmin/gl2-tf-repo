resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "_%@"
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.name}/rds/master"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.master.result
    engine   = var.engine
    host     = aws_db_instance.this.address
    port     = var.port
    dbname   = var.db_name
  })
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Database access from ECS and bastion"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = toset(var.allowed_security_group_ids)

    content {
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.bastion_security_group_id == null ? [] : [var.bastion_security_group_id]

    content {
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-db-sg"
  })
}

resource "aws_db_instance" "this" {
  identifier                      = "${var.name}-rds"
  db_name                         = var.engine == "sqlserver-se" ? null : var.db_name
  instance_class                  = var.instance_class
  allocated_storage               = var.allocated_storage
  max_allocated_storage           = var.max_allocated_storage
  storage_type                    = "gp3"
  engine                          = var.engine
  engine_version                  = var.engine_version
  username                        = var.username
  password                        = random_password.master.result
  port                            = var.port
  multi_az                        = var.multi_az
  db_subnet_group_name            = var.db_subnet_group_name
  vpc_security_group_ids          = [aws_security_group.db.id]
  backup_retention_period         = var.backup_retention_period
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${var.name}-final-snapshot"
  performance_insights_enabled    = var.performance_insights_enabled
  enabled_cloudwatch_logs_exports = var.engine == "sqlserver-se" ? ["agent", "error"] : []
  auto_minor_version_upgrade      = true
  apply_immediately               = false
  publicly_accessible             = false
  copy_tags_to_snapshot           = true
  manage_master_user_password     = false
  backup_window                   = "02:00-03:00"
  maintenance_window              = "sun:03:00-sun:04:00"

  tags = merge(var.tags, {
    Name = "${var.name}-rds"
  })
}
