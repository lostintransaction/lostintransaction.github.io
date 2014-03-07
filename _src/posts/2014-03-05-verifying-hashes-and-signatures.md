    Title: Verifying Hashes and Signatures
    Date: 2014-03-05T06:44:02
    Tags: hashes, signatures, MultiBit

Security is really important when handling bitcoins. Hashes and
signatures can help by verifying that you're downloading what you
think you're downloading.

In this post, I briefly explain hashes and signatures, and then check
the hash and signature of the MultiBit wallet program, essentially
following [the MultiBit tutorial on hashes and signatures][1]. All
examples are run in Windows 7 (64-bit).

[1]: https://multibit.org/blog/2013/07/24/how-to-check-signatures.html
"MultiBit tutorial on hashes and signatures"

<!-- more -->

### Verifying Hashes ###

#### _A first example_ ####

A hash function maps its input to a number. The [SHA-1][sha1] hash
function maps inputs to 160-bit numbers (40 hexadecial digits). Here's
the SHA-1 hash (computed with Microsoft's FCIV program) of the `"Hello
world"` example from the MultiBit tutorial:

[sha1]: http://en.wikipedia.org/wiki/SHA-1 "SHA-1 Wikipedia entry"

    $ echo "Hello world" > example.txt
    $ fciv -sha1 example.txt
    //
    // File Checksum Integrity Verifier version 2.05.
    //
    25e64db6d4d1d6116ffe0b317918c98f3624cbed example.txt

Note that in Windows, the resulting hash differs from the tutorial
(ie, when using Linux) because the Windows `examples.txt` file has
extra quotes, an extra space, and uses the windows `\r\n` end-of-line
instead of `\n`. We can easily simulate the Linux version though. Here
I use a [Racket](http://racket-lang.org) script:

```racket
(with-output-to-file "example.txt" (lambda () (display "Hello world\n")) #:exists 'replace)
```

    $ racket
    Welcome to Racket v6.0.0.3
    > (with-output-to-file "example.txt" (lambda () (display "Hello world\n")) #:exists 'replace)
    > (exit)
    $ fciv -sha1 example.txt
    //
    // File Checksum Integrity Verifier version 2.05.
    //
    33ab5639bfd8e7b95eb1d8d0b87781d4ffea4d5d example.txt
	
[It looks like I'm not the only person that noticed the discrepancy][so].

[so]: http://bitcoin.stackexchange.com/questions/14041/multibit-error-or-at-least-confusion-in-how-to-check-digital-signatures-in
"Bitcoin StackExchange"

#### _Computing SHA-256_ ####

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

Since FCIV only does SHA-1, we need something else that computes
SHA-256. A quick Google search finds the [`md5deep` library][md5deep].

[md5deep]: http://md5deep.sourceforge.net/

Since we are focusing on security, let's make sure the program we just
got is virus-free by [uploading to VirusTotal][vt1].

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
[intentional][samehash] and the file determines its behavior based on its
filename.

[samehash][http://sourceforge.net/projects/md5deep/reviews/?offset=25] 
"explanation of identical hash"

#### _Checking MultiBit's hash_ ####

Now we're finally ready to check the hash of MultiBit 0.5.17 for Windows.

From the [release notes][0517notes]:

    SHA256 hashes for files:
    90506bf43a64986ce8219ca0fb18a5e1f0776cfeb31043ca848cea7f71eda45d  multibit-0.5.17-windows-setup.exe

Computing the hash of the downloaded file:

    $ sha256deep64.exe multibit-0.5.17-windows-setup.exe
    90506bf43a64986ce8219ca0fb18a5e1f0776cfeb31043ca848cea7f71eda45d  multibit-0.5.17-windows-setup.exe

And it matches!

### Verifying Signatures ###

#### _A very brief introduction_ ####

Verifying the hash only ensures that nothing happened to the file
during the download. For example, you can be pretty sure that no one
intercepted your download and then sent you a hacked version. But what
if the website you downloaded from was hacked in the first place, so
both the file and the has were fake?

This is where [digital signatures][digsig] can help. Briefly, to prove
that a file was not tampered with, the distributor of the file "signs"
the file with a secret key that only they know. The distributor then
posts the file, the signature, and a public key that is calculated
from the private key. The downloader then uses the public and
signature to verify the downloaded file.

In a secure signature system, it's impossible to determine the private
key from the public key. Also, the verification process is only
successful if the downloaded file was originally signed with the
private key, which is only known by the distributor of the file. In
other words, in a secure system, it's computationally impossible to
forge a valid signature without knowledge of the private key.

[digsig]: http://en.wikipedia.org/wiki/Digital_signature 
"digital signature Wikipedia entry"

##### NOTE: #####

Verifying a signature does not guarantee that the file you
downloaded was not tampered with. If you don't know the person
distributing the file, then you wouldn't be able to distinguish
between a legitamate file-signature-public key set from a bad
one. However, the system relies on additional knowledge about the
public key you are using. 

For example, the public key could be confirmed by a central authority
or key server that does additional checks to link keys to people. Or
the other person, and their public key, may be well known, and so the
"confirmation" in this case would be an informal public
consensus. None of these methods guarantees authenticity, but it's a
lot more difficult to fool.

#### _Checking MultiBit's signature_ ####

A well-known signature system is [PGP][pgp], which we'll use to check
verify MultiBit's signature. 

1. First we download [GnuPG][gnupg] [for Windows][gpgwin],
specifically Gpg4win-Vanilla 2.2.1. Of course we check the hash first:

    $ sha1deep64 gpg4win-vanilla-2.2.1.exe
    6d229b03ec2dcbb54a40f7590d108dc0cbcb5aac  gpg4win-vanilla-2.2.1.exe
	
and make sure [it matches][gpghash], which it does.

[pgp]: http://en.wikipedia.org/wiki/Pretty_Good_Privacy "PGP Wikipedia entry"
[gnupg]: http://www.gnupg.org/ "GnuPG"
[gpgwin]: http://www.gnupg.org/ "GnuPG for Windows"
[gpghash]: http://gpg4win.org/download.html "Gpg4win download and hashes"

2. Then, following the MultiBit tutorial, we get the public key for
Jim Burton, MultiBit developer, from a key server.

    $ gpg2.exe" --keyserver pgp.mit.edu -- recv-keys 0x79F7C572
     gpg: requesting key 79F7C572 from hkp server pgp.mit.edu
     gpg: .../AppData/Roaming/gnupg/trustdb.gpg: trustdb created
     gpg: key 79F7C572: public key "Jim Burton (multibit.org developer) <jim618@fastmail.co.uk>" imported
     gpg: no ultimately trusted keys found
     gpg: Total number processed: 1
     gpg:               imported: 1  (RSA: 1)

3. Then we download the [signature file][multibitsig].

[multibitsig]: https://multibit.org/releases/multibit-0.5.17/multibit-0.5.17-windows-setup.exe.asc "MultiBit signature file"

4. Finally, we can verify that Jim signed the file we're downloading
and that it hasn't been tampered with.

    $ gpg2.exe" --verify multibit-0.5.17-windows-setup.exe.asc
    gpg: Signature made 03/03/14 06:09:34 Eastern Standard Time using RSA key ID 23F7FB7B
    gpg: Good signature from "Jim Burton (multibit.org developer) <jim618@fastmail.co.uk>"
    gpg: WARNING: This key is not certified with a trusted signature!
    gpg:          There is no indication that the signature belongs to the owner.
    Primary key fingerprint: 299C 423C 672F 47F4 756A  6BA4 C197 2AED 79F7 C572
         Subkey fingerprint: 4A71 A836 F572 01B4 D088  7D60 0820 A658 23F7 FB7B
	 
The warning means that we have never seen Jim's public key, and nor
has anyone that we trust. This key server uses the [public-based key
confirmation strategy][wot] described above. A person's public keys can be
signed by other people and in this way, each of these people are
vouching that this is Jim's key. Of course, it could still be that
lots of people have teamed up to deceive you. As the key accumulates
more signatures, however, the likelihood that it is fake does
down. Also, the GnuPG program keeps track of keys of people you trust
and lets you know if one of these people have signed Jim's key.

[wot]: http://en.wikipedia.org/wiki/Web_of_trust "web of trust Wikipedia entry"
