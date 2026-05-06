param(
  [int]$Port = 0
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PublicDir = Join-Path $Root "public"
$DataDir = Join-Path $Root "data"
$DataFile = Join-Path $DataDir "punishments.json"

function Import-DotEnv {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
    $trimmed = $line.Trim()

    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
      continue
    }

    $separator = $trimmed.IndexOf("=")
    if ($separator -lt 1) {
      continue
    }

    $key = $trimmed.Substring(0, $separator).Trim()
    $value = $trimmed.Substring($separator + 1).Trim().Trim("'", '"')

    if (-not [Environment]::GetEnvironmentVariable($key, "Process")) {
      [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
  }
}

function New-HttpError {
  param(
    [int]$StatusCode,
    [string]$Message
  )

  $error = [System.Exception]::new($Message)
  $error.Data["StatusCode"] = $StatusCode
  return $error
}

function Ensure-Store {
  if (-not (Test-Path -LiteralPath $DataDir)) {
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
  }

  if (-not (Test-Path -LiteralPath $DataFile)) {
    Set-Content -LiteralPath $DataFile -Encoding UTF8 -Value "[]"
  }
}

function Read-Punishments {
  Ensure-Store
  $raw = Get-Content -LiteralPath $DataFile -Raw -Encoding UTF8

  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }

  $items = $raw | ConvertFrom-Json
  if ($null -eq $items) {
    return @()
  }

  return @($items)
}

function Write-Punishments {
  param([array]$Items)

  Ensure-Store
  $json = ConvertTo-Json -InputObject @($Items) -Depth 10
  if ([string]::IsNullOrWhiteSpace($json)) {
    $json = "[]"
  }

  Set-Content -LiteralPath $DataFile -Encoding UTF8 -Value $json
}

function Get-BodyJson {
  param($Request)

  $reader = [System.IO.StreamReader]::new($Request.InputStream, [System.Text.Encoding]::UTF8)
  $body = $reader.ReadToEnd()

  if ([string]::IsNullOrWhiteSpace($body)) {
    return [pscustomobject]@{}
  }

  try {
    return $body | ConvertFrom-Json
  } catch {
    throw (New-HttpError 400 "Некорректный JSON.")
  }
}

function Get-TextValue {
  param(
    $Object,
    [string]$Name,
    [string]$Default = ""
  )

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property -or $null -eq $property.Value) {
    return $Default
  }

  return ([string]$property.Value).Trim()
}

function Get-CleanPunishment {
  param($InputObject)

  $punishment = [pscustomobject]@{
    type = Get-TextValue $InputObject "type" "Доган"
    language = Get-TextValue $InputObject "language" "ru"
    from = Get-TextValue $InputObject "from"
    to = Get-TextValue $InputObject "to"
    date = Get-TextValue $InputObject "date"
    reason = Get-TextValue $InputObject "reason"
  }

  if (-not $punishment.from -or -not $punishment.to -or -not $punishment.date -or -not $punishment.reason) {
    throw (New-HttpError 400 "Заполни поля: от кого, кому, причина и когда.")
  }

  $allowedTypes = @("Доган", "Мут", "Бан", "Предупреждение")
  $allowedLanguages = @("ru", "uk")

  if ($allowedTypes -notcontains $punishment.type) {
    throw (New-HttpError 400 "Выбери правильный тип наказания.")
  }


  if ($allowedLanguages -notcontains $punishment.language) {
    throw (New-HttpError 400 "Выбери язык: Русский или Українська.")
  }

  return $punishment
}

