package Session::Token;

use strict;

use Carp qw/croak/;
use POSIX qw/ceil/;


our $VERSION = '1.007';

require XSLoader;
XSLoader::load('Session::Token', $VERSION);


my $default_alphabet = join('', ('0'..'9', 'a'..'z', 'A'..'Z',));
my $default_entropy = 128;

my $is_windows;

if ($^O =~ /mswin/i) {
  require Crypt::Random::Source::Strong::Win32;
  $is_windows = 1;
}


sub new {
  my ($class, @args) = @_;

  ## support arguments in a hash ref
  @args = %{$args[0]} if @args == 1 && ref $args[0] eq 'HASH';

  my %args = @args;

  my $self = {};
  bless $self, $class;

  ## Init seed

  my $seed;

  if (defined $args{seed}) {
    croak "seed argument should be a 1024 byte long bytestring"
      unless length($args{seed}) == 1024;
    $seed = $args{seed};
  }

  if (!defined $seed) {
    if ($is_windows) {
      my $windows_rng_source = Crypt::Random::Source::Strong::Win32->new;
      $seed = $windows_rng_source->get(1024);
      die "Win32 RNG source didn't provide 1024 bytes" unless length($seed) == 1024;
    } else {
      my ($fh, $err1, $err2);

      open($fh, '<:raw', '/dev/urandom') || ($err1 = $!);
      open($fh, '<:raw', '/dev/arandom') || ($err2 = $!)
        unless defined $fh;

      if (!defined $fh) {
        croak "unable to open /dev/urandom ($err1) or /dev/arandom ($err2)";
      }

      sysread($fh, $seed, 1024) == 1024 || croak "unable to read from random device: $!";
    }
  }


  ## Init alphabet

  $self->{alphabet} = defined $args{alphabet} ? $args{alphabet} : $default_alphabet;
  $self->{alphabet} = join('', @{$self->{alphabet}}) if ref $self->{alphabet} eq 'ARRAY';

  croak "alphabet must be between 2 and 256 bytes long"
    if length($self->{alphabet}) < 2 || length($self->{alphabet}) > 256;


  ## Init token length

  croak "you can't specify both length and entropy"
    if defined $args{length} && defined $args{entropy};

  if (defined $args{length}) {
    croak "bad value for length" unless $args{length} =~ m/^\d+$/ && $args{length} > 0;
    $self->{length} = $args{length};
  } else {
    my $entropy = $args{entropy} || $default_entropy;
    croak "bad value for entropy" unless $entropy > 0;
    my $alphabet_entropy = log(length($self->{alphabet})) / log(2);
    $self->{length} = ceil($entropy / $alphabet_entropy);
  }

  ## Create the ISAAC context
  $self->{ctx} = _get_isaac_context($seed) || die "Bad seed (incorrect length?)";

  return $self;
}


sub get {
  my ($self) = @_;

  my $output = "\x00" x $self->{length};

  _get_token($self->{ctx}, $self->{alphabet}, $output);

  return $output;
}


sub DESTROY {
  my ($self) = @_;

  _destroy_isaac_context($self->{ctx});
}


1;



__END__


=encoding utf-8

=head1 NAME

Session::Token - Secure, efficient, simple random session token generation


=head1 SYNOPSIS

=head2 Simple 128-bit session token

    my $token = Session::Token->new->get;
    ## 74da9DABOqgoipxqQDdygw

=head2 Keep generator around

    my $generator = Session::Token->new;

    my $token = $generator->get;
    ## bu4EXqWt5nEeDjTAZcbTKY

    my $token2 = $generator->get;
    ## 4Vez56Zc7el5Ggx4PoXCNL

=head2 Custom minimum entropy in bits

    my $token = Session::Token->new(entropy => 256)->get;
    ## WdLiluxxZVkPUHsoqnfcQ1YpARuj9Z7or3COA4HNNAv

=head2 Custom alphabet and length

    my $token = Session::Token->new(alphabet => 'ACGT', length => 100_000_000)->get;
    ## AGTACTTAGCAATCAGCTGGTTCATGGTTGCCCCCATAG...


