package Test::Email;
use strict;
use warnings;

use Test::Builder;
use MIME::Parser;
use Carp 'croak';

use base 'MIME::Entity';

our $VERSION = '0.07';

my $TEST = Test::Builder->new();

my $DEBUG = 0;
# for quietly failing .t tests which we expect to fail
$Test::Email::QUIET_DIAG = 0;

sub ok {
    my ($self, $test_href, $desc) = @_;

    my $pass = $self->_run_tests($test_href);
    
    my $ok = $TEST->ok($pass, $desc);

    return $ok;
}

sub header_ok {
    my ($self, $header_name, $argument, $description) = @_;

    my $value = $self->head()->get($header_name);
    chomp($value);

    my $pass = $TEST->ok($value eq $argument, $description);

    return $pass;
}

sub header_like {
    my ($self, $header_name, $argument, $description) = @_;

    my $value = $self->head()->get($header_name);
    chomp($value);

    my $pass = $TEST->like($value, $argument, $description);

    return $pass;
}

sub header_is {
    my ($self, $header_name, $argument, $description) = @_;

    my $value = $self->head()->get($header_name);
    chomp($value);

    my $pass = $TEST->is_eq($value, $argument, $description);

    return $pass;
}

sub body_ok {
    my ($self, $argument, $description) = @_;

    my $body = join '', @{ $self->body() };

    $body =~ s/\n+$//;
    $argument  =~ s/\n+$//;

    my $pass = $TEST->ok($body eq $argument, $description);

    return $pass;
}

sub body_like {
    my ($self, $argument, $description) = @_;

    my $body = join '', @{ $self->body() };

    $body =~ s/\n+$//;
    $argument  =~ s/\n+$//;

    my $pass = $TEST->like($body, $argument, $description);

    return $pass;
}

sub body_is {
    my ($self, $argument, $description) = @_;

    my $body = join '', @{ $self->body() };

    $body =~ s/\n+$//;
    $argument  =~ s/\n+$//;

    my $pass = $TEST->is_eq($body, $argument, $description);

    return $pass;
}

sub parts_ok {
    my ($self, $part_count, $description) = @_;

    my $pass = $TEST->is_num($part_count, scalar($self->parts()), $description);

    return $pass;
}

sub mime_type_ok {
    my ($self, $type, $description) = @_;

    my $pass = $TEST->is_eq($type, $self->mime_type(), $description);

    return $pass;
}

# run all tests against this email, return success
sub _run_tests {
    my ($self, $test_href) = @_;
    
    for my $key (keys %$test_href) {
        my $passed = $self->_test($key, $test_href->{$key});
        if (!$passed) {
            return 0;
        }
    }

    return 1;
}

my %test_for = (
    header  =>  \&_test_header,
    body    =>  \&_test_body,
);

# perform one test against one email
sub _test {
    my ($self, $key, $test) = @_;

    _debug("in _test($self, $key, $test)");

    if (my $test_cref = $test_for{$key}) {
        return $test_cref->($self, $test);
    }
    else {
        return $test_for{header}->($self, $key, $test);
    }
}

sub _test_header {
    my ($self, $header, $test) = @_;

    _debug("in _test_header($self, $header, $test)");

    my $value = $self->head()->get($header) || '';
    chomp($value);

    return _do_test($value, $test, $header);
}

sub _test_body {
    my ($self, $test) = @_;

    _debug("in _test_body($self, $test)");

    my $body = join '', @{ $self->body() };
    return _do_test($body, $test, 'body');
}

sub _do_test {
    my ($thing, $test, $what) = @_;

    _debug("Testing '$thing' against $test");

    my $type = ref $test;
    if ($type eq 'Regexp') {
        my $ret = $thing =~ $test;
        if (!$ret && !$Test::Email::QUIET_DIAG) {
            $TEST->diag("Email $what:");
            $TEST->diag(sprintf <<DIAGNOSTIC, $thing, "doesn't match", $test);
                  %s
    %13s '%s'
DIAGNOSTIC
        }
        return $ret;
    }
    elsif ($type eq '') {
        $thing =~ s/\n+$//;
        $test  =~ s/\n+$//;
        my $ret = $thing eq $test;
        if (!$ret && !$Test::Email::QUIET_DIAG) {
            $TEST->diag("Email $what:");
            $TEST->_is_diag($thing, 'eq', $test);
        }
        return $ret;
    }
    else {
        croak "I don't know how to test for this type: '$type'";
    }
}

sub _debug {
    my ($msg) = @_;
    warn $msg."\n" if $DEBUG;
}

1;
__END__

=head1 NAME

Test::Email - Test Email Contents

=head1 SYNOPSIS

  use Test::Email;

  # is-a MIME::Entity
  my $email = Test::Email->new(\@lines);

  # all-in-one test
  $email->ok({
    # optional search parameters
    from       => ($is or qr/$regex/),
    subject    => ($is or qr/$regex/),
    body       => ($is or qr/$regex/),
    headername => ($is or qr/$regex/),
  }, "passed tests");

  # single-test header methods
  $email->header_is($header_name, $value, "$header_name matches");
  $email->header_ok($header_name, $value, "$header_name matches");
  $email->header_like($header_name, qr/regex/, "$header_name matches");

  # single-test body methods
  $email->body_is($header_name, $value, "$header_name matches");
  $email->body_ok($header_name, $value, "$header_name matches");
  $email->body_like($header_name, qr/regex/, "$header_name matches");

  # how many MIME parts does the messages contain?
  $email->parts_ok($parts_count, "there were $parts_count parts found");

  # what is the MIME type of the firs part
  my @parts = $email->parts(); # see MIME::Entity
  $parts[0]->mime_type_ok('test/html', 'the first part is type text/html');

=head1 DESCRIPTION

Please note that this is ALPHA CODE. As such, the interface is likely to
change.

Test::Email is a subclass of MIME::Entity, with the above methods.
If you want the messages fetched from a POP3 account, use Test::POP3.

Tests for equality remove trailing newlines from strings before testing.
This is because some mail messages have newlines appended to them during
the mailing process, which could cause unnecessary confusion.

This module should be 100% self-explanatory. If not, then please look at
L<Test::Simple> and L<Test::More> for clarification.

=head1 METHODS

=over

=item C<my $email = Test::Email-E<gt>new($lines_aref);>

This is identical to C<MIME::Entity-E<gt>new()>. See there for details.

=item C<$email-E<gt>ok($test_href, $description);>

Using this method, you can test multiple qualities of an email message
with one test. This will execute the tests as expected and will produce
output just like C<Test::Simple::ok> and C<Test::More::ok>. Keys for
C<$test_href> are either C<body>, or they are considered to be the name
of a header, case-insensitive.

=item single-test methods

The single-test methods in the synopsis above are very similar to their
counterparts in L<Test::Simple> and L<Test::More>. Please consult those
modules for documentation.

Please note that tests for equality remove newlines from their operands
before testing. This is because some email messages have newlines appended
to them during mailing.

=item C<my $ok = $email->parts_ok($parts_count, $description);>

Check to see how many MIME parts this email contains. Each part is also a
Test::Email object.

=item C<my $ok = $email->mime_type_ok($expected_mime_type, $description);>

Check the MIME type of an email or an email part.

=back

=head1 EXPORT

None.

=head1 SEE ALSO

L<Test::Builder>, L<Test::Simple>, L<Test::More>, L<Test::POP3>

=head1 TODO

I am open to suggestions.

=head1 AUTHOR

James Tolley, E<lt>james@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2008 by James Tolley

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