function Send-Json {
  param(
    $Response,
    [int]$StatusCode,
    $Payload
  )

  if ($Payload -is [array]) {
    $body = ConvertTo-Json -InputObject @($Payload) -Depth 10
  } else {
    $body = ConvertTo-Json -InputObject $Payload -Depth 10
  }

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  $Response.StatusCode = $StatusCode
  $Response.ContentType = "application/json; charset=utf-8"
  $Response.ContentLength64 = $bytes.Length
  $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Send-NoContent {
  param($Response)
  $Response.StatusCode = 204
}

function Send-DiscordNotification {
  param(
    [string]$Action,
    $Punishment
  )

  if ([string]::IsNullOrWhiteSpace($script:DiscordWebhookUrl)) {
    return
  }

  $colors = @{
    created = 15680587
    updated = 16030219
    deleted = 6575243
  }

  $isUkrainian = $Punishment.language -eq "uk"
  $languageName = if ($isUkrainian) { "Українська" } else { "Русский" }

  $typeNamesRu = @{
    "Доган" = "Доган"
    "Мут" = "Мут"
    "Бан" = "Бан"
    "Предупреждение" = "Предупреждение"
  }

  $typeNamesUk = @{
    "Доган" = "Доган"
    "Мут" = "Мут"
    "Бан" = "Бан"
    "Предупреждение" = "Попередження"
  }

  $reasonNamesRu = @{
    "Не явка на лекції" = "Неявка на лекцию"
    "Рекомендації голови колегії адвокатів і президента" = "Рекомендации главы коллегии адвокатов и президента"
  }

  $reasonNamesUk = @{
    "Не явка на лекції" = "Не явка на лекції"
    "Рекомендації голови колегії адвокатів і президента" = "Рекомендації голови колегії адвокатів і президента"
  }

  if ($isUkrainian) {
    $typeText = if ($typeNamesUk.ContainsKey($Punishment.type)) { $typeNamesUk[$Punishment.type] } else { $Punishment.type }
    $reasonText = if ($reasonNamesUk.ContainsKey($Punishment.reason)) { $reasonNamesUk[$Punishment.reason] } else { $Punishment.reason }
  } else {
    $typeText = if ($typeNamesRu.ContainsKey($Punishment.type)) { $typeNamesRu[$Punishment.type] } else { $Punishment.type }
    $reasonText = if ($reasonNamesRu.ContainsKey($Punishment.reason)) { $reasonNamesRu[$Punishment.reason] } else { $Punishment.reason }
  }

  if ($isUkrainian) {
    $titles = @{
      created = "Видано покарання"
      updated = "Покарання змінено"
      deleted = "Покарання видалено"
    }

    $labels = @{
      type = "Тип"
      from = "Від кого"
      to = "Кому"
      date = "Коли"
      reason = "Причина"
    }
  } else {
    $titles = @{
      created = "Выдано наказание"
      updated = "Наказание изменено"
      deleted = "Наказание удалено"
    }

    $labels = @{
      type = "Тип"
      from = "От кого"
      to = "Кому"
      date = "Когда"
      reason = "Причина"
    }
  }

  $payload = [pscustomobject]@{
    username = if ($env:DISCORD_BOT_NAME) { $env:DISCORD_BOT_NAME } else { "Punishment Panel" }
    embeds = @(
      [pscustomobject]@{
        title = $titles[$Action]
        color = $colors[$Action]
        fields = @(
          [pscustomobject]@{ name = $labels.type; value = $typeText; inline = $false }
          [pscustomobject]@{ name = $labels.from; value = $Punishment.from; inline = $false }
          [pscustomobject]@{ name = $labels.to; value = $Punishment.to; inline = $false }
          [pscustomobject]@{ name = $labels.date; value = $Punishment.date; inline = $false }
          [pscustomobject]@{ name = $labels.reason; value = $reasonText; inline = $false }
        )
        footer = [pscustomobject]@{ text = "ID: $($Punishment.id)" }
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
      }
    )
  }

  $json = ConvertTo-Json -InputObject $payload -Depth 10
  $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  Invoke-RestMethod -Uri $script:DiscordWebhookUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $bodyBytes | Out-Null
}


function Try-SendDiscordNotification {
  param(
    [string]$Action,
    $Punishment
  )

  try {
    Send-DiscordNotification $Action $Punishment
    return $null
  } catch {
    Write-Host "Discord webhook failed: $($_.Exception.Message)"
    return "Запис збережено, але Discord не прийняв повідомлення. Перевір webhook або права каналу."
  }
}

function Add-DiscordWarning {
  param(
    $Payload,
    [string]$Warning
  )

  if ([string]::IsNullOrWhiteSpace($Warning)) {
    return $Payload
  }

  $copy = [ordered]@{}
  foreach ($property in $Payload.PSObject.Properties) {
    $copy[$property.Name] = $property.Value
  }
  $copy["discordWarning"] = $Warning
  return [pscustomobject]$copy
}
function Handle-Api {
  param($Context)

  $request = $Context.Request
  $response = $Context.Response
  $path = $request.Url.AbsolutePath
  $segments = @($path.Trim("/").Split("/", [System.StringSplitOptions]::RemoveEmptyEntries))
  $id = if ($segments.Count -ge 3) { $segments[2] } else { $null }

  if ($path -eq "/api/punishments" -and $request.HttpMethod -eq "GET") {
    $items = @(Read-Punishments | Sort-Object -Property createdAt -Descending)
    Send-Json $response 200 $items
    return
  }

  if ($path -eq "/api/punishments" -and $request.HttpMethod -eq "POST") {
    $items = @(Read-Punishments)
    $clean = Get-CleanPunishment (Get-BodyJson $request)
    $now = (Get-Date).ToUniversalTime().ToString("o")
    $punishment = [pscustomobject][ordered]@{
      id = [guid]::NewGuid().ToString()
      type = $clean.type
      language = $clean.language
      from = $clean.from
      to = $clean.to
      date = $clean.date
      reason = $clean.reason
      createdAt = $now
      updatedAt = $now
    }

    $items += $punishment
    Write-Punishments $items
    Send-DiscordNotification "created" $punishment
    Send-Json $response 201 $punishment
    return
  }

  if ($segments.Count -eq 3 -and $segments[0] -eq "api" -and $segments[1] -eq "punishments" -and $request.HttpMethod -eq "PUT") {
    $items = @(Read-Punishments)
    $existing = $items | Where-Object { $_.id -eq $id } | Select-Object -First 1

    if ($null -eq $existing) {
      Send-Json $response 404 ([pscustomobject]@{ message = "Наказание не найдено." })
      return
    }

    $clean = Get-CleanPunishment (Get-BodyJson $request)
    $updated = [pscustomobject][ordered]@{
      id = $existing.id
      type = $clean.type
      language = $clean.language
      from = $clean.from
      to = $clean.to
      date = $clean.date
      reason = $clean.reason
      createdAt = $existing.createdAt
      updatedAt = (Get-Date).ToUniversalTime().ToString("o")
    }

    $items = @($items | ForEach-Object { if ($_.id -eq $id) { $updated } else { $_ } })
    Write-Punishments $items
    Send-DiscordNotification "updated" $updated
    Send-Json $response 200 $updated
    return
  }

  if ($segments.Count -eq 3 -and $segments[0] -eq "api" -and $segments[1] -eq "punishments" -and $request.HttpMethod -eq "DELETE") {
    $items = @(Read-Punishments)
    $existing = $items | Where-Object { $_.id -eq $id } | Select-Object -First 1

    if ($null -eq $existing) {
      Send-Json $response 404 ([pscustomobject]@{ message = "Наказание не найдено." })
      return
    }

    $items = @($items | Where-Object { $_.id -ne $id })
    Write-Punishments $items
    Send-DiscordNotification "deleted" $existing
    Send-NoContent $response
    return
  }

  Send-Json $response 404 ([pscustomobject]@{ message = "API route not found." })
}

function Get-MimeType {
  param([string]$Path)

  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".html" { return "text/html; charset=utf-8" }
    ".css" { return "text/css; charset=utf-8" }
    ".js" { return "text/javascript; charset=utf-8" }
    ".json" { return "application/json; charset=utf-8" }
    ".png" { return "image/png" }
    ".jpg" { return "image/jpeg" }
    ".jpeg" { return "image/jpeg" }
    ".svg" { return "image/svg+xml" }
    default { return "application/octet-stream" }
  }
}

