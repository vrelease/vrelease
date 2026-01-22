import mainimpl
import vr/meta
import vr/html
import vr/helpers
import vr/cli/parser
import vr/cli/logger
import vr/git/program
import vr/git/release


proc main () =
  let userInput = handleUserInput()

  let logger = getLogger(userInput.verbose, userInput.noColor)
  logger.debug("flag_verbose",         $userInput.verbose)
  logger.debug("flag_no_color",        $userInput.noColor)
  logger.debug("flag_add_checksum",    $userInput.addChecksum)
  logger.debug("flag_add_description", $userInput.addDescription)
  logger.debug("flag_pre_release",     $userInput.preRelease)
  logger.debug("flag_limit",           $userInput.limit)
  logger.debug("flag_attach",          $userInput.attacheables)

  displayStartMessage(userInput.noColor)
  checkForGit()

  # ---
  let git = newGitInterface()
  let authToken = checkAndGetAuthToken()
  let attacheables = processAttacheables(userInput.attacheables, userInput.addChecksum)

  # ---
  let remotes = git.getRemoteInfo()
  if len(remotes) == 0:
    logger.info("unable to create releases due to missing git remote; exiting early...")
    return

  # ---
  let tags = git.getTags()
  logger.debug("git_tags", $tags)
  logger.debug("git_tags_count", $len(tags))

  # ---
  let semverTags = filterSemver(tags)
  logger.debug("git_tags_semver", $semverTags)
  logger.debug("git_tags_semver_count", $len(semverTags))

  if len(semverTags) < 2:
    logger.info("unable to create a changelog due to insufficient tags; exiting early...")
    return

  # ---
  let tagFrom = semverTags[1]
  let tagTo   = semverTags[0]
  logger.info("generating changelog from $1 to $2", tagFrom, tagTo)

  # ---
  let commits = git.getCommits(tagFrom, tagTo)
  logger.debug("git_commits", $commits)
  logger.debug("git_commits_count", $len(commits))

  # ---
  remotes.foreach(
    proc (remote: GitRemote) =
      let opts = ReleaseBodyOptions(
        remote         : remote,
        commits        : commits,
        assets         : attacheables,
        commitLimit    : userInput.limit,
        addChecksum    : userInput.addChecksum,
        addDescription : userInput.addDescription,
      )

      let release = Release(
        remote     : remote,
        token      : authToken,
        body       : buildHTMLChangelog(opts),
        assets     : attacheables,
        preRelease : userInput.preRelease,
        tag        : tagTo,
      )

      release.create()
  )


when isMainModule:
  main()
