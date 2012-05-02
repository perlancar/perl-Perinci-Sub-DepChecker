package Perinci::Sub::DepChecker;

use 5.010;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(check_deps);

# VERSION

sub check_deps {
    my ($val) = @_;
    #say "D:check: ", dump($val);
    while (my ($dname, $dval) = each %$val) {
        return "Unknown dependency type: $dname"
            unless defined &{"checkdep_$dname"};
        my $check = \&{"checkdep_$dname"};
        my $res = $check->($dval);
        if ($res) {
            $res = "$dname: $res";
            return $res;
        }
    }
    "";
}

sub checkdep_all {
    my ($val) = @_;
    #say "D:check_all: ", dump($val);
    for (@$val) {
        my $res = check_deps($_);
        return "Some dependencies not met: $res" if $res;
    }
    "";
}

sub checkdep_any {
    my ($val) = @_;
    my $nfail = 0;
    for (@$val) {
        return "" unless check_deps($_);
        $nfail++;
    }
    $nfail ? "None of the dependencies are met" : "";
}

sub checkdep_none {
    my ($val) = @_;
    for (@$val) {
        my $res = check_deps($_);
        return "A dependency is met when it shouldn't: $res" unless $res;
    }
    "";
}

sub checkdep_env {
    my ($cval) = @_;
    $ENV{$cval} ? "" : "Environment variable $cval not set/true";
}

sub checkdep_code {
    my ($cval) = @_;
    $cval->() ? "" : "code doesn't return true value";
}

sub checkdep_prog {
    my ($cval) = @_;

    if ($cval =~ m!/!) {
        return "Program $cval not executable" unless (-x $cval);
    } else {
        require File::Which;
        return "Program $cval not found in PATH"
            unless File::Which::which($cval);
    }
    "";
}

# for backward-compatibility
sub checkdep_exec { checkdep_prog(@_) }

1;
# ABSTRACT: Check dependencies from 'deps' property

=head1 SYNOPSIS

 use Perinci::Spec::DepChecker qw(check_deps dep_must_be_satisfied);

 my $err = check_deps($meta->{deps});
 print "Dependencies not met: $err" if $err;

 print "Dep foo must be satisfied"
     if dep_must_be_satisfied('foo', $meta->{deps});

=head1 DESCRIPTION

The 'deps' spec clause adds information about subroutine dependencies. This
module performs check on it.

This module is mainly used by L<Perinci::Sub::Wrapper>.


=head1 FUNCTIONS

None is exported by default, but every function is exportable.

=head2 check_deps($deps_clause) => ERRSTR

Check dependencies. Will in turn call various C<checkdep_NAME()> subroutines.
Return empty string if all dependencies are met, or a string containing an error
message stating a dependency error.

Example:

 my $err = check_deps({env=>'DEBUG'});

Will check environment variable C<DEBUG>. If true, will return an empty string.
Otherwise will set $err with something like C<Environment variable DEBUG not
set/true>.

Another example:

 my $err = check_deps({ all=>[{env=>"A"}, {env=>"B", prog=>"bc"}] });

The above will check environment variables C<A>, C<B>, as well as program C<bc>.
All dependencies must be met (because we use the C<and> metaclause).

To support a custom dependency named C<NAME>, just define C<checkdep_NAME>
subroutine in L<Perinci::Sub::DepChecker> package which accepts a value and
should return an empty string on success or an error message string.


=head1 SEE ALSO

L<Perinci>

'deps' section in L<Rinci::function>

=cut
