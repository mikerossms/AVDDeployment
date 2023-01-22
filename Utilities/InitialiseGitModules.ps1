# RE-initialises the ResourceModules repo and reconnecting it as a shared repo to this one.

if (Test-Path -Path "./ResourceModules") {
    Remove-Item ResourceModule -Recurse
}

git submodule add --force https://github.com/Azure/ResourceModules.git ResourceModules