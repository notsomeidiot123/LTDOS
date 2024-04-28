# LTDOS
#### Learning to make an operating system, starting from an x86 DOS-like

In my previous attempts, I've always managed to get my self way in over my own head. While my previous project, [EdenOS](https://github.com/notsomeidiot123/EdenOS) is not dead, I've taken a break from it, and probably will do another re-write of the architecture, as It's been so long since i've worked on it that I've completely forgotten what I was doing. This operating system here will focus on being the bare minimum. That is, a 16-bit real mode operating system that can read, write, and execute files. Since it's more hassle than it's worth, I will not be writing this in C, just pure x86 assembly, and will make a few basic apps that will be compatible with later versions of this project (Most notibly, when i reach x86-32 and later, x86-64)

This 16-bit version will have only 3 features:

Loading Executables from a FAT-12 formatted floppy disk in COM or MZ format
Reading and writing files to said formatted disk
Providing a basic interface for both the user to interact with the system

