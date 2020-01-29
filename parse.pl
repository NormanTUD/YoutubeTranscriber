#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor;

sub mysystem ($);

main(@ARGV);

sub main {
	my $start = shift;
	mkdir "dl" unless -d "dl";
	mkdir "results" unless -d "results";

	my @ids = ();
	if($start =~ m#list#) {
		push @ids, dl_playlist($start);
	} else {
		push @ids, $start;
	}

	foreach my $id (@ids) {
		my $fn = "$id.de.vtt";
		if (-f "dl/$fn") {
			warn "dl/$fn already exists. Skipping this...";
			next;
		}
		my $downloaded_filename = transcribe($id);
		my $contents = parse_vtt($downloaded_filename);
		open my $fh, '>', "results/$id.txt" or die $!;
		$contents = "Dieser Mitschnitt basiert auf den von YouTube erstellten Subtitel-Daten.\nDas Skript findet sich unter https://github.com/NormanTUD/YoutubeTranscriber und ist frei verfügbar.\n\n$contents";
		print $fh $contents;
		close $fh;
	}
}

sub transcribe {
	my $id = shift;
	mysystem qq#youtube-dl --sub-lang=de --write-auto-sub --skip-download "$id" -o dl/$id#;

	return "dl/$id.de.vtt";
}

sub dl_playlist {
	my $start = shift;

	my $command = qq#youtube-dl -j --flat-playlist "$start" | jq -r '.id'#;
	print $command;
	my @list = qx($command);
	@list = map { chomp $_; $_ } @list;

	warn "got ".Dumper(@list);

	return @list;
}

sub texter {
	my $file = shift;

	my $contents = parse_vtt($file);
	return $contents;
}

# youtube-dl --sub-lang=de --write-auto-sub --skip-download https://www.youtube.com/watch\?v\=5E2EjUx_5Vs -o dl/5E2EjUx_5Vs

sub parse_vtt {
	my $filename = shift;

	my $contents = '';

	my $last_minute_marker = 0;
	my $last_hour_marker = 0;

	open my $fh, '<', $filename or die $!;
	while (my $line = <$fh>) {
		$line =~ s#\R##g;
		$line = remove_comments($line);
		if(
			$line !~ m#^WEBVTT$# &&
			$line !~ m#^Kind: captions$# &&
			$line !~ m#^Language: \w+$# &&
			$line !~ /^\s*$/ && 
			$line !~ m#^\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}\s*align:start position:0%$# &&
			$line ne get_last_line($contents)
		) {
			$contents .= "$line\n";
		} elsif (
			$line =~ m#^(\d{2}):(\d{2}):\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}\s*align:start position:0%$#
		) {
			my ($this_hour, $this_minute) = ($1, $2);

			if($last_hour_marker != $this_hour || $last_minute_marker != $this_minute) {
				$contents .= "[$this_hour:$this_minute]\n";
			}

			($last_hour_marker, $last_minute_marker) = ($this_hour, $this_minute);
		}
	}
	close $fh;

	$contents = wrap_lines($contents);
	return $contents;
}

sub wrap_lines {
	my $contents = shift;

	my @splitted = split /(\[\d+:\d+\])/, $contents;

	my @removed = ();
	foreach (@splitted) {
		s#\R# #g;
		push @removed, $_;
	}

	my $joined = join "\n", map { s#^\s+##g; s#\s+$##g; $_ } @removed;
	$joined .= "\n";

	return $joined;
}

sub remove_comments {
	my $line = shift;
	$line =~ s#<\d\d:\d\d:\d\d\.\d{3}><c>##g;
	$line =~ s#</c>##g;
	return $line;
}

sub get_last_line {
	my $contents = shift;

	my @split = split /\R/, $contents;
	return "" unless @split;

	my $last_line = $split[$#split];
	if($last_line =~ m#^\[\d+:\d+\]$#) {
		$last_line = $split[$#split - 1];
	}

	return $last_line;
}
sub mysystem ($) {
	my $command = shift;
	print "$command\n";
	system($command);
	print "\n$command ENDE\n";
	print "RETURN-CODE: ".($? << 8)."\n";
}
