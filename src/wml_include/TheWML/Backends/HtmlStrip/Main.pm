##  htmlstrip -- Strip HTML markup code
##  Copyright (c) 1997-2000 Ralf S. Engelschall, All Rights Reserved.
##  Copyright (c) 2000 Denis Barbier

package TheWML::Backends::HtmlStrip::Main;

use strict;
use warnings;

use Class::XSAccessor (
    constructor => 'new',
    accessors   => +{
        map { $_ => $_ }
            qw(
            argv
            opt_O
            opt_b
            opt_o
            opt_v
            )
    },
);

use Getopt::Long;

#
#   process command line
#
sub usage
{
    print STDERR "Usage: htmlstrip [options] [file]\n";
    print STDERR "\n";
    print STDERR "Options:\n";
    print STDERR
        "  -o, --outputfile=<file>   set output file instead of stdout\n";
    print STDERR "  -O, --optimize=<level>    set optimization/crunch level\n";
    print STDERR "  -v, --verbose             verbose mode\n";
    die;
}

sub verbose
{
    my ( $self, $str ) = @_;
    if ( $self->opt_v )
    {
        print STDERR "** HTMLstrip:Verbose: $str\n";
    }
}

sub error
{
    my ($str) = @_;
    die "** HTMLstrip:Error: $str\n";
}

#
#   read input file
#
use TheWML::Backends;

#
#   stripping functions for particular areas
#

sub _nexttoken
{
    my ($buf) = @_;
    my ( $token, $bufN );

    if ( $buf =~ m|^([^<]+?)(<.+)$|s )
    {
        $token = $1;
        $bufN  = $2;
    }
    elsif ( $buf =~ m|^(<[^>]+>)(.*)$|s )
    {
        $token = $1;
        $bufN  = $2;
    }
    else
    {
        $token = $buf;
        $bufN  = '';
    }

    if ( length($token) > 80 )
    {
        my $x = substr( $token, 0, 80 );
        my $i = rindex( $x, ' ' );
        my $bufN = substr( $token, $i ) . $bufN;
        $token = substr( $token, 0, $i );
    }
    return ( $token, $bufN );
}

#   Strip Plain Text, i.e. outside of any
#   preformatted area and outside any HTML tag.
sub _strip_plain_text
{
    my ( $self, $buf ) = @_;

    #   Level 0
    #if ($self->opt_O >= 0) {
    #}
    #   Level 1
    if ( $self->opt_O >= 1 )
    {
        #   strip empty lines
        $buf =~ s|\n\s*\n|\n|sg;
    }

    #   Level 2
    if ( $self->opt_O >= 2 )
    {
        #   strip multiple whitespaces to single one
        $buf =~ s|(\S+)[ \t]{2,}|$1 |sg;

        #   strip trailing whitespaces
        $buf =~ s|\s+\n|\n|sg;
    }

    #   Level 3
    if ( $self->opt_O >= 3 )
    {
        #   strip leading whitespaces
        $buf =~ s|\n\s+|\n|sg;
    }

    #   Level 4
    if ( $self->opt_O >= 4 )
    {
        #   strip empty lines again
        $buf =~ s|^\s*$||mg;
        $buf =~ s|\n\n|\n|sg;
    }

    #   Level 5
    if ( $self->opt_O >= 5 )
    {
        #   concatenate all lines
        $buf =~ s|\n| |sg;
        #
        my $from = $buf;
        my $line = '';
        $buf = '';
        while ( length($from) > 0 )
        {
            my ( $token, $from ) = _nexttoken($from);
            if ( ( length($line) + length($token) ) < 80 )
            {
                $line .= $token;
            }
            else
            {
                $buf .= $line . "\n";
                $line = $token;
            }
        }
        $buf =~ s|^\s+||mg;
        $buf =~ s|\s+$||mg;
    }

    return $buf;
}

