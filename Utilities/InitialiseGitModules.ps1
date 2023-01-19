if (Test-Path -Path "./ResourceModules") {
    Remove-Item ResourceModule -Recurse
}

git submodule add --force https://github.com/Azure/ResourceModules.git ResourceModules