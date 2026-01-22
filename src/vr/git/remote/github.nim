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
  apiVersion = "2022-11-28"


type JsonResponse = object
  code: HttpCode
  body: string
  json: JsonNode


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


proc parseErrorDetails (data: JsonNode): string =
  var parts: seq[string] = @[]

  if data.kind == JObject and data.hasKey("message"):
    parts.add(data["message"].getStr())

  if data.kind == JObject and data.hasKey("errors") and data["errors"].kind == JArray:
    for err in data["errors"]:
      if err.kind != JObject:
        continue
      if err.hasKey("message"):
        parts.add(err["message"].getStr())
      elif err.hasKey("code"):
        parts.add(err["code"].getStr())

  return parts.join("; ")


proc formatError (res: JsonResponse): string =
  let detail = if res.json.kind != JNull: parseErrorDetails(res.json) else: parseErrorMessage(res.body)
  return if detail.len > 0: fmt"{res.code} ({detail})" else: fmt"{res.code}"


proc withHeaders (token: string, contentType: string): HttpHeaders =
  result = newHttpHeaders()
  result["Authorization"] = fmt"Bearer {token}"
  result["User-Agent"] = "vrelease"
  result["Accept"] = "application/vnd.github+json"
  result["X-GitHub-Api-Version"] = apiVersion
  result["Content-Type"] = contentType


proc requestJson (client: HttpClient, verb: HttpMethod, url: string, token: string, payload: JsonNode = nil): JsonResponse =
  var body = ""
  if payload != nil:
    body = $payload

  let headers = withHeaders(token, "application/json")
  let resp = client.request(url, httpMethod = verb, body = body, headers = headers)
  var parsed = newJNull()

  if resp.body.len > 0:
    try:
      parsed = parseJson(resp.body)
    except:
      discard

  return JsonResponse(code: resp.code, body: resp.body, json: parsed)


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


proc listAssets (client: HttpClient, token: string, owner: string, repo: string, releaseId: int): seq[(int, string)] =
  let url = fmt"{apiBaseUrl}/repos/{owner}/{repo}/releases/{releaseId}/assets"
  let res = requestJson(client, HttpGet, url, token)

  if not isSuccess(res.code):
    die("GitHub API request failed: $1", formatError(res))

  if res.json.kind != JArray:
    return @[]

  for item in res.json:
    if item.kind != JObject:
      continue
    if not item.hasKey("id") or not item.hasKey("name"):
      continue

    result.add((item["id"].getInt(), item["name"].getStr()))


proc deleteAsset (client: HttpClient, token: string, owner: string, repo: string, assetId: int) =
  let url = fmt"{apiBaseUrl}/repos/{owner}/{repo}/releases/assets/{assetId}"
  let res = requestJson(client, HttpDelete, url, token)

  if not isSuccess(res.code):
    die("GitHub API asset delete failed: $1", formatError(res))


proc ensureRelease (client: HttpClient, token: string, owner: string, repo: string, tag: string, body: string, preRelease: bool, logger: Logger): JsonNode =
  let createUrl = fmt"{apiBaseUrl}/repos/{owner}/{repo}/releases"
  let payload = %* {
    "tag_name": tag,
    "name": tag,
    "body": body,
    "prerelease": preRelease,
    "draft": false,
  }

  let created = requestJson(client, HttpPost, createUrl, token, payload)
  if isSuccess(created.code):
    return created.json

  if created.code != Http422:
    die("GitHub API request failed: $1", formatError(created))

  let existingUrl = fmt"{apiBaseUrl}/repos/{owner}/{repo}/releases/tags/{tag}"
  let existing = requestJson(client, HttpGet, existingUrl, token)
  if existing.code != Http200 or not existing.json.hasKey("id"):
    die("GitHub API request failed: $1", formatError(existing))

  let releaseId = existing.json["id"].getInt()
  logger.info("release already exists, updating it")

  let updateUrl = fmt"{apiBaseUrl}/repos/{owner}/{repo}/releases/{releaseId}"
  let updated = requestJson(client, HttpPatch, updateUrl, token, payload)

  if not isSuccess(updated.code):
    die("GitHub API request failed: $1", formatError(updated))

  return updated.json


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
  let response = ensureRelease(client, token, owner, repo, tag, body, preRelease, logger)
  if not response.hasKey("upload_url"):
    die("GitHub API response missing upload_url")

  let uploadUrl = stripUploadTemplate(response["upload_url"].getStr())
  if uploadUrl.len == 0:
    die("GitHub API returned an empty upload_url")

  if assets.len == 0:
    return

  if not response.hasKey("id"):
    die("GitHub API response missing release id")

  let releaseId = response["id"].getInt()
  let existingAssets = listAssets(client, token, owner, repo, releaseId)

  for asset in assets:
    let name = extractFilename(asset.filepath)
    for (assetId, assetName) in existingAssets:
      if assetName == name:
        logger.info("deleting existing asset $1", name)
        deleteAsset(client, token, owner, repo, assetId)

    uploadAsset(client, token, uploadUrl, asset, logger)
