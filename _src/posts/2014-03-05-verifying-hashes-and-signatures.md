    Title: Verifying Hashes and Signatures
    Date: 2014-03-05T06:44:02
    Tags: hashes, signatures, MultiBit

_Replace this with your post text. Add one or more comma-separated
Tags above. The special tag `DRAFT` will prevent the post from being
published._

Security is really important when handling bitcoins. One easy
safeguard is to make sure the programs you download are actually what
you think they are using hashes and signatures.

In this post, I essentially follow [the MultiBit tutorial][1]. I'm
using Windows 7 (64-bit).

[1]: https://multibit.org/blog/2013/07/24/how-to-check-signatures.html
"MultiBit tutorial on hashes and signatures"

<!-- more -->

# Verifying Hashes #

A hash function maps its input to a number. The [SHA-1][sha1] function
maps inputs to 160-bit (40 hexadecial digit) numbers. Here's the SHA-1
(using Microsoft's FCIV program) of the Hello World example from the
MultiBit tutorial:

[sha1]: http://en.wikipedia.org/wiki/SHA-1 "SHA-1 Wikipedia entry"

    $ echo "Hello world" > example.txt
    $ fciv -sha1 example.txt
    //
    // File Checksum Integrity Verifier version 2.05.
    //
    25e64db6d4d1d6116ffe0b317918c98f3624cbed example.txt

Note that when using Windows, the resulting hash is not the same as in
the tutorial (ie, when using Linux) because the `examples.txt` file
has extra quotes, an extra space, and uses the windows `\r\n`
end-of-line instead of `\n`. I simulated the Linux version of the example with a quick [Racket](http://racket-lang.org) script:

    $ racket
    Welcome to Racket v6.0.0.3
    > (with-output-to-file "example.txt" (lambda () (display "Hello world\n")))
    > (exit)
    $ fciv -sha1 example.txt
    //
    // File Checksum Integrity Verifier version 2.05.
    //
    33ab5639bfd8e7b95eb1d8d0b87781d4ffea4d5d example.txt

I found other people discussing the discrepancy [here][so].

[so]: http://bitcoin.stackexchange.com/questions/14041/multibit-error-or-at-least-confusion-in-how-to-check-digital-signatures-in
"Bitcoin StackExchange"

Most software you download from the internet should provide a hash
that you can verify to make sure the file was not corrupted or
altered. For example, Multibit provides SHA256 hashes [here][2].

[2]: https://multibit.org/releases/multibit-0.5.17/release.txt
"MultiBit 0.5.17 release notes"

Since FCIV only does SHA-1, I needed something else that computes SHA-256. A quick Google search turned up the [`md5deep` library][md5deep].

[md5deep]: http://md5deep.sourceforge.net/

Since we are being paranoid here, let's just make sure the program we need is [legit][vt1].

[vt1]: https://www.virustotal.com/en/file/eec0c765124b014c824db8759300f36b4a62b74ff81dfa68f77440389bb68d29/analysis/
"sha256deep64.exe on virustotal"

Now we're finally ready to check the hash of MultiBit 0.5.17 for Windows.

From the [release file][2]:

    SHA256 hashes for files:
    90506bf43a64986ce8219ca0fb18a5e1f0776cfeb31043ca848cea7f71eda45d  multibit-0.5.17-windows-setup.exe

Computing the hash:

    $ sha256deep64.exe multibit-0.5.17-windows-setup.exe
    90506bf43a64986ce8219ca0fb18a5e1f0776cfeb31043ca848cea7f71eda45d  multibit-0.5.17-windows-setup.exe

And it matches!

# Verifying Signatures #