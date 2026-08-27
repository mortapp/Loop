# Native iOS Integration Run

ZIP_PATH=`C:\Users\micha\Downloads\loop-ios-supabase-connected.zip`

ZIP_SHA256=`7701272E2B7952D294DC4087DF7434CCBDDAF7EEA1C07758909C02BB11B857C0`

STAGING_PATH=`C:\Users\micha\AppData\Local\Temp\loop-ios-zip-list-b\loop-ios-monorepo\apps\ios-native`

START_HEAD=`58bf7e1565d8a401cbb4c3c414c1338126c28de0`

START_ORIGIN_MAIN=`58bf7e1565d8a401cbb4c3c414c1338126c28de0`

IOS_PROJECT_NAME=`LOOP.xcodeproj`

IOS_SCHEME=`LOOP`

IOS_BUNDLE_ID=`com.loop.app.loop_ios`

IOS_CALLBACK=`com.loop.app.loop_mobile://login-callback`

SUPABASE_PROJECT=`zqalnvfwxmfrnyjcuehq`

CURRENT_PHASE=`source integration and Windows static audit`

FILES_MERGED=`apps/ios-native/**, docs, root README, iOS GitHub Actions workflow, Windows static validation script`

FILES_REJECTED=`none; the older local ios-loop archive was not used`

TESTS=`scripts/validate-ios-native.ps1; Python plistlib XML parse; static forbidden-reference scan`

STATIC_VALIDATION=`PASS on Windows; macOS/Xcode compilation cannot run on this host`

OWNER_ACTION_REQUIRED=`Run the native app and complete Google sign-in on macOS/Xcode; confirm the existing callback remains registered in Supabase and Google.`

NEXT_ACTION=`GitHub Actions builds the LOOP scheme for a generic iOS Simulator without code signing.`