#   Strip HTML Tag, i.e. outside of any
#   preformatted area but inside a HTML tag.
sub _strip_html_tag
{
    my ( $self, $buf ) = @_;

    #   Level 0
    #if ($self->opt_O >= 0) {
    #}
    #   Level 1
    #if ($self->opt_O >= 1) {
    #}
    #   Level 2
    if ( $self->opt_O >= 2 )
    {
        #   strip multiple whitespaces to single one
        $buf =~ s|(\S+)[ \t]{2,}|$1 |mg;

        #   strip trailing whitespaces at end of line
        $buf =~ s|\s+\n|\n|sg;

        #   strip whitespaces between attribute name and value
        $buf =~ s|([ \t]+[a-zA-Z][a-zA-Z0-9_]*)\s*=\s*|$1=|sg;

        #   strip whitespaces before tag end
        $buf =~ s|[ \t]+>$|>|sg;
    }

    #   Level 3
    #if ($self->opt_O >= 3) {
    #}
    #   Level 4
    if ( $self->opt_O >= 4 )
    {
        #   strip HTML comments
        $buf =~ s|<!--.+?-->||sg;

        #   strip newlines before tag end
        $buf =~ s|\n>$|>|sg;
    }

    #   Level 5
    #if ($self->opt_O >= 5) {
    #}

    return $buf;
}

#   Strip Preformatted Areas, i.e.  inside
#   <pre>, <xmp> and <nostrip> container tags.
sub _strip_preformatted
{
    my ( $self, $buf ) = @_;

    #   Level 0
    #if ($self->opt_O >= 0) {
    #}
    #   Level 1
    #if ($self->opt_O >= 1) {
    #}
    #   Level 2
    if ( $self->opt_O >= 2 )
    {
        #   strip trailing whitespaces on non-empty lines
        $buf =~ s|\S\K[ \t]+\n|\n|sg;
    }

    #   Level 3
    #if ($self->opt_O >= 3) {
    #}
    #   Level 4
    #if ($self->opt_O >= 4) {
    #}
    #   Level 5
    #if ($self->opt_O >= 5) {
    #}

    return $buf;
}

sub _strip_non_preformatted
{
    my ( $self, $I ) = @_;

    my $O = '';
    while ( $I =~ s|^(.*?)(<.+?>)||s )
    {
        my ( $text, $tag ) = ( $1, $2 );
        $O .= $self->_strip_plain_text($text) . $self->_strip_html_tag($tag);
    }
    $O .= $self->_strip_plain_text($I);
    return $O;
}

sub _append_non_preformat
{
    my ( $self, $out, $in ) = @_;

    my $o = $self->_strip_non_preformatted($in);
    $o =~ s|\A\n||s if $$out =~ m|\n\z|s;
    $$out .= $o;

    return;
}

my %TAGS = (
    "nostrip" => 1,
    "pre"     => 0,
    "xmp"     => 0,
);

