Manual execution of validation does like this:

..\..\..\Core\deployments\scripts\manual-copy.ps1 -templateLibrarySrc ..\template\ -templateLibraryDst keyvaults/bernard-dev -storageRG PwS2-Infra-Storage-RG -storageAccountName azpwsdeploytpnjitlh3orvq -containerName library-dev

then

.\validate.ps1 -templateLibraryName keyvaults -templateLibraryVersion bernard-dev