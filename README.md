# zerver
Exploring zig's network and server functionalities

# KNOWN BUG IN 0.17.0
On windows there is an issue compiling due to a enum value in the translate-c package. 
How to solve:
error msg example : "no avx512bmm Feature in your bla bla...", go in zig-pkg and comment out the enum entry correspondingto avx512bmm. The bug should be resolved with the release of zig 0.17.1.
