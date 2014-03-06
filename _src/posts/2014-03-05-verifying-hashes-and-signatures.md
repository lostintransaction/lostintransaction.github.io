    Title: Verifying Hashes and Signatures
    Date: 2014-03-05T06:44:02
    Tags: hashes, signatures, MultiBit

_Replace this with your post text. Add one or more comma-separated
Tags above. The special tag `DRAFT` will prevent the post from being
published._

Security is really important when handling bitcoins. One easy
safeguard is to make sure you're downloading what you think you're
downloading using hashes and signatures.

In this post, I check the hash and signature of
MultiBit, essentially following
[the MultiBit tutorial on hashes and signatures][1]. All examples are
run in Windows 7 (64-bit).

[1]: https://multibit.org/blog/2013/07/24/how-to-check-signatures.html
"MultiBit tutorial on hashes and signatures"

<!-- more -->

## Verifying Hashes ##

A hash function maps its input to a number. The [SHA-1][sha1] function
maps inputs to 160-bit numbers (40 hexadecial digits). Here's the SHA-1
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
end-of-line instead of `\n`. We can simulate the Linux version of the
example with a quick [Racket](http://racket-lang.org) script:

```racket
(with-output-to-file "example.txt" (lambda () (display "Hello world\n")) #:exists 'replace)
```

```racket
$ del example.txt
$ racket
Welcome to Racket v6.0.0.3
> (with-output-to-file "example.txt" (lambda () (display "Hello world\n")) #:exists 'replace)
> (exit)
$ fciv -sha1 example.txt
//
// File Checksum Integrity Verifier version 2.05.
//
33ab5639bfd8e7b95eb1d8d0b87781d4ffea4d5d example.txt
```
	
[It looks like I'm not the only person that noticed the discrepancy][so].

[so]: http://bitcoin.stackexchange.com/questions/14041/multibit-error-or-at-least-confusion-in-how-to-check-digital-signatures-in
"Bitcoin StackExchange"

Most software you download from the internet should provide a hash
that you can verify to make sure the file was not corrupted or
altered. For example, Multibit provides [SHA-256 hashes][sha256] (256-bits)
in [the release notes][0517notes] (SHA-256 is also the main hash function used in the
[Bitcoin protocol][protocol].

[sha256]: http://en.wikipedia.org/wiki/SHA-2 "SHA-256 Wikipedia entry"
[0517notes]: https://multibit.org/releases/multibit-0.5.17/release.txt
"MultiBit 0.5.17 release notes"
[protocol]: https://en.bitcoin.it/wiki/Protocol_specification#Common_standards 
"Bitcoin protocol"

Since FCIV only does SHA-1, I needed something else that computes SHA-256. A quick Google search turned up the [`md5deep` library][md5deep].

[md5deep]: http://md5deep.sourceforge.net/

Since we are being paranoid here, let's just make sure the program we need is virus free by [uploading to VirusTotal][vt1].

[vt1]: https://www.virustotal.com/en/file/eec0c765124b014c824db8759300f36b4a62b74ff81dfa68f77440389bb68d29/analysis/
"sha256deep64.exe on virustotal"

VirusTotal also uses SHA-1, to track which files it has seen, and we
can check that the file we uploaded, `sha256deep64.exe`, matches the
file for which VirusTotal is reporting results:

    $ sha256deep64 sha256deep64.exe
    eec0c765124b014c824db8759300f36b4a62b74ff81dfa68f77440389bb68d29  sha256deep64.exe

Interestingly, `sha256deep64.exe` and `sha1deep64.exe` produce the same SHA-256 hash:

    $ sha256deep64 sha1deep64.exe
    eec0c765124b014c824db8759300f36b4a62b74ff81dfa68f77440389bb68d29  sha1deep64.exe

No cause for concern though. Apparently this is
[intentional][samehash] and the file behaves differently based on its
name.

[samehash][http://sourceforge.net/projects/md5deep/reviews/?offset=25] 
"explanation of identical hash"

Now we're finally ready to check the hash of MultiBit 0.5.17 for Windows.

From the [release file][2]:

    SHA256 hashes for files:
    90506bf43a64986ce8219ca0fb18a5e1f0776cfeb31043ca848cea7f71eda45d  multibit-0.5.17-windows-setup.exe

Computing the hash of the downloaded file:

    $ sha256deep64.exe multibit-0.5.17-windows-setup.exe
    90506bf43a64986ce8219ca0fb18a5e1f0776cfeb31043ca848cea7f71eda45d  multibit-0.5.17-windows-setup.exe

And it matches!

# Verifying Signatures #
