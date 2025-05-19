Write-Output "$WINDOWN_PFX"
Move-Item -Path $WINDOWS_PFX -Destination cloudchat.pem
certutil -decode cloudchat.pem cloudchat.pfx

flutter pub run msix:create -c cloudchat.pfx -p $WINDOWS_PFX_PASS --sign-msix true --install-certificate false
