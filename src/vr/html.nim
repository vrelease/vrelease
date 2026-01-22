import std/os
import std/strformat
import std/strutils

import attacheable
import git/program


type ReleaseBodyOptions* = object
  remote         *: GitRemote
  commits        *: seq[GitCommit]
  assets         *: seq[Attacheable]
  commitLimit    *: int
  addChecksum    *: bool
  addDescription *: bool
  tagMessage     *: string


proc escapeHtml (t: string): string =
  result = t
  result = result.replace("&", "&amp;")
  result = result.replace("<", "&lt;")
  result = result.replace(">", "&gt;")
  result = result.replace("\"", "&quot;")
  result = result.replace("'", "&#39;")


proc limitCommits (commits: seq[GitCommit], limit: int): seq[GitCommit] =
  if limit <= 0 or limit >= len(commits):
    return commits

  return commits[0 ..< limit]


proc commitUrl (remote: GitRemote, sha: string): string =
  case remote.provider
  of GitProvider.GitHub:
    return fmt"https://github.com/{remote.username}/{remote.repository}/commit/{sha}"
  of GitProvider.GitLab:
    return fmt"https://gitlab.com/{remote.username}/{remote.repository}/-/commit/{sha}"


proc buildHTMLChangelog* (opts: ReleaseBodyOptions): string =
  var body = ""

  if opts.addDescription and opts.tagMessage.strip().len > 0:
    let desc = escapeHtml(opts.tagMessage.strip()).replace("\n", "<br/>")
    body &= "<h1>Description</h1>"
    body &= "<p>" & desc & "</p>"

  let commits = limitCommits(opts.commits, opts.commitLimit)
  if len(commits) > 0:
    body &= "<h1>Changelog</h1><ul>"

    for commit in commits:
      let shortSha = if commit.sha.len >= 7: commit.sha[0 .. 6] else: commit.sha
      let url = commitUrl(opts.remote, commit.sha)
      let msg = escapeHtml(commit.message)
      body &= fmt"<li><a href='{url}'><code>{shortSha}</code></a> {msg}</li>"

    body &= "</ul>"

  if opts.addChecksum and len(opts.assets) > 0:
    body &= "<h1>Checksum (SHA256)</h1><ul>"

    for asset in opts.assets:
      let name = escapeHtml(asset.filepath.extractFilename())
      let hash = escapeHtml(asset.hash)
      body &= fmt"<li>{name} (<code>{hash}</code>)</li>"

    body &= "</ul>"

  return body
