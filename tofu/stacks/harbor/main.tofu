resource "harbor_project" "library" {
  name                   = "library"
  public                 = false
  vulnerability_scanning = false
}

resource "harbor_project" "drova" {
  name                   = "drova"
  public                 = false
  vulnerability_scanning = false
  storage_quota          = 50
}

resource "harbor_immutable_tag_rule" "releases" {
  project_id    = harbor_project.drova.id
  repo_matching = "**"
  tag_matching  = "v*"
}

resource "harbor_garbage_collection" "weekly" {
  schedule        = "0 30 4 * * 0"
  delete_untagged = true
  workers         = 1
}

resource "harbor_robot_account" "ci" {
  name        = "ci"
  description = "drova GitHub Actions"
  level       = "project"

  permissions {
    kind      = "project"
    namespace = harbor_project.drova.name

    access {
      resource = "repository"
      action   = "push"
    }
    access {
      resource = "repository"
      action   = "pull"
    }
    access {
      resource = "artifact"
      action   = "read"
    }
    access {
      resource = "artifact"
      action   = "list"
    }
    access {
      resource = "tag"
      action   = "create"
    }
    access {
      resource = "tag"
      action   = "list"
    }
  }
}

resource "harbor_robot_account" "pull" {
  name        = "pull"
  description = "drova cluster pull"
  level       = "project"

  permissions {
    kind      = "project"
    namespace = harbor_project.drova.name

    access {
      resource = "repository"
      action   = "pull"
    }
    access {
      resource = "artifact"
      action   = "read"
    }
  }
}
