#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw/ceil/;

my $number_of_slides = 20;
my $fabula_size = $ARGV[2] || 500;
my $theme = $ARGV[1] || "winter";

open FILE, $ARGV[0];

my @words = ();
foreach my $line (<FILE>)
{
	$line =~ s/[^a-zA-Z0-9]/ /g;
	$line = lc $line;
	
	push @words, split(/ +/, $line);

}
close FILE;

my %word_set = ();
foreach my $word (@words)
{
	$word_set{$word}++;
}

open NGRAMS, "2008grams.tsv";
my $ngram_count = 0;
my %ngram_set = ();
foreach my $line (<NGRAMS>)
{
	#word	year	occurences	pages	texts
	my @bits = split /\t/, $line;
	$ngram_count += $bits[2];
	if($word_set{$bits[0]})
	{
		$ngram_set{$bits[0]} = $bits[2];
	}
}
close NGRAMS;

use Data::Dumper;

#print Dumper(%ngram_set);

print STDERR "there are ".scalar @words." words\n";

my $word_count = scalar @words;
my $section_size = ceil($word_count/$number_of_slides);

my @slide_words = ();
my $slide_count = 0;
while(scalar @words > 0){
	$slide_words[$slide_count] = "";
	my $best_score = 0;
	foreach my $word (splice(@words, 0, $section_size))
	{
		#print "the word $word is ".$word_set{$word}/$word_count." of the document\n";
		if(!$ngram_set{$word})
		{
			print STDERR "Word: $word is not in the ngram set. It is ignored\n";
			next;
		}

		my $word_score = ($word_set{$word} * $ngram_count) / ($ngram_set{$word} * $word_count);
		if($word_score > $best_score)
		{
			$best_score = $word_score;
			$slide_words[$slide_count] = $word;
		}
	}
	print STDERR "\n\n END OF SLIDE $slide_count. Word: ".$slide_words[$slide_count].". Score: $best_score\n\n";
	$slide_count++;
}

my %images = ();
my @slides = ();
foreach my $keyword (@slide_words)
{
	if(! -e $keyword.$fabula_size.".fab")
	{
		`java -jar flickrfab.jar $keyword $fabula_size -noise 4`;
	}
	
	if(! defined $images{$keyword} )
	{
		my $output = `java -jar tmb.jar $keyword$fabula_size.fab $number_of_slides $theme -brief -o -`;
	
		my @output_lines = split /\n/, $output;
		
		$images{$keyword} = \@output_lines;
	}

	
	push @slides, shift(@{$images{$keyword}});
}

my $count = 1;
foreach my $slide (@slides)
{
	my $keyword = shift @slide_words;
	print "<img src='$slide' alt='$keyword' title='$keyword' />\n";
	my $file_name = sprintf("%03d", $count).".jpg";
	#$slide =~ s/_m\.jpg/_b.jpg/g;
	`wget $slide -O - | convert - -resize '480x320' -size 480x320 xc:black +swap -gravity center -composite $file_name`;
	$count++;
}

`ffmpeg -r 0.05 -b 9600 -i %03d.jpg video.mp4`;
`espeak -f $ARGV[0] -v'en-klatt2' --stdout | lame - audio.mp3`;
`ffmpeg -i video.mp4 -i audio.mp3 -acodec copy -vcodec copy -ab 128k -ar 44100 -map 0:0 -map 1:0 output.mp4`
