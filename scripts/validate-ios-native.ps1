param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$iosRoot = Join-Path $ProjectRoot 'apps/ios-native'
$configuration = Join-Path $iosRoot 'LOOP/Core/Configuration/LoopConfiguration.swift'
$liveServices = Join-Path $iosRoot 'LOOP/Services/Live/LiveServices.swift'
$infoPlist = Join-Path $iosRoot 'LOOP/Info.plist'
$projectFile = Join-Path $iosRoot 'LOOP.xcodeproj/project.pbxproj'

foreach ($path in @($configuration, $liveServices, $infoPlist, $projectFile)) {
    Assert-True (Test-Path -LiteralPath $path) "Required native iOS file is missing: $path"
}

[xml](Get-Content -Raw -LiteralPath $infoPlist) | Out-Null
$configurationText = Get-Content -Raw -LiteralPath $configuration
$liveServicesText = Get-Content -Raw -LiteralPath $liveServices
$projectText = Get-Content -Raw -LiteralPath $projectFile
$iosSource = (Get-ChildItem -LiteralPath $iosRoot -Recurse -File | Where-Object { $_.Extension -in '.swift', '.plist', '.pbxproj' } | ForEach-Object {
    Get-Content -Raw -LiteralPath $_.FullName
}) -join "`n"

Assert-True ($configurationText -match 'https://zqalnvfwxmfrnyjcuehq\.supabase\.co') 'LOOP Supabase URL is not configured.'
Assert-True ($configurationText -match 'com\.loop\.app\.loop_mobile://login-callback') 'Canonical Supabase PKCE callback is not configured.'
Assert-True ($projectText -match 'PRODUCT_BUNDLE_IDENTIFIER = com\.loop\.app\.loop_ios;') 'Native app bundle identifier is not com.loop.app.loop_ios.'
Assert-True ($projectText -match 'membershipExceptions = \([\s\S]*Info\.plist') 'Xcode project does not exclude Info.plist from filesystem-synchronized resource membership.'

foreach ($rpc in @('account_money_totals', 'create_purchase_with_money_event', 'create_listing_and_mark_item', 'create_quote_with_line_items', 'generate_today_actions', 'record_item_sale', 'refund_return_with_money_event', 'set_quote_status_with_money_event')) {
    Assert-True ($liveServicesText -match [regex]::Escape('"' + $rpc + '"')) "Missing canonical RPC: $rpc"
}

foreach ($table in @('profiles', 'accounts', 'actions', 'contacts', 'leads', 'opportunities', 'quotes', 'quote_line_items', 'money_events', 'items', 'purchases', 'returns', 'warranties', 'valuations', 'listings', 'sales', 'documents')) {
    Assert-True ($liveServicesText -match [regex]::Escape('"' + $table + '"')) "Missing canonical table reference: $table"
}

Assert-True ($liveServicesText -match 'let contactResults = contacts\.map') 'Live search does not route contact results.'
Assert-True ($liveServicesText -match 'source: \.customer\(\$0\.id\)') 'Live search does not route contacts to their detail view.'
Assert-True ($liveServicesText -match 'let leadResults = leads\.map') 'Live search does not route lead results.'
Assert-True ($liveServicesText -match 'source: \.lead\(\$0\.id\)') 'Live search does not route leads to their detail view.'

foreach ($forbidden in @('rakjydmgwwgtdislanbt', 'money_transactions', 'owned_items', 'loop_exchange_oauth_code', 'inventory_items', 'service_role', 'ANTHROPIC_API_KEY', 'client_secret', 'localhost', '127.0.0.1', 'example.supabase.co', 'placeholder.supabase.co')) {
    Assert-True ($iosSource -notmatch [regex]::Escape($forbidden)) "Forbidden iOS runtime reference found: $forbidden"
}

Write-Output 'IOS_NATIVE_STATIC_VALIDATION=PASS'
