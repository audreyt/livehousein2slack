#!/usr/bin/env perl
use utf8;
use 5.12.0;
use JSON;
use Furl;
use File::Slurp qw[ read_file write_file ];

binmode STDOUT, ':utf8'; $|++;

my $ascii_only = 1;
my $furl = Furl->new( agent => 'MyGreatUA/2.0', timeout => 10,);

my $channel = shift or die "Usage: perl $0 livehouse_channel_name";
my $webhook = read_file('webhook.url') or die "Please set up incoming webhook and store it in a 'webhook.url' file";
my $lastFetch = -e "$channel.lastFetch" ? read_file("$channel.lastFetch") : '0';
my $lastMessage = -e "$channel.lastMessage" ? read_file("$channel.lastMessage") : '';
chomp($webhook, $lastFetch, $lastMessage);

while (1) {
    my $ts = time;
    print "$ts\r";
    my @messages;
    eval { @messages = @{ (decode_json($furl->get(qq[https://rest-message-10.livehouse.in/get-messages-by-chat-public?channelCode=$channel&actingPartner=tf&oldestDate=$lastFetch])->content) || {messages => []})->{messages} } };
    for my $msg (reverse @messages) {
        next if $msg->{createdDate} le $lastMessage;
        say "$msg->{creator}{name}: $msg->{text}";
        my $emoji = '';
        if ($msg->{text} =~ /[!！]\s*$/) {
            $emoji = ':exclamation:';
        }
        elsif ($msg->{text} =~ /[\?？]\s*$/) {
            $emoji = ':question:';
        }
        elsif ($msg->{text} =~ /喜歡|愛/) {
            $emoji = ':heart';
        }
        elsif ($msg->{text} =~ /認為|想|覺得/) {
            $emoji = ':thought_balloon:';
        }
        elsif ($msg->{text} =~ /讚|\+1|\+\+|贊/) {
            $emoji = ':thumbsup:';
        }
        elsif ($msg->{text} =~ /噓|\-1|\-\-/) {
            $emoji = ':thumbsdown';
        }
        elsif ($msg->{text} =~ /^\s*我/) {
            $emoji = ':hand:';
        }
        my $payload = to_json({
            username => $msg->{creator}{name},
            icon_url => $msg->{creator}{avatar},
            icon_emoji => $emoji || {
                WEB => ':globe_with_meridians:',
                IOS => ':apple',
                ANDROID => ':robot_face:',
            }->{$msg->{sourceType}} || ':question:',
            text => $msg->{text}
        }, { ascii => $ascii_only });
        $furl->post($webhook, [], [ payload => $payload ]);
        $lastMessage = $msg->{createdDate};
        write_file("$channel.lastMessage" => $lastMessage);
    }
    $lastFetch = $ts . '00';
    write_file("$channel.lastFetch" => $lastFetch);
    sleep 1;
}
