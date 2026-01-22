import std/httpclient
import std/json
import std/uri
import std/strformat
import std/strutils
import std/os

import ../../attacheable
import ../../helpers
import ../../cli/logger
import ../program


const
  apiBaseUrl = "https://api.github.com"


proc isSuccess (code: HttpCode): bool =
  let n = code.int
  return n >= 200 and n < 300


proc parseErrorMessage (body: string): string =
  if body.len == 0:
    return ""

  try:
    let data = parseJson(body)
    if data.hasKey("message"):
      return data["message"].getStr()
  except:
    discard

  return ""


proc withHeaders (token: string, contentType: string): HttpHeaders =
  result = newHttpHeaders()
  result["Authorization"] = fmt"token {token}"
  result["User-Agent"] = "vrelease"
  result["Accept"] = "application/vnd.github+json"
  result["Content-Type"] = contentType


proc requestJson (client: HttpClient, verb: HttpMethod, url: string, token: string, payload: JsonNode): JsonNode =
  let body = $payload
  let headers = withHeaders(token, "application/json")
  let resp = client.request(url, httpMethod = verb, body = body, headers = headers)

  if not isSuccess(resp.code):
    let detail = parseErrorMessage(resp.body)
    let msg = if detail.len > 0: fmt"{resp.code} ({detail})" else: fmt"{resp.code}"
    die("GitHub API request failed: $1", msg)

  return if resp.body.len > 0: parseJson(resp.body) else: newJObject()


proc stripUploadTemplate (url: string): string =
  let idx = url.find("{")
  if idx < 0:
    return url

  return url[0 .. idx - 1]


proc uploadAsset (client: HttpClient, token: string, uploadUrl: string, asset: Attacheable, logger: Logger) =
  let filename = extractFilename(asset.filepath)
  let url = fmt"{uploadUrl}?name={encodeUrl(filename)}"
  let headers = withHeaders(token, "application/octet-stream")
  let content = readFile(asset.filepath)

  logger.info("uploading asset $1", filename)

  let resp = client.request(url, httpMethod = HttpPost, body = content, headers = headers)
  if not isSuccess(resp.code):
    let detail = parseErrorMessage(resp.body)
    let msg = if detail.len > 0: fmt"{resp.code} ({detail})" else: fmt"{resp.code}"
    die("GitHub API asset upload failed: $1", msg)


proc createGitHubRelease* (
  remote: GitRemote,
  token: string,
  tag: string,
  body: string,
  assets: seq[Attacheable],
  preRelease: bool,
  logger: Logger,
) =
  let owner = remote.username
  let repo = remote.repository

  logger.info("creating GitHub release for $1/$2 ($3)", owner, repo, tag)

  var client = newHttpClient()
  let url = fmt"{apiBaseUrl}/repos/{owner}/{repo}/releases"
  let payload = %* {
    "tag_name": tag,
    "name": tag,
    "body": body,
    "prerelease": preRelease,
    "draft": false,
  }

  let response = requestJson(client, HttpPost, url, token, payload)
  if not response.hasKey("upload_url"):
    die("GitHub API response missing upload_url")

  let uploadUrl = stripUploadTemplate(response["upload_url"].getStr())
  if uploadUrl.len == 0:
    die("GitHub API returned an empty upload_url")

  assets.foreach(
    proc (asset: Attacheable) =
      uploadAsset(client, token, uploadUrl, asset, logger)
  )
