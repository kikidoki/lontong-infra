# 0001: one directory (and one state) per environment
Workspaces and tfvars-switching make "applied staging config to production" a one-word mistake. Here the blast radius is the
directory you are standing in: each environment has its own state key, its own CI role and its own values, composed from the same modules.
Moving production to its own AWS account later only changes `environments/production/backend.tf` plus a new bootstrap.
