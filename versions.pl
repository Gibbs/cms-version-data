#!/usr/bin/env perl
use strict;
use warnings;
no warnings qw(newline);

use FindBin qw($RealBin $RealScript);
use File::Basename;
use JSON;

our $REPO = "https://raw.githubusercontent.com/JamesDooley/VersionFinder/master";
our $UPDATECHECK = 43200; # 12 hours
our $SIGNATURES;
our $DATA;
our $FORMAT = '';

our @OARGV = @ARGV;

while (@ARGV) {
  my $argument = shift @ARGV;

  if ($argument =~ /^-/) {
    if ($argument =~ /^--json/i) {
      $FORMAT = 'json';
    }
  }
}

sub checkUpdate {
  unless (qx(which curl 2>/dev/null)) {
    print " [Failed]\n - Curl is not found on this system\n - Automated update checks are disabled.\n";
    return;
  };

  my $VFUpdates;
  my $ScriptUpdated;

  if (-e "$RealBin/.vf_updates") {
    open (my $FH, "<","$RealBin/.vf_updates");

    while (<$FH>) {
      $_ =~ /^([a-zA-Z_.]*):(.*)$/;
      next unless ($1 && $2);
      $VFUpdates->{$1} = $2;
    }
  }

  return if ($VFUpdates->{manual});

  if ($VFUpdates->{lastcheck} && $VFUpdates->{lastcheck} + $UPDATECHECK > time) {
    return;
  }

  foreach my $file ('.vf_signatures') {
    my $header = qx(curl -I "$REPO/$file" 2>/dev/null);

    unless ($header =~ /ETag:.+"(.*)"/) {
      print "[Failed]\n - Repo did not return an ETag\n - Automated update checks are disabled.\n";
      next;
    }

    if ($VFUpdates->{$file} && $VFUpdates->{$file} eq $1) {
      next;
    }

    if (updateFile("$file")) {
      $VFUpdates->{$file} = $1;
      $ScriptUpdated = 1 if ($file eq "versionfinder.pl");
    };
  }

  if (-e "$RealBin/versionfinder.sigs") {
    delete $VFUpdates->{'versionfinder.sigs'};
    unlink "$RealBin/versionfinder.sigs";
  }

  $VFUpdates->{lastcheck} = time;

  open (my $FH, ">", "$RealBin/.vf_updates");

  foreach my $var (keys %$VFUpdates) {
    print $FH "$var:".$VFUpdates->{$var}."\n";
  }

  close $FH;
}

sub updateFile {
  my $file = shift;

  if (qx(which wget)) {
    qx(wget --quiet --no-check-certificate -O "$RealBin/$file.new" "$REPO/$file");
  } elsif (qx(which curl)) {
    qx(curl --fail --output "$RealBin/$file.new" "$REPO/$file" 2>/dev/null);
  } else {
    print "[Failed]\n - Need Curl or Wget for automatic downloads\n - Automated update checks are disabled, please manually update.\n";
    return 0;
  }

  if ( ! -e "$RealBin/$file.new" || -z "$RealBin/$file.new") {
    unlink "$RealBin/$file.new" if (-e "$RealBin/$file.new");
    print "[Failed]\n - File did not download properly.\n";
    return 0;
  }

  my $realfile = $file;

  unlink "$RealBin/$realfile" if (-e "$RealBin/$realfile" && -e "$RealBin/$file.new");
  rename "$RealBin/$file.new","$RealBin/$realfile";

  return 1;
}

sub printJSON {
  require "$RealBin/.vf_signatures" unless $SIGNATURES;
  my $data;

  foreach my $signame (sort {$a cmp $b} keys %$SIGNATURES) {
    my $signature = $SIGNATURES->{$signame};
    $data->{$signature->{name}} = $signature->{releases};
  }

  print encode_json $data;
}

# Check for signature updates
checkUpdate;

# Print JSON output
if ($FORMAT eq 'json') {
  printJSON();
}
