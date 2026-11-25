$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $flutter = (Get-Command flutter).Source
    $dart = Join-Path (Split-Path $flutter) 'cache/dart-sdk/bin/dart.exe'
    $env:FLUTTER_ROOT = Split-Path (Split-Path $flutter)

    & $dart pub get
    if ($LASTEXITCODE) { throw 'Could not resolve Flutter dependencies.' }
    if (!(Test-Path 'web/sqlite3.wasm')) {
        $sqlite3 = 'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm'
        Invoke-WebRequest -UseBasicParsing -Uri $sqlite3 -OutFile '.dart_tool/sqlite3-2.9.4.wasm'
        Copy-Item '.dart_tool/sqlite3-2.9.4.wasm' 'web/sqlite3.wasm'
    }
    & $dart compile js -O2 --no-source-maps tool/sqflite_web_worker.dart -o .dart_tool/sqflite_sw.js
    if ($LASTEXITCODE) { throw 'Could not compile the SQLite Web worker.' }
    Copy-Item '.dart_tool/sqflite_sw.js' 'web/sqflite_sw.js'

    $version = '0.10.21'
    $archive = ".dart_tool/tasks-vision-$version.tgz"
    $expectedHash = '4EE84A1FE72B79DAB8CCB92C19B62B9EF27568B21631CE6BD141F0CF1CEA978047102270200A0147AD59AEAC06396E99992048CD4D6DE15B4A8FC85BC4568A78'
    if (!(Test-Path $archive)) {
        $url = "https://registry.npmjs.org/@mediapipe/tasks-vision/-/tasks-vision-$version.tgz"
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive
    }
    if ((Get-FileHash $archive -Algorithm SHA512).Hash -ne $expectedHash) {
        throw "MediaPipe archive checksum mismatch. Download a fresh copy of $archive."
    }

    $vision = New-Item -ItemType Directory -Force 'web/vision'
    $entries = @(
        'package/vision_bundle.mjs', 'package/README.md',
        'package/wasm/vision_wasm_internal.js', 'package/wasm/vision_wasm_internal.wasm',
        'package/wasm/vision_wasm_nosimd_internal.js', 'package/wasm/vision_wasm_nosimd_internal.wasm'
    )
    & tar.exe -xf $archive -C $vision.FullName --strip-components=1 @entries
    if ($LASTEXITCODE) { throw 'Could not extract the MediaPipe runtime.' }
    # Python's HTTP server on Windows may serve .mjs as text/plain.
    Move-Item -LiteralPath (Join-Path $vision.FullName 'vision_bundle.mjs') -Destination (Join-Path $vision.FullName 'vision_bundle.js') -Force

    $license = Join-Path $vision.FullName 'LICENSE.txt'
    if (!(Test-Path $license)) {
        $url = "https://raw.githubusercontent.com/google-ai-edge/mediapipe/v$version/LICENSE"
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $license
    }
    Copy-Item 'android/app/src/main/assets/face_landmarker.task' $vision.FullName
    Copy-Item 'android/app/src/main/assets/vowel_a.wav' $vision.FullName
} finally {
    Pop-Location
}
