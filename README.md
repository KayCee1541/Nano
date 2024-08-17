      /-|   /-/    /-|       /-|   / /    /-------/
     / /|  / /    / /|      / /|  / /    / /---/ /
    / / | / /    / / |     / / | / /    / /   / /
   / /| |/ /    / /| |    / /| |/ /    / /   / /
  / / | / /    / /-| |   / / | / /    / /   / /
 / /  |/ /    / /--| |  / /  |/ /    / /---/ /
/-/   |-/    /-/   | | /-/   |-/    /-------/

(c) 2024

What is Project Nano?
Project Nano is an attempt to get a secure, multitasking, gui operating system on the intel 80186

Project Goals:
- compatible with i286+
- preemptive multitasking
- custom interrupts
- GUI support
- more tbd

Building:
To build the files into ./build/, run buildscript.ps1 in powershell.
To generate a compatible disk image, run diskformat.ps1 in powershell.

Roadmap:
[x] CUSTOM BOOTLOADER
[ ] CUSTOM INTERRUPTS
    [ ] VGA DRIVER
    [ ] PS/2 KEYBOARD HANDLER
    [ ] MOUSE HANDLER
    [ ] DISK DRIVE IMPLEMENTATION
    [ ] TIMER
    [ ] INTER-PROCESS COMMUNICATION
[ ] SYSCALLS/OS API
[ ] SHELL
[ ] FILESYSTEM
[ ] MULTITASKING
