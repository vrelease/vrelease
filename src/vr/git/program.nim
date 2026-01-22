import std/sequtils
import std/strutils
import std/strformat
import std/sugar

import ../helpers
import ../cli/logger


type
  GitProtocol = enum
    HTTP  = "HTTP",
    HTTPS = "HTTPS",
    SSH   = "SSH"

  GitProvider* = enum
    GitHub = "GitHub",
    GitLab = "GitLab"

type
  Git = object
    logger: Logger

  GitRemote* = object
    provider   *: GitProvider
    protocol   *: GitProtocol
    username   *: string
    repository *: string

  GitCommit* = object
    sha     *: string
    message *: string


proc malformedUrlErr () = die("Malformed git remote URL")


func tryToSplit (url: string, sep: string): (string, string) =
  if not url.contains(sep):
    malformedUrlErr()

  let segs = url.split(sep)
  if len(segs) != 2:
    malformedUrlErr()

  var t = segs.last()
  if t.endsWith(".git"):
    t = t.split(".git").first()

  return (segs.first(), t)


func identifyRemoteProtocol (url: string): GitProtocol =
  let u = url.toLower()

  if u.startsWith("http://"):
    return GitProtocol.HTTP

  if u.startsWith("https://"):
    return GitProtocol.HTTPS

  return GitProtocol.SSH


func identifyRemoteProvider (domain: string): GitProvider =
  let u = domain.toLower()

  if u == "github.com":
    return GitProvider.GitHub

  if u == "gitlab.com":
    return GitProvider.GitLab

  die(fmt"Unsupported provider '{domain}'")


func retrieveFromSshRemote (url: string): (string, string, string) =
  let (sshConn, afterProtocol) = url.tryToSplit(":")
  if not sshConn.contains("@"):
    malformedUrlErr()

  let domain = sshConn.split("@").last()
  let segs = afterProtocol.split("/")
  if len(segs) < 2:
    malformedUrlErr()

  let
    username   = segs[0]
    repository = segs.last()

  return (domain, username, repository)


func retrievefromHttpRemote (url: string): (string, string, string) =
  let (_, afterProtocol) = url.tryToSplit("://")
  let segs = afterProtocol.split("/")
  if len(segs) < 3:
    malformedUrlErr()

  let
    domain     = segs[0]
    username   = segs[1]
    repository = segs.last()

  return (domain, username, repository)


proc parseRemoteUrl (g: Git, i: int, url: string): GitRemote =
  let ns = (t: string) => fmt"git_remote_{t}_{i + 1}"
  g.logger.debug(ns("url"), url)

  if url.find(" ") >= 0:
    malformedUrlErr()

  let protocol = identifyRemoteProtocol(url)

  let (remoteDomain, username, repository) = (
    if protocol == GitProtocol.SSH: retrieveFromSshRemote(url)
    else: retrievefromHttpRemote(url)
  )

  let provider = identifyRemoteProvider(remoteDomain)
  g.logger.debug(ns("protocol"), fmt"{protocol}")
  g.logger.debug(ns("provider"), fmt"{provider}")
  g.logger.debug(ns("username"), username)
  g.logger.debug(ns("repository"), repository)

  if len(username) == 0 or len(repository) == 0:
    malformedUrlErr()

  return GitRemote(
    provider   : provider,
    protocol   : protocol,
    username   : username,
    repository : repository,
  )


proc getRemoteInfo* (g: Git): seq[GitRemote] =
  let (gitRemoteRaw, _) = execCmd("git remote get-url --all origin")
  let gitRemotes = gitRemoteRaw.splitClean()

  g.logger.info("found $1 remote(s) for this project", len(gitRemotes))

  if len(gitRemotes) == 0:
    return @[]

  return gitRemotes.mapC((i: int, url: string) => g.parseRemoteUrl(i, url))


proc getTags* (g: Git): seq[string] =
  let (gitTagsRaw, _) = execCmd("git tag --sort=-creatordate")
  return gitTagsRaw.splitClean()


proc getTagMessage* (g: Git, tag: string): string =
  let (raw, _) = execCmd(fmt"git log -1 --pretty=%B {tag}")
  return raw.strip()


proc getCommits* (g: Git, tagFrom: string, tagTo: string): seq[GitCommit] =
  let (gitCommitsRaw, _) = execCmd(fmt"git log --pretty=oneline {tagFrom}..{tagTo}")
  return gitCommitsRaw
    .splitClean()
    .map(
      func (commit: string): GitCommit =
        if len(commit) < 42:
          die("got malformed commit from 'git log': " & commit)

        let
          sha = commit[0 .. 39]
          msg = commit[41 .. len(commit) - 1]

        return GitCommit(sha : sha, message : msg)
    )


proc newGitInterface* (): Git = Git(logger : getLogger())