=head1 DESCRIPTION

This module provides a secure, efficient, and simple interface for creating session tokens, password reset codes, temporary passwords, random identifiers, and anything else you can think of.

When a Session::Token object is created, 1024 bytes are read from C</dev/urandom> (Linux, Solaris, most BSDs), C</dev/arandom> (some older BSDs), or L<Crypt::Random::Source::Strong::Win32> (Windows). These bytes are used to seed the L<ISAAC-32|http://www.burtleburtle.net/bob/rand/isaacafa.html> pseudo random number generator.

Once a generator is created, you can repeatedly call the C<get> method on the generator object and it will return new tokens.

B<IMPORTANT>: If your application calls C<fork>, make sure that any generators are re-created in one of the processes after the fork since forking will duplicate the generator state and both parent and child processes will go on to produce identical tokens (just like perl's L<rand> after it is seeded).

After the generator context is created, no system calls are used to generate tokens. This is one way that Session::Token helps with efficiency. However, this is only important for certain use cases (generally not web sessions).

ISAAC is a cryptographically secure PRNG that improves on the well known RC4 algorithm in some important areas. For instance, it doesn't have short cycles like RC4 does. A theoretical shortest possible cycle in ISAAC is C<2**40>, although no cycles this short have ever been found (and probably don't exist at all). On average, ISAAC cycles are C<2**8295>.

Creators of server applications must choose whether a single generator will be kept around and used to generate all tokens, or if a new Session::Token object will be created every time a token is needed. Using a generator may be undesirable because servers start up early after a reboot and the kernel's randomness pool might be poorly seeded at this point. For this reason, you might want to defer creating the generator until the first request comes in and/or periodically re-create the generator object. 

There are good arguments for keeping the generator around, however. Probably the most important is that generating a new token cannot fail due to a full file descriptor table. Creating a new Session::Token object for every token can fail for this reason because the constructor opens C</dev/urandom>. Programs that re-use the generator are also more efficient and are less likely to cause problems in C<chroot>ed environments where C</dev/urandom> can no longer be opened.

Aside: Some crappy (usually C) programs that assume opening C</dev/urandom> will always succeed can return session tokens based only on the contents of nulled or uninitialised memory. Unix really ought to provide a system call for random data.



=head1 CUSTOM ALPHABETS

Being able to choose exactly which characters appear in your token is sometimes useful. This set of characters is called the I<alphabet>. B<The default alphabet size is 62 characters: uppercase letters, lowercase letters, and digits> (C<a-zA-Z0-9>).

For some purposes, base-62 is a sweet spot. It is more compact than hexadecimal encoding which helps with efficiency because session tokens are usually transfered over the network many times during a session (often uncompressed in HTTP headers).

Also, base-62 tokens don't use "wacky" characters like base-64 encodings do. These characters sometimes cause encoding/escaping problems (ie when embedded in URLs) and are annoying because often you can't select tokens by double-clicking on them.

Although the default is base-62, there are all kinds of reasons you might like to use another alphabet. One example is if your users are reading tokens from a print-out or SMS or whatever, you may choose to omit characters like C<o>, C<O>, and C<0> that can easily be confused.

To set a custom alphabet, just pass in either a string or an array of characters to the C<alphabet> parameter of the constructor:

    Session::Token->new(alphabet => '01')->get;
    Session::Token->new(alphabet => ['0', '1'])->get; # same thing
    Session::Token->new(alphabet => ['a'..'z'])->get; # character range

Constructor args can be a hash-ref too:

    Session::Token->new({ alphabet => ['a'..'z'] })->get;



=head1 ENTROPY

There are two ways to specify the length of tokens. The most primitive is in terms of characters:

    print Session::Token->new(length => 5)->get;
    ## -> wpLH4

But the primary way is to specify their minimum entropy in terms of bits:

    print Session::Token->new(entropy => 24)->get;
    ## -> Fo5SX

In the above example, the resulting token contains at least 24 bits of entropy. Given the default base-62 alphabet, we can compute the exact entropy of a 5 character token as follows:

    $ perl -E 'say 5 * log(62)/log(2)'
    29.7709815519344