# On large files, benchmarking show that most of the time is spent
# here because of the complicated regexps.  To minimize memory usage
# and CPU time, input is splitted into small chunks whose size may
# be changed by the -b flag.
sub _main_loop
{
    my ( $self, $input ) = @_;

    my $output    = '';
    my $chunksize = $self->opt_b;
    my $loc       = 0;
    my $run_once  = 1;
    while ( $run_once || $input )
    {
        $run_once = 0;

        my $NEXT = '';
        if (   $chunksize > 0
            && $chunksize < 32767
            && length($input) > $chunksize )
        {
            $NEXT = substr( $input, $chunksize );
            $input = substr( $input, 0, $chunksize );
        }

    PROCESS:
        while (1)
        {
            #   look for a begin tag
            my $len = length($input);
            my $pos = $len;
            my $tagname;
            my $epilog;
            my $prolog;
            my $curtag;
            foreach my $tag ( keys(%TAGS) )
            {

                if ( my ( $pro, $tag_body, $epi ) =
                    $input =~ m|\A(.*?)(<$tag(?:\s+[^>]*)?>)(.*)\z|is )
                {
                    my $n = length($pro);
                    if ( $n < $pos )
                    {
                        $pos     = $n;
                        $prolog  = $pro;
                        $curtag  = $tag_body;
                        $epilog  = $epi;
                        $tagname = $tag;
                    }
                }
            }
            if ( $pos < $len )
            {
                my $str = sprintf "found $curtag at position %d", $loc + $pos;
                $self->verbose($str);
                $self->_append_non_preformat( \$output, $prolog );

                my ( $body, $endtag );

                #   if end tag not found, extend string
                if ( $epilog =~ s|^(.*?)(</$tagname>)||is )
                {
                    $body   = $1;
                    $endtag = $2;
                }
                else
                {
                    $input = $curtag . $epilog . $NEXT;
                    $chunksize += $self->opt_b;
                    last PROCESS;
                }

                $str = sprintf "found $endtag at position %d",
                    $loc + $pos + length($body);
                $self->verbose($str);
                $output .= $curtag if ( not $TAGS{$tagname} );
                $output .= $self->_strip_preformatted($body);
                $output .= $endtag if ( not $TAGS{$tagname} );
                $loc += $pos + length($body) + length($curtag);
                $input = $epilog;
                next PROCESS;
            }
            else
            {
                if ( $input =~ m|^(.+)(<.*)$|s )
                {
                    $loc += length($1);
                    $input = $2;
                    $self->_append_non_preformat( \$output, $1 );
                }
                if ($NEXT)
                {
                    if ( length($input) < $chunksize )
                    {
                        $chunksize = $self->opt_b;
                    }
                    else
                    {
                        $chunksize += $self->opt_b;
                    }
                    $input .= $NEXT;
                }
                else
                {
                    $self->_append_non_preformat( \$output, $input );
                    $input = '';
                }
                last PROCESS;
            }
        }
        if ( $NEXT eq '' )
        {
            $output .= $input;
            $input = '';
        }
    }

    return $output;
}

sub main
{
    my ($self) = @_;
    $self->opt_v(0);
    $self->opt_o('-');
    $self->opt_O(2);
    $self->opt_b(16384);
    $Getopt::Long::bundling      = 1;
    $Getopt::Long::getopt_compat = 0;
    if (
        not Getopt::Long::GetOptionsFromArray(
            $self->argv,
            "v|verbose"     => sub { my ( undef, $v ) = @_; $self->opt_v($v); },
            "O|optimize=i"  => sub { my ( undef, $v ) = @_; $self->opt_O($v); },
            "b|blocksize=i" => sub { my ( undef, $v ) = @_; $self->opt_b($v); },
            "o|outputfile=s" =>
                sub { my ( undef, $v ) = @_; $self->opt_o($v); },
        )
        )
    {
        usage();
    }
    $self->opt_b(32766) if $self->opt_b > 32766;
    $self->opt_b(1024) if ( $self->opt_b > 0 and $self->opt_b < 1024 );

    my $input = TheWML::Backends->input( $self->argv, \&error, \&usage );

    #
    #   global initial stripping
    #

    $self->verbose("Strip sharp-like comments");

    #   strip sharp-like comments
    #$input =~ s|^\s*#.*$||mg;
    $input =~ s/\A(?:(?:[ \t]*)#[^\n]*\n)+//s;    # special  case: at begin
    $input =~ s/\n[ \t]*#[^\n]*(?=\n)//sg;        # standard case: in the middle
    $input =~ s/\n[ \t]*#[^\n]*\n?$/\n/s;         # special  case: at end
    $input =~ s/^([ \t]*)\\(#)/$1$2/mg;           # remove escaping backslash
                                                  #
                                                  #   Processing Loop
                                                  #

    $self->verbose("Main processing");
    my $output = $self->_main_loop($input);

    #
    #   global final stripping
    #
    $self->verbose("Fix <suck> special command");
    $output =~ s|\s*<suck(\s*/)?>\s*||isg;
    $output =~ s|^\n||s;

    TheWML::Backends->out( $self->opt_o, \&error, [$output] );
    return;
}

1;

# __END__
# # Below is stub documentation for your module. You'd better edit it!