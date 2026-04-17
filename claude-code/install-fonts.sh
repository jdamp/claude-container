#!/bin/sh
set -eu

# Fonts not packaged in Alpine (Roboto comes from the apk package)

mkdir -p /usr/share/fonts/source-sans-pro \
         /usr/share/fonts/source-sans-3 \
         /usr/share/fonts/font-awesome-6 \
         /usr/share/fonts/font-awesome-7

wget -qO /tmp/sanspro.zip \
    "https://github.com/adobe-fonts/source-sans/releases/download/2.045R-ro%2F1.095R-it/source-sans-pro-2.045R-ro-1.095R-it.zip"
unzip -qj /tmp/sanspro.zip "*.otf" -d /usr/share/fonts/source-sans-pro/

wget -qO /tmp/sans3.zip \
    "https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip"
unzip -qj /tmp/sans3.zip "*.otf" -d /usr/share/fonts/source-sans-3/

wget -qO /tmp/fa6.zip \
    "https://use.fontawesome.com/releases/v6.5.2/fontawesome-free-6.5.2-desktop.zip"
unzip -qj /tmp/fa6.zip "*/otfs/*.otf" -d /usr/share/fonts/font-awesome-6/

wget -qO /tmp/fa7.zip \
    "https://use.fontawesome.com/releases/v7.2.0/fontawesome-free-7.2.0-desktop.zip"
unzip -qj /tmp/fa7.zip "*/otfs/*.otf" -d /usr/share/fonts/font-awesome-7/

fc-cache -f
rm -f /tmp/sanspro.zip /tmp/sans3.zip /tmp/fa6.zip /tmp/fa7.zip