So these tokens have about 29.8 bits of entropy. Note that if we removed one character from this token, it would bring it below our desired 24 bits of entropy:

    $ perl -E 'say 4 * log(62)/log(2)'
    23.8167852415475

B<The default minimum entropy is 128 bits.> Default tokens are 22 characters long and therefore have about 131 bits of entropy:

    $ perl -E 'say 22 * log(62)/log(2)'
    130.992318828511

An interesting observation is that in base-64 representation, 128-bit minimum tokens also require 22 characters and that these tokens contain only 1 more bit of entropy.

Another Session::Token design criterion is that all tokens should be the same length. The default token length is 22 characters and the tokens are always exactly 22 characters (no more, no less). This is nice because it makes writing matching regular expressions easier, simplifies storage (you never have to store length), and causes various log files and things to line up neatly on your screen. Instead of tokens that are exactly C<N> characters, some libraries that use arbitrary precision arithmetic end up creating tokens of I<at most> C<N> characters.

In summary, the default token length of exactly 22 characters is a consequence of these decisions: base-62 representation, 128 bit minimum token entropy, and consistent token length.



=head1 MOD BIAS

Some token generation libraries that implement custom alphabets will generate a random value, compute its modulus over the size of an alphabet, and then use this modulus to index into the alphabet to determine an output character.

Assume we have a uniform random number source that generates values in the set C<[0,1,2,3]> (most PRNGs provide sequences of bits, in other words power-of-2 size sets) and wish to use the alphabet C<"abc">.

If we use the naïve modulus algorithm described above then C<0> maps to C<a>, C<1> maps to C<b>, C<2> maps to C<c>, and C<3> I<also> maps to C<a>. This results in the following biased distribution for each character in the token:

    P(a) = 2/4 = 1/2
    P(b) = 1/4
    P(c) = 1/4

Of course in an unbiased distribution, each character would have the same chance:

    P(a) = 1/3
    P(b) = 1/3
    P(c) = 1/3

Bias is undesirable because certain tokens are obvious starting points when token guessing and certain other tokens are very unlikely. Tokens that are unbiased are equally likely and therefore there is no starting point with them.

Session::Token provides unbiased tokens regardless of the size of your alphabet (though see the L<INTRODUCING BIAS> section for a mis-use warning). It does this in the same way that you might simulate producing unbiased random numbers from 1 to 5 given an unbiased 6-sided die: Re-roll every time a 6 comes up.

In the above example, Session::Token eliminates bias by only using values of C<0>, C<1>, and C<2> (the C<t/no-mod-bias.t> test contains some more notes on this topic).

Note that mod bias can be made arbitrarily small by increasing the amount of data consumed from a random number generator (provided that arbitrary precision modulus is available). Because this module fundamentally avoids mod bias, it can use each of the 4 bytes from an ISAAC-32 word for a separate character (excepting "re-rolls").



=head1 EFFICIENCY OF RE-ROLLING

Throwing away a portion of random data in order to avoid mod bias is slightly inefficient. How many bytes from ISAAC do we expect to consume for every character in the token? It depends on the size of the alphabet.

Session::Token masks off each byte using the smallest power of two greater than or equal to the alphabet size minus one so the probability that any particular byte can be used is:

    P = alphabet_size / next_power_of_two(alphabet_size)

For example, with the default base-62 alphabet C<P> is C<62/64>.

In order to find the average number of bytes consumed for each character, calculate the expected value C<E>. There is a probability C<P> that the first byte will be used and therefore only one byte will be consumed, and a probability C<1 - P> that C<1 + E> bytes will be consumed:

    E = P*1 + (1 - P)*(1 + E)

    E = P + 1 + E - P - P*E

    0 = 1 - P*E

    P*E = 1

    E = 1/P

So for the default base-62 alphabet, the average number of bytes consumed for each character in a token is:

    E = 1/(62/64) = 64/62 ~ 1.0323

