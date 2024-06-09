# LTDOS
#### Learning to make an operating system, starting from an x86 DOS-like

In my previous attempts, I've always managed to get my self way in over my own head. While my previous project, [EdenOS](https://github.com/notsomeidiot123/EdenOS) is not dead, (Update 6/9/24: It might be dead now. Me and the person i designed it with broke it off and now I might be re-doing the entire thing) I've taken a break from it, and probably will do another re-write of the architecture, as It's been so long since i've worked on it that I've completely forgotten what I was doing. This operating system here will focus on being the bare minimum. That is, a 16-bit real mode operating system that can read, write, and execute files. Since it's more hassle than it's worth, I will not be writing this in C, just pure x86 assembly, and will make a few basic apps that will be compatible with later versions of this project (Most notibly, when i reach x86-32 and later, x86-64)

This 16-bit version will have only 3 features:

Loading Executables from a FAT-16 formatted floppy disk in COM or MZ format

Reading and writing files to said formatted disk

Providing a basic interface for both the user to interact with the system

With the stock filesystem driver, currently there is a bug that requires files to have a 3-character file extension at the end of their names. This will hope fully be patched later with a seperate driver, or a bug fix

Intentionally, the default filesystem driver only supports FAT16, and no subdirectories. This might be added later, but do not expect it. I'll probably end up starting my 32-bit update before I add this feature. This project might even die, and I end up working on EdenOS (or some new operating system).

