import ../attacheable
import ../helpers
import ../cli/logger
import ../git/program
import ../git/remote/github


type Release* = object
  remote     *: GitRemote
  token      *: string
  body       *: string
  assets     *: seq[Attacheable]
  preRelease *: bool
  tag        *: string


proc create* (rel: Release) =
  let logger = getLogger()

  case rel.remote.provider
  of GitProvider.GitHub:
    createGitHubRelease(rel.remote, rel.token, rel.tag, rel.body, rel.assets, rel.preRelease, logger)
  of GitProvider.GitLab:
    die("GitLab releases are not supported yet")
