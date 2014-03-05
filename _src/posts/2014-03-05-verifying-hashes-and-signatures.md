    Title: Verifying Hashes and Signatures
    Date: 2014-03-05T06:44:02
    Tags: hashes, signatures, MultiBit

_Replace this with your post text. Add one or more comma-separated
Tags above. The special tag `DRAFT` will prevent the post from being
published._

Security is really important when handling bitcoins. One easy
safeguard is to make sure the programs you download are actually what
you think they are using hashes and signatures.

In this post, I'm using Windows 7 (64-bit), and I essentially follow [the MultiBit tutorial][1].

[1]: https://multibit.org/blog/2013/07/24/how-to-check-signatures.html
"MultiBit tutorial on hashes and signatures"

<!-- more -->

# Verifying Hashes #

A hash function maps its input to a number. The SHA-1 function maps
inputs to 160-bit (40 hexadecial digit) numbers. Here's the Hello
World example from the MultiBit tutorial:

    $ echo "Hello world" > example.txt
    $ fciv -sha1 example.txt
    //
    // File Checksum Integrity Verifier version 2.05.
    //
    25e64db6d4d1d6116ffe0b317918c98f3624cbed example.txt

Most software you download from the internet should provide a hash
that you can verify to make sure the file was not corrupted or
altered. For example, Multibit provides SHA256 hashes [here][2].

[2]: https://multibit.org/releases/multibit-0.5.17/release.txt
"MultiBit 0.5.17 release notes"

Even though the tutorial suggests downloading getting Microsoft's FCIV tool, it only has SHA1, and I need SHA256, so I 


# Verifying Signatures #