    Title: Verifying Andreas's Dorian Nakamoto Fundraiser Message
    Date: 2014-03-07T18:52:52
    Tags: Andreas Antonopoulos, signatures

Today, Andreas M. Antonopoulos, Chief Security Officer of
Blockchain.info, started a [fundraiser][reddit] for Dorian Nakamoto,
the guy who's being harassed by the media due to Newsweek's recent
article about Satoshi Nakamoto. To prove that the message is not fake,
Andreas [signed the message][pastebin] with his public key. Since I've
[recently been playing with digital signatures][sigs], this seemed
like a great chance to explore some more. Let's try to to verify the
message.

[reddit]: http://www.reddit.com/r/Bitcoin/comments/1ztjmg/andreas_im_fundraising_for_dorian_nakamoto/ "Dorian fundraiser message on Reddit"
[pastebin]: http://pastebin.com/4MHvpaeN "Dorian fundraiser message on Pastebin"
[sigs]: http://www.lostintransaction.com/blog/2014/03/05/verifying-hashes-and-signatures/ "Post: Verifying Hashes and Signatures"

<!-- more -->

Unlike, [when we wanted to verify the Multibit signature][sigs], Andreas posted a [clearsigned][clearsign] message, where the content and signature are in the same document. However, we can still use [GnuPG][gnupg] to verify the message.

First, we need Andreas's public key. I went to the [MIT PGP Public Key Server](http://pgp.mit.edu/) and [searched for `"Andreas M. Antonopoulos"`][searchres]. There were several results, so I arbitrarily chose the one associated with his domain name:

[clearsign]: http://gnupg.org/gph/en/manual/x135.html "GnuPG docs"
[gnupg]: http://www.gnupg.org/: "GnuPG"
[searchres]: http://pgp.mit.edu/pks/lookup?search=%22Andreas+M.+Antonopoulos%22&op=index "Andreas PGP key search results"

    pub  4096R/2878DE4F 2013-12-14 Andreas M. Antonopoulos <andreas@antonopoulos.com>

I then added the key to my database using [GnuPG][gnupg]:

    $ gpg2.exe" --keyserver pgp.mit.edu --recv-keys 0x2878DE4F
    gpg: requesting key 2878DE4F from hkp server pgp.mit.edu
    gpg: key 2878DE4F: public key "Andreas M. Antonopoulos <andreas@antonopoulos.com>" imported
    gpg: Total number processed: 1
    gpg:               imported: 1  (RSA: 1)

Next, I downloaded the [message from Pastebin][pastebindl] and tried to verify it:

[pastebindl]: http://pastebin.com/download.php?i=4MHvpaeN "download message txt file"

    $gpg2.exe" --verify andreas_fundraising_for_dorian.txt
    gpg: Signature made 03/07/14 12:26:34 Eastern Standard Time using RSA key ID B1632E74
    gpg: Can't check signature: No public key

Oops, I got the wrong key. The message is signed with key `B1632E74`
(Andreas's Blockchain.info key) so let's get that one:

    $ gpg2.exe" --keyserver pgp.mit.edu --recv-keys 0xB1632E74
    gpg: requesting key B1632E74 from hkp server pgp.mit.edu
    gpg: key B1632E74: public key "Andreas M. Antonopoulos (Blockchain.info CSO) <andreas@blockchain.info>" imported
    gpg: no ultimately trusted keys found
    gpg: Total number processed: 1
    gpg:               imported: 1  (RSA: 1)

And now let's try to verify:

    $ gpg2.exe" --verify andreas_fundraising_for_dorian.txt
    gpg: Signature made 03/07/14 12:26:34 Eastern Standard Time using RSA key ID B1632E74
    gpg: Good signature from "Andreas M. Antonopoulos (Blockchain.info CSO) <andreas@blockchain.info>"
    gpg: WARNING: This key is not certified with a trusted signature!
    gpg:          There is no indication that the signature belongs to the owner.
    Primary key fingerprint: B40F E0EB 4316 82F5 A7BD  5B3B 339B 0210 B163 2E74

Success!

One final issue. How do we know that _the_ Andreas Antonopoulos actually controls the `B1632E74` key, and not someone posing as him, or someone else with the same name. As I mentioned in a [previous post][sigs], there's a few options:

1. We can look in a central place that we trust. I checked
[bitcoin.org](https://bitcoin.org/en) and found the
[PGP keys for several important people](https://bitcoin.org/en/development)
in the Bitcoin community. But no Andreas! I could not find anything on
[blockchain.info](https://blockchain.info) either.

2. We can do an informal verification via "public consensus" by looking
at [who else signed Andreas's key][andreaskey]. Unfortunately, there
are not too many other signatures at the moment:

        uid Andreas M. Antonopoulos (Blockchain.info CSO) <andreas@blockchain.info>
        sig  sig3  B1632E74 2014-01-22 __________ 2015-01-22 [selfsig]
        sig  sig   2878DE4F 2014-01-22 __________ __________ Andreas M. Antonopoulos <andreas@antonopoulos.com>
        sig  sig   CF8338F5 2014-03-07 __________ __________ Christopher David Howie <me@chrishowie.com>
Other than Andreas himself, there's only one other person that is vouching for the key.

3. Luckily, Andreas anticipated this issue, and
[issued a statement on YouTube][youtube], confirming his key. That
confirms it! Now we are assured that the message is authentic.

[andreaskey]: http://pgp.mit.edu/pks/lookup?op=vindex&search=0x339B0210B1632E74 "Andreas Antonopoulos public key signatures"
[youtube]: http://www.youtube.com/watch?v=JCF1u1Wqfv0 "Andreas PGP key YouTube video"
