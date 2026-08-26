AUTO TECHNO FOR WINDOWS

Launch AutoTechno.exe. The application is standalone at runtime: it needs no
DAW, plug-in host, cloud service, account, or external audio content.

Keep AutoTechno.exe and the adjacent DLL files together. They are the official
Swift/Foundation and Microsoft C++ runtime libraries required by Windows; the
installer keeps them together automatically.

This build has one accessible Play/Pause transport. It prepares immutable audio
ahead of playback and queues three bars of lookahead. Closing the window stops
playback and releases the default output device.

BUILD-MANIFEST.json records the exact source revision and Swift toolchain.
CHECKSUMS.txt records a SHA-256 hash for every staged file.