Because of the next power of two masking optimisation described above, C<E> will always be less than C<2>. In the worst case scenario of an alphabet with 129 characters, C<E> is roughly C<1.9845>.

This minor inefficiency isn't an issue because the ISAAC implementation used is quite fast and this module is very thrifty in how it uses ISAAC's output.



=head1 INTRODUCING BIAS

If your alphabet contains the same character two or more times, this character will be more biased than a character that only occurs once. You should be careful that your alphabets don't overlap if you are trying to create random session tokens.

However, if you wish to introduce bias this library doesn't try to stop you. (Maybe it should issue a warning?)

    Session::Token->new(alphabet => '0000001', length => 5000)->get; # don't do this
    ## -> 0000000000010000000110000000000000000000000100...

Due to a limitation discussed below, alphabets larger than 256 aren't currently supported so your bias can't get very granular.

Aside: If you have a constant-biased output stream like the above example produces then you can re-construct an un-biased bit sequence with the von neumann algorithm. This works by comparing pairs of bits. If the pair consists of identical bits, it is discarded. Otherwise the order of the different bits is used to determine an output bit, ie C<00> and C<11> are discarded but C<01> and C<10> are mapped to output bits of C<0> and C<1> respectively. This only works if the bias in each bit is constant (like all characters in a Session::Token are).



=head1 ALPHABET SIZE LIMITATION

Due to a limitation in this module's code, alphabets can't be larger than 256 characters. Everywhere the above manual says "characters" it actually means bytes. This isn't a Unicode limitation per se, just the maximum size of the alphabet. If you like, you can map tokens onto new alphabets as long as they aren't more than 256 characters long. Here is how to generate a 128-bit minimum entropy token using the lowercase greek alphabet (note that both forms of lowercase sigma are included which may not be desirable):

    use utf8;
    my $token = Session::Token->new(alphabet => [map {chr} 0..25])->get;
    $token = join '', map {chr} map {ord($_) + ord('α')} split //, $token;
    # ρφνδαπξδββφδοςλχτμγσψδψζειετ

Here's an interesting way to generate a uniform random integer between 0 to 999 inclusive:

    0 + Session::Token->new(alphabet => ['0'..'9'], length => 3)->get

If you wanted to natively support high code points, there is no point in hard-coding a limitation on the size of Unicode or some arbitrary machine word. Instead, arbitrary precision "characters" should be supported with L<bigint>. Here's an example of something similar in lisp: L<isaac.lisp|http://hcsw.org/downloads/isaac.lisp>.

This module is not however designed to be the ultimate random number generator and at this time I think changing the design as described above would interfere with its goal of being secure, efficient, and simple.




=head1 SEEDING

This module is designed to always seed itself from your kernel's secure random number source. You should never need to seed it yourself.

However if you know what you're doing you can pass in a custom seed as a 1024 byte long string. For example, here is how to create a "null seeded" generator:

    my $gen = Session::Token(seed => "\x00" x 1024);

This is done in the test-suite to compare against Jenkins' reference ISAAC output, but obviously don't do this in regular applications because the generated tokens will always be the same.

One valid reason for seeding is if you have some reason to believe that there isn't enough entropy in your kernel's randomness pool and therefore you don't trust C</dev/urandom>. In this case you should acquire your own seed data from somewhere trustworthy (maybe C</dev/random> or a previously stored trusted seed).




=head1 VARIABLE LENGTH TOKENS

As mentioned above, all tokens produced by a Session::Token generator are the same length. If you prefer tokens of variable length, it is possible to post-process the tokens in order to achieve this so long as you keep some things in mind.

If you randomly truncate tokens created by Session::Token, be careful not to introduce bias. For example, if you choose the length of the token as a uniformly distributed random length between 8 and 10, then the output will be biased towards shorter token sizes. Length 8 tokens should appear less frequently than length 9 or 10 tokens because there are fewer of them.

Another approach is to eliminate leading characters of a given value in the same way as leading C<0>s are eliminated from numeric representations. Although this approach doesn't introduce bias, the tokens C<1> and C<01> are not distinct so it does not increase token entropy given a fixed maximum token length which is the main reason for preferring variable length tokens. The ideal variable length algorithm would generate both C<1> and C<01> tokens (with identical frequency of course).

