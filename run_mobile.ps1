$env:JAVA_HOME="E:\Java\java-1.8.0-openjdk-1.8.0.392-1.b08.redhat.windows.x86_64"
$env:GRADLE_USER_HOME="E:\.gradle"
$env:JAVA_TOOL_OPTIONS="-Djava.io.tmpdir=E:\.tmp"
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"

Write-Host "Launching Drivo on Mobile... (This may take a minute)"
flutter run -d RZ8RC06NKED