function Send-StaticFile {
  param($Context)

  $response = $Context.Response
  $requestPath = $Context.Request.Url.AbsolutePath

  if ($requestPath -eq "/") {
    $requestPath = "/index.html"
  }

  $relative = [Uri]::UnescapeDataString($requestPath.TrimStart("/")).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
  $filePath = [System.IO.Path]::GetFullPath((Join-Path $PublicDir $relative))
  $publicFull = [System.IO.Path]::GetFullPath($PublicDir).TrimEnd("\", "/")
  $publicRoot = $publicFull + [System.IO.Path]::DirectorySeparatorChar

  if (-not $filePath.StartsWith($publicRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Send-Json $response 403 ([pscustomobject]@{ message = "Forbidden." })
    return
  }

  if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
    $filePath = Join-Path $PublicDir "index.html"
  }

  $bytes = [System.IO.File]::ReadAllBytes($filePath)
  $response.StatusCode = 200
  $response.ContentType = Get-MimeType $filePath
  $response.ContentLength64 = $bytes.Length
  $response.OutputStream.Write($bytes, 0, $bytes.Length)
}

Import-DotEnv (Join-Path $Root ".env")

if ($Port -le 0) {
  if ($env:PORT) {
    $Port = [int]$env:PORT
  } else {
    $Port = 3000
  }
}

$script:DiscordWebhookUrl = $env:DISCORD_WEBHOOK_URL
Ensure-Store

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Punishment panel is running at http://localhost:$Port"
Write-Host "Press Ctrl+C to stop."

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()

    try {
      if ($context.Request.Url.AbsolutePath.StartsWith("/api/")) {
        Handle-Api $context
      } else {
        Send-StaticFile $context
      }
    } catch {
      $statusCode = 500
      if ($_.Exception.Data.Contains("StatusCode")) {
        $statusCode = [int]$_.Exception.Data["StatusCode"]
      }

      Write-Host $_.Exception.Message
      $errorMessage = $_.Exception.Message
      if ($statusCode -eq 500) {
        $errorMessage = "Что-то пошло не так на сервере."
      }
      Send-Json $context.Response $statusCode ([pscustomobject]@{ message = $errorMessage })
    } finally {
      $context.Response.OutputStream.Close()
    }
  }
} finally {
  $listener.Stop()
  $listener.Close()
}