Implementing unbiased, variable-length tokens would complicate the Session::Token implementation especially since you should still be able to specify minimum entropy variable-length tokens. Minimum entropy is the primary input to Session::Token, not token length. This is the reason that the default token length of C<22> isn't hard-coded anywhere in the Session::Token source code (but C<128> is).




=head1 BUGS

Should check for biased alphabets and print warnings.

Would be cool if it could detect forks and warn or re-seed in the child process.

There is currently no way to extract the seed from a Session::Token object. Note when implementing this: The saved seed must either store the current state of the ISAAC round as well as the 1024 byte C<randsl> array or else do some kind of minimum fast forwarding in order to protect against a partially duplicated keystream bug.

Doesn't work on perl 5.6 and below due to the use of C<:raw> (thanks CPAN testers). It could probably use C<binmode> instead, but meh.



=head1 SEE ALSO

L<The Session::Token github repo|https://github.com/hoytech/Session-Token>

There are lots of different modules for generating random data. If the characterisations of any of them below are inaccurate or out-of-date, please file a github issue and I will correct them.

Like this module, perl's C<rand()> function implements a user-space PRNG seeded from C</dev/urandom>. However, perl's C<rand()> is not secure. Perl doesn't specify a PRNG algorithm at all. On linux, whatever it is is seeded with a mere 4 bytes from C</dev/urandom>.

L<Data::Token> is the first thing I saw when I looked around on CPAN. It has an inflexible and unspecified alphabet. It tries to get its source of unpredictability from UUIDs and then hashes these UUIDs with SHA-1. I think this is bad design because some standard UUID formats aren't designed to be unpredictable at all. Knowing a target's MAC address and the rough time the token was issued may help you predict a reduced area of token-space to concentrate guessing attacks upon. I don't know if Data::Token uses these types of UUIDs or the potentially secure "version 4" UUIDs, but because this wasn't addressed in the documentation and because of an apparent misapplication of hash functions (if you really had a good random UUID type, there would be no need to hash), I don't feel good about using this module.

There are several decent random number generators like L<Math::Random::Secure> and L<Crypt::URandom> but they usually don't implement alphabets and some of them require you open C</dev/urandom> for every chunk of random bytes. Note that Math::Random::Secure does prevent mod bias in its random integers and could be used to implement unbiased alphabets (slowly).

L<String::Random> is a cool module with a neat regexp-like language for specifying random tokens which is more flexible than alphabets. However, it uses perl's C<rand()> and the lack of performance, bias, and security discussion in the docs made me decide to not use this otherwise very interesting module.

L<String::Urandom> has alphabets, but it uses the flawed mod algorithm described above and opens C</dev/urandom> for every token.

There are other modules like L<Data::Random>, L<App::Genpass>, L<String::MkPasswd>, L<Crypt::RandPasswd>, L<Crypt::GeneratePassword>, and L<Data::SimplePassword> but they use C<rand()>/mersenne twister, don't adequately deal with bias, and/or don't let you specify generic alphabets.

L<Bytes::Random::Secure> has alphabets (aka "bags"), uses ISAAC, and avoids mod bias using the re-roll algorithm. However, it is much slower than this module (even when using L<Math::Random::ISAAC::XS>) and doesn't let you specify token-pool size by entropy. It does however support alphabets larger than C<256> and might work in environments without XS.

Neil Bowers has conducted a L<3rd party review|http://neilb.org/reviews/passwords.html> of various token/password generation modules including Session::Token.



=head1 AUTHOR

Doug Hoyte, C<< <doug@hcsw.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 Doug Hoyte.

This module is licensed under the same terms as perl itself.

ISAAC code:

    By Bob Jenkins.  My random number generator, ISAAC.  Public Domain

=cut




TODO

* Write a full file descriptor table test

* Make the urandom/arandom checking code more readable/maintainable

* Seed extractor API

* Issue warning when an alphabet contains a duplicated character
