package Sub::Spec::Clause::deps;
# ABSTRACT: Specify subroutine dependencies

use 5.010;
use strict;
use warnings;

#use Data::Dump qw(dump);


sub check {
    my ($val) = @_;
    #say "D:check: ", dump($val);
    while (my ($cname, $cval) = each %$val) {
        return "Unknown dependency clause: $cname"
            unless $Sub::Spec::Clause::deps::{"check_$cname"};
        no strict 'refs';
        my $check = \&{"check_$cname"};
        my $res = $check->($cval);
        if ($res) {
            $res = "$cname: $res";
            return $res;
        }
    }
    "";
}

sub check_all {
    my ($cval) = @_;
    #say "D:check_all: ", dump($cval);
    for (@$cval) {
        my $res = check($_);
        return "Some dependency not met: $res" if $res;
    }
    "";
}

sub check_any {
    my ($cval) = @_;
    my $nfail = 0;
    for (@$cval) {
        return "" unless check($_);
        $nfail++;
    }
    $nfail ? "None of the dependencies are met" : "";
}

sub check_none {
    my ($cval) = @_;
    for (@$cval) {
        my $res = check($_);
        return "A dependency is met when it shouldn't: $res" unless $res;
    }
    "";
}

sub check_mod {
    my ($cval) = @_;
    my $m = $cval;
    $m =~ s!::!/!g;
    $m .= ".pm";
    #eval { require $m } ? "" : "Can't load module $cval: $@";
    eval { require $m } ? "" : "Can't load module $cval";
}

sub check_sub {
    my ($cval) = @_;
    my ($pkg, $name);
    if ($cval =~ /(.*)::(.+)/) {
        $pkg = $1 || "main";
        $name = $2;
    } else {
        $pkg = "main";
        $name = $cval;
    }
    no strict 'refs';
    my $stash = \%{"$pkg\::"};
    $stash->{$name} ? "" : "Subroutine $cval doesn't exist";
}

sub check_env {
    my ($cval) = @_;
    $ENV{$cval} ? "" : "Environment variable $cval not set/true";
}

sub check_code {
    my ($cval) = @_;
    $cval->() ? "" : "code doesn't return true value";
}

sub check_exec {
    my ($cval) = @_;

    if ($cval =~ m!/!) {
        return "Executable $cval not available" unless (-x $cval);
    } else {
        require File::Which;
        return "$cval not found in PATH" unless File::Which::which($cval);
    }
    "";
}

1;


=pod

=head1 NAME

Sub::Spec::Clause::deps - Specify subroutine dependencies

=head1 VERSION

version 1.0.1

=head1 SYNOPSIS

In your spec:

 deps => {
     DEPCLAUSE => DEPVALUE,
     ...,
     all => [
         {DEPCLAUSE=>DEPVALUE, ...},
         ...,
     },
     any => [
         {DEPCLAUSE => DEPVALUE, ...},
         ...,
     ],
     none => [
         {DEPCLAUSE => DEPVALUE, ...},
         ....,
     ],
 }

=head1 DESCRIPTION

The 'deps' clause adds information about subroutine dependency. It is extensible
so you can specify anything as a dependency, be it another subroutine, Perl
version and modules, environment variables, etc. It is up to some implementor to
make use of this information.

The 'deps' clause is used, for example, by L<Sub::Spec::Runner> to run
subroutine in dependency order.

Dependencies are specified as a hash of clauses:

 {
    DEPCLAUSE     => DEPVALUE,
    ANOTHERCLAUSE => VALUE,
    ...
  }

All of the clauses must be satisfied in order for the dependencies to be
declared a success.

Below is the list of defined dependency clauses. New dependency clause may be
defined by providing Sub::Spec::Clause::deps::check_<CLAUSE>().

=head2 sub => STR

Require that subroutine exists. STR is the name of the subroutine and will be
assumed to be in the 'main' package if unqualified.

Example:

 sub => 'foo'   # == main::foo
 sub => '::foo' # == main::foo
 sub => 'Package::foo'

=head2 mod => STR

Require that module is loadable. Example:

 mod => 'Moo'

=head2 env => STR

Require that an environment variable exists and has a true value. Example:

 env => 'HTTPS'

=head2 exec => STR

Require that an executable exists. If STR doesn't contain path separator
character '/' it will be searched in PATH.

 exec => 'rsync'   # any rsync found on PATH
 exec => '/bin/su' # won't accept any other su

=head2 code => CODEREF

Require that CODEREF returns a true value after called. Example:

 code => sub {$>}  # i am not being run as root

=head2 all => [DEPCLAUSES, ...]

A "meta" clause that allows several dependencies to be joined together in a
logical-AND fashion. All dependencies must be satisfied. For example, to declare
a dependency to several subroutines:

 all => [
     {sub => 'Package::foo1'},
     {sub => 'Package::foo2'},
     {sub => 'Another::Package::bar'},
 ],

=head2 any => [DEPCLAUSES, ...]

Like 'all', but specify a logical-OR relationship. Any one of the dependencies
will suffice. For example, to specify requirement to alternative modules:

 or => [
     {mod => 'HTTP::Daemon'},
     {mod => 'HTTP::Daemon::SSL'},
 ],

=head2 none => [DEPCLAUSES, ...]

Specify that none of the dependencies must be satisfied for this clause to be
satisfied. Example, to specify that the subroutine not run under SUDO or by
root:

 none => [
     {env  => 'SUDO_USER'},
     {code => sub {$> != 0} },
 ],

Note that the above is not equivalent to below:

 none => [
     {env => 'SUDO_USER', code => sub {$> != 0} },
 ],

which means that if none or only one of 'env'/'code' is satisfied, the whole
dependency becomes a success (since it is negated by 'none'). Probably not what
you want.

=for Pod::Coverage check check_.+

=head1 SEE ALSO

L<Sub::Spec>

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

