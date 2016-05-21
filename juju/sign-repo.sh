#!/bin/bash

cd repo
dpkg-sig --sign builder *.deb

apt-ftparchive packages . > Packages
sed -i 's/Filename: .\//Filename: /g' Packages 
gzip -c Packages > Packages.gz

apt-ftparchive release . > Release
gpg --clearsign -o InRelease Release
gpg -abs -o Release.gpg Release

gpg --output key --armor --export A246AB40

