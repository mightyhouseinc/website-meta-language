#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Path::Tiny qw/ cwd path tempdir /;

# Remove WML_TEST_BUILD so we won't run the tests with infinite recursion.
if ( !delete( $ENV{'WML_TEST_BUILD'} ) )
{
    plan skip_all => "Skipping because WML_TEST_BUILD is not set";
}

plan tests => 7;

# Change directory to the Freecell Solver base distribution directory.
my $src_path = path($0)->parent(3)->absolute;

sub test_cmd
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $cmd, $blurb ) = @_;

    # These environment variables confuse the input for the harness.
    my $sys_ret = do
    {
        local %ENV = %ENV;
        delete( $ENV{HARNESS_VERBOSE} );

        system(@$cmd);
    };

    if ( !ok( !$sys_ret, $blurb ) )
    {
        Carp::confess( "Command ["
                . join( " ", ( map { qq/"$_"/ } @$cmd ) )
                . "] failed! $!." );
    }
}

{
    my $temp_dir        = tempdir( TEMPLATE => 'wml-build-process--XXXXXXXX' );
    my $before_temp_cwd = cwd;

    chdir($temp_dir);

    # TEST
    test_cmd( [ "cmake", $src_path ], "cmake succeeded" );

    # TEST
    test_cmd( [ "make", "all" ], "make all is successful" );
    {
        open my $in, "man ./wml_frontend/wmk.1 | cat |"
            or die "Cannot open $! !";
        local $/;
        my $text = <$in>;

        # TEST
        unlike( $text, qr/\@WML_VERSION/, "WML_VERSION was expanded" );
    }

    # TEST
    test_cmd( [ "make", "package_source" ],
        "make package_source is successful" );

    my ($version) =
        map { /\ASET *\( *VERSION *"([0-9\.]+)" *\)\z/ ? ($1) : () }
        $src_path->child("CMakeLists.txt")->lines_utf8( { chomp => 1 } );

    my $base     = "wml-$version";
    my $tar_arc  = "$base.tar";
    my $arc_name = "$tar_arc.xz";

    # The code starting from here makes sure we can run "make package_source"
    # inside the freecell-solver-$X.$Y.$Z/ directory generated by the unpacked
    # archive. So we don't have to rename it.

    # TEST
    test_cmd( [ "tar", "-xf", $arc_name ], "Unpacking the arc name" );

    # TEST
    ok( scalar( -d $base ), "The directory was created" );

    chdir($base);
    mkdir("build");
    chdir("build");

    local $ENV{WML_TEST_QUIET} = 1;

    # TEST
    test_cmd( [ $^X, "../wml_test/run_test.pl" ] );

    # For cleanup of the temp_dir.
    chdir($before_temp_cwd);
}

__END__

=head1 COPYRIGHT AND LICENSE

This file is part of Freecell Solver. It is subject to the license terms in
the COPYING.txt file found in the top-level directory of this distribution
and at http://fc-solve.shlomifish.org/docs/distro/COPYING.html . No part of
Freecell Solver, including this file, may be copied, modified, propagated,
or distributed except according to the terms contained in the COPYING file.

Copyright (c) 2009 Shlomi Fish

=cut
