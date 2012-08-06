package DR::StraMedia::SMS;

use 5.008008;
use strict;
use warnings;

use base 'Exporter';
use Carp;
use XML::LibXML;


our @EXPORT_OK = (
    'build_request', 'parse_response',
    'build_status_request', 'parse_status_response'
);

our @EXPORT = qw();

our $VERSION = '0.01';


=head1 NAME

DR::StraMedia::SMS - a module to send SMS through L<http://stramedia.ru/>

=head1 SYNOPSIS

    use DR::StraMedia::SMS;
    use AnyEvent::HTTP;
    my ($url, $body) = DR::StraMedia::SMS::build_request(
        from    => 'My Nagios',
        to      => '+7-123-45-67-89',
        text    => 'hello world'
    );

    http_post $url => $body, sub { ... };


=head1 DESCRIPTION

The module provides low-level interface for L<stramedia|http://stramedia.ru>

=head1 FUNCTIONS

=head2 build_request

builds request that can be sent to server.

=head3 Arguments

=over

=item from

A name or phone of sender.

=item to

Phone of receiver.

=item text

Text of message.

=item username & password

Access attributes to Your account of L<http://stramedia.ru>.

=item coding (latin|cyrillic|raw)

Format of text message. Optional argument. Default value is 'B<cyrillic>'.

=item priority (0 - 3)

Priority. Default value is B<0>.

=item type (sms|flash)

Type of message. Default value is 'B<sms>'.

=item defer MINUTES

Send the message after specified interval. Default value is B<0>.

=back

=cut

sub _add_tag($$;$) {
    my ($dom, $tag, $value) = @_;
    my $tag_t = XML::LibXML::Element->new($tag);
    $tag_t->appendText( $value ) if defined $value;
    $dom->addChild( $tag_t );
    return $tag_t;
}

sub build_request {
    my %opts = @_;
    my $from = $opts{from} || 'SMS-service';
    my $to   = $opts{to} || '';
    for ($to) {
        s/\D+//g;
        # some hacks for Russia
        $_ = "7$_" if 10 == length $_;
        s/^8(\d{10})$/7$1/;
    }

    my $username    = $opts{username};
    my $password    = $opts{password};
    my $defer       = $opts{defer} || 0;
    my $priority    = $opts{priority} || 0;
    my $coding      = $opts{coding} || 'cyrillic';
    my $type        = $opts{type} || 'sms';
    my $text        = $opts{text};

    croak 'wrong client phone' unless $to =~ /^\d{11,}$/;
    croak 'username was not defined' unless $username;
    croak 'password was not defined' unless $password;
    croak "wrong value for 'defer': $defer" unless $defer =~ /^\d+$/;
    croak "wrong priority=$priority" unless $priority =~ /^[0-3]$/;
    croak "wrong coding=$coding" unless $coding =~ /^(raw|cyrillic|latin)$/;
    croak "wrong type=$type" unless $type =~ /^(sms|flash)$/;
    croak "text of message was not defined" unless defined $text;


    if ($coding eq 'raw') {
        $coding = 1;
    } elsif ($coding eq 'latin') {
        $coding = 0;
    } else {
        $coding = 2;
    }


    my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
    my $msg_t = _add_tag $dom => 'message';

    _add_tag $msg_t => username     => $username;
    _add_tag $msg_t => password     => $password;
    _add_tag $msg_t => from         => $from;
    _add_tag $msg_t => to           => $to;
    _add_tag $msg_t => coding       => $coding;
    _add_tag $msg_t => text         => $text;
    _add_tag $msg_t => priority     => $priority;
    _add_tag $msg_t => mclass       => ($type eq 'sms') ? 1 : 0;
    _add_tag $msg_t => deferred     => $defer if $defer;

    return $dom->toString unless wantarray;
    return(
        'https://www.stramedia.ru/modules/xml_send_sms.php' => $dom->toString
    );
}



=head2 build_status_request

Builds request that can be used for checking status of message that was sent.

=head3 Arguments

=over

=item id

Id of message that was sent

=item username & password

Access attributes to Your account of L<http://stramedia.ru>.

=back

=cut

sub build_status_request {
    my (%opts) = @_;

    my $username    = $opts{username};
    my $password    = $opts{password};
    my $id          = $opts{id};

    croak 'username was not defined' unless $username;
    croak 'password was not defined' unless $password;
    croak 'id was not defined' unless $id;

    my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
    my $msg_t = _add_tag $dom => 'message';

    _add_tag $msg_t => username     => $username;
    _add_tag $msg_t => password     => $password;
    _add_tag $msg_t => id           => $id;

    return $dom->toString unless wantarray;
    return(
        'https://www.stramedia.ru/modules/xml_sms_status.php',
        $dom->toString
    );
}


=head2 parse_response

Parses response, returns hash with the following items:

=over

=item status => ok | error

Result of operation.

=item message

text of error (if status == error)

=item id

id of message that was sent

=back

=cut

sub parse_response {
    my ($resp) = @_;
    return { status => 'error', message => 'undefined response' }
        unless $resp;

    my $xml = eval { XML::LibXML->load_xml(string => $resp) };
    return { status => 'error', message => $@ || 'Can not parse XML' }
        unless defined $xml;

    my $msg = eval { $xml->getElementsByTagName('text')->shift->textContent };
    my $id = eval { $xml->getElementsByTagName('msg_ids')->shift->textContent };

    return {
        id          => $id,
        status      => 'ok',
        message     => $msg || 'ok'
    } if $id;
    return { status => 'error', message => $msg || 'Can not parse response' };
}


=head2 parse_status_response

Parses status response, returns hash with the following items:

=over

=item status => ok | error

Result of operation.

=item message

text of error (if status == error)

=item code

code of message status.

=over

=item 0

Message was sent to gate

=item 1

Message was delivered

=item 2

Client's phone refused message

=item 4

Message is in provider's queue

=item 8

Provider accepted message

=item 16

Provider refused message

=item 32

Gate refused message

=back

=back

=cut

sub parse_status_response {
    my ($resp) = @_;
    return { status => 'error', message => 'undefined response' }
        unless $resp;

    my $xml = eval { XML::LibXML->load_xml(string => $resp) };
    return { status => 'error', message => $@ || 'Can not parse XML' }
        unless defined $xml;

    my $time = eval {
        $xml->getElementsByTagName('update_time')->shift->textContent
    };
    my $id = eval { $xml->getElementsByTagName('id')->shift->textContent };
    my $code = eval {
        $xml->getElementsByTagName('status')->shift->textContent
    };

    my %msgs = (
        0       => 'Message was sent to gate',
        1       => 'Message was delivered',
        2       => "Client's phone refused message",
        4       => "Message is in provider's queue",
        8       => "Provider accepted message",
        16      => "Provider refused message",
        32      => "Gate refused message",
    );

    if ($id and defined $code) {
        my $msg = $msgs{ $code };
        $msg = "Unknown status message, code=$code" unless defined $msg;

        return {
            id          => $id,
            status      => 'ok',
            code        => $code,
            message     => $msg
        };
    }

    my $msg = eval { $xml->getElementsByTagName('text')->shift->textContent };

    return { status => 'error', message => $msg || 'Can not parse response' };
}

1;
