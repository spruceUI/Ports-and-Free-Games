# retroshelf for SpruceOS

Version: 0.6.11

This package contains the retroshelf Go sync engine, SDL app, SpruceOS launcher,
and bundled SDL runtime libraries for both arm64 and Miyoo-class armv7 devices.
The engine was built for API URL:
https://www.retroshelf.org

Copy retroshelf/ into App/ on your SpruceOS SD card.

Before deleting retroshelf/, run bin/retroshelf-uninstall.sh. Pass
--keep-data when you plan to reinstall and want to preserve the linked device
and sync history.
