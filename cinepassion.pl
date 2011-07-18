#!/usr/bin/perl -w

#
# This perl script is intended to perform movie data lookups in french based on 
# the http://passion-xbmc.org/scraper/index2.php?Page=Home
#
# For more information on MythVideo's external movie lookup mechanism, see
# the README file in this directory.
#

# changes:
# 2009-12-15 : v 1.0 
#			Creation du script pour mythtv 0.22
# 2009-12-20 : v 1.1
#			Application de l'API du scraper 
#			Integration du mode GUI
# 2010-01-02 : v 1.2
#			Validation de l'API
# 2010-01-02 : v 1.3
#			Modification XML resultat de recherche
# 2010-01-24 : v 1.4
#			Ajout securite quand il n'y a pas de Poster et de Fanart
# 2010-01-24 : v 1.5
#			Ajout l'option -lock pour verouiller les informations par raport au script "janu"

use warnings;
#use strict;
use File::Basename;
use File::Copy;
use lib dirname($0);
use Encode;
use utf8;

use XML::Twig;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Status;

use Tk;    # Appel du module Tk
use Tk::Photo;
use Tk::JPEG;
use Tk::PNG;
use Tk::Bitmap;
use Tk::Label;
use Image::Magick;

use DBI;
use DBD::mysql;

use FindBin '$Bin';

use vars qw($opt_h $opt_i $opt_v $opt_D $opt_M $opt_P  $opt_F $opt_gui $opt_lock $opt_internalfix);
use Getopt::Long;

my $title = "Passion-XBMC scraper Query"; 
my $version = "v1.5";
my $author = "MARTIN-GONTHIER Fabrice";
my $FichierXML = "/tmp/scrapertmp.xml";
my $LastDownload = "/tmp/scraper.last";
my $UserAgent = "Mythtvfr r104";
my $Key = "eb098b4fd229b7844aed7c4ba2604f4e";

# Debug option $opt_d=1
# my $opt_d = 1;

binmode(STDOUT, ":utf8");

# display usage
sub usage {
	print "usage: $0  -lock -gui -hviMPFD [parameters]\n";
	print "       -h, --help                          help\n";
	print "       -v, --version                       display version\n";
	print "       -i, --info                          display info\n";
	print "\n";
	print "       -gui, --gui                         display window to select a picture\n";
	print "       -lock, --lock                       Fix the inetref to 99999999 for jamu script\n";
	print "\n";
	print "       -M <query>,   --movie <query>       get movie list\n";
	print "       -D <movieid>, --data <movieid>      get movie data\n";
	print "       -P <movieid>, --poster <movieid>    get movie poster\n";
	print "       -F <movieid>, --fanart <movieid>    get movie fanart\n";

	exit(-1);
}

# display 1-line of info that describes the version of the program
sub version {
	print "$title ($version) by $author\n"
} 

# display 1-line of info that can describe the type of query used
sub info {
	print ("This perl script is intended to perform movie data lookups in french based cine-passion on the http://passion-xbmc.org/scraper/index2.php?Page=Home\n");
}

# display detailed help 
sub help {
	version();
	info();
	usage();
}

# extraction nom de fichier
sub FilenameExtract{
	my ($URL)=@_; # grab URL parameter
	my $fichiertmp = '';
	if ( $URL =~ /([^\/]*)$/) 
		{
		if (defined $opt_d) { print "# FilenameExtract: ". $1."\n";}
		return $1;
		}
	else
		{
		exit;
		}
}

#Donwload XML
sub getUrlDataXML {
	my ($URL)=@_; # grab URL parameter
	
	# test last download XML sortie de fonction si deja telecharger
	if (-e $LastDownload) 
		{
		open ( my $fichiertemp, '<', $LastDownload) or die ( "Impossible de lire dans $LastDownload");
		my $ligne = <$fichiertemp>;
		if (defined $opt_d) { printf("# getUrlDataXML: $ligne\n");}
		close($fichiertemp);
		if ( $URL eq $ligne) 
			{
			if (defined $opt_d) { printf("# Sortie de la fonction getUrlDataXML\n");}
			return; 
			}
		}
	my $ua = LWP::UserAgent->new;
	$ua->agent($UserAgent);
	my $response = $ua->get( $URL );
	open ( my $fichier , '>', $FichierXML) or die ( "Impossible ecrire dans $FichierXML");
	if  ($response->is_success)
		{
		print {$fichier} $response->content;
		close ($fichier);
		chmod 0777, $FichierXML; # for multiuser
		open ( $fichier , '>', $LastDownload) or die ( "Impossible ecrire dans $LastDownload");
		print {$fichier} $URL;
		close ($fichier);
		chmod 0777, $LastDownload; # for multiuser
		}
	else 
		{
		 printf("Erreur impossible de recevoir les donnees\n");
		 exit;
		}
}

#Donwload image
sub DownloadImage {
	my ($URL)=@_; # grab URL parameter
	
	my $ua = LWP::UserAgent->new;
	$ua->agent($UserAgent);
	my $fichiertmp = FilenameExtract($URL);
	if ( ! ($fichiertmp eq "")) 
		{
		if  ( -e '/tmp/'.$fichiertmp ) { return; } # sortie si le fichier existe deja ou le telecharge
		if (defined $opt_d) { print '# Download image : '.$URL."\n";}
		my $response = $ua->get( $URL );
		open ( my $fichier , '>', '/tmp/'.$fichiertmp) or die ( "Impossible ecrire dans /tmp/$1");
		if  ($response->is_success)
			{
			binmode $fichier;
			print {$fichier} $response->content;
			close ($fichier);
			chmod 0777, $fichier; # for multiuser
			}
		else 
			{
			 printf("Erreur impossible de recevoir les donnees\n");
			 exit;
			}
		}
}

# Image resize
sub ImageResize {
	my ($imageorigin)=@_;
	my $image = new Image::Magick;
	$image->Read("/tmp/".$imageorigin);
	$image->Resize(geometry=>"600x600");
	$image->Write('/tmp/imagescraper.jpg');
	chmod 0777, '/tmp/imagescraper.jpg'; # for multiuser
}

# Delete tmp image
sub DeleteImage{
	my ($ref_listurlpreview)=@_;
	foreach (@$ref_listurlpreview)
		{
		my $fichiertmp = FilenameExtract($_);
		unlink ('/tmp/'.$fichiertmp);
		if (defined $opt_d) { print '# Delete image  : ','/tmp/'.$fichiertmp,"\n";}
		}
		unlink ('/tmp/imagescraper.jpg');
}

# Fenetre de selection
sub FormSelection {
	my ($ref_listurl,$ref_listurlpreview,$title)=@_; # grab url list parameter

	my $index = 0;

	# Creation de la fenetre
	my $fenetre = new MainWindow(
	  -title      => $title,
	  -background => "black",
	); 

	# Taille minimale de ma fenetre   
	$fenetre->minsize(600,700);
	
	if (defined $opt_d) { 
						print '# Form image original: ',$$ref_listurl[$index],"\n";
						print '# Form image preview : ',$$ref_listurlpreview[$index],"\n";
					}

	ImageResize(FilenameExtract($$ref_listurlpreview[$index]));
	my $ObjImage = $fenetre->Photo( -file => '/tmp/imagescraper.jpg');
	
	my $Imagebutton = $fenetre->Label( 
		-height => 600,
		-width => 600,
		-image => $ObjImage,
		-background => "black",
		-borderwidth =>  0,
		-activebackground => "black",
		-relief => 'flat',
		-underline => 0,
	)->pack(-side => 'top');

	# Affichage d'un bouton pour fermer la fenetre
	my $boutonOK = $fenetre -> Button (
		-text => "Select", 
		#-anchor => "s",
		-command => sub { 
							print $$ref_listurl[$index]."\n";
							DeleteImage(\@$ref_listurlpreview);
							exit;
						},
	)->pack(-side => 'bottom');

	my $labelindex = $fenetre -> Label (
			-text => ($index+1)." / ".scalar(@$ref_listurlpreview),
			#-background => "black",
			#-activebackground => "black",
		)->pack(-side => 'bottom');

	my $boutonBefore = $fenetre -> Button (
		-text =>  "Previous", 
		#-anchor => "s",
		-command => sub { 
						$index = $index-1;
						if ( $index < 0) {$index=scalar(@$ref_listurlpreview)-1;}
						ImageResize(FilenameExtract($$ref_listurlpreview[$index]));
						$ObjImage = $fenetre->Photo( -file => '/tmp/imagescraper.jpg');
						$Imagebutton->configure(-image => $ObjImage);
						$labelindex->configure(-text => ($index+1)." / ".scalar(@$ref_listurlpreview));
						},
	)->pack(-side => 'left');
	
	my $boutonNext= $fenetre -> Button (
		-text => "Next", 
		#-anchor => "s",
		-command => sub { 
						$index = $index+1;
						if ( $index > (scalar(@$ref_listurlpreview)-1)) {$index=0;}
						ImageResize(FilenameExtract($$ref_listurlpreview[$index]));
						$ObjImage = $fenetre->Photo( -file => '/tmp/imagescraper.jpg');
						$Imagebutton->configure(-image => $ObjImage);
						$labelindex->configure(-text => ($index+1)." / ".scalar(@$ref_listurlpreview),);
						},
	)->pack(-side => 'right');

	MainLoop();  # Obligatoire
}

# get Movie Data 
sub getMovieData {
	my ($movieid)=@_; # grab movieid parameter
	if (defined $opt_d) { printf("# looking for movie id: '%s'\n", $movieid);}

	# get the search results  page
	my $request = "http://passion-xbmc.org/scraper/API/1/Movie.GetInfo/ID/fr/XML/".$Key."/".$movieid;
	if (defined $opt_d) { printf("# request: '%s'\n", $request); }

	getUrlDataXML($request);
	
	my $twig = new XML::Twig;
	$twig->parsefile($FichierXML);
	my $root = $twig->root;
	#Title
	if ($root->first_child('title')) 
		{
		my $twigTitle = $root->first_child('title');
		print "Title:".$twigTitle->text."\n";
		}
	#OriginalTitle
	if ($root->first_child('originaltitle')) 
		{
		my $twigOriginalTitle = $root->first_child('originaltitle');
		print "OriginalTitle:".$twigOriginalTitle->text."\n";
		}
	#Year
	my $year = "";
	if ($root->first_child('year')) 
		{
		my $twigYear= $root->first_child('year');
		print "Year:".$twigYear->text."\n";
		$year = $twigYear->text;
		}
	#Director
	if ($root->first_child('directors')) 
		{
		print "Director:";
		$text = "";
		foreach my $twigDirector ($root->first_child('directors')->children) 
			{
			$text = $text.$twigDirector->text.", ";
			} 
		chop($text); # Efface le dernier caractere
		chop($text); # Efface le dernier caractere
		print $text."\n";
		}
	#Plot
	if ($root->first_child('plot')) 
		{
		my $twigPlot = $root->first_child('plot');
		printf"Plot:".$twigPlot->text."\n";
		}
	#UserRating
	if ($root->first_child('ratings')) 
		{
		foreach my $twigUserRating ($root->first_child('ratings')->children) 
			{
			if  ($twigUserRating->att( 'type') eq "allocine")
				{
				print "UserRating:".$twigUserRating->text."\n";
				}
			}
		}
	#MovieRating
	#~ if ($root->first_child('ratings')) 
		#~ {
		#~ foreach my $twigMovieRating ($root->first_child('ratings')->children) 
			#~ {
			#~ if  ($twigMovieRating->att( 'type') eq "allocine")
				#~ {
				#~ print "MovieRating:".$twigMovieRating->text."\n";
				#~ }
			#~ }
		#~ }
	#Runtime
	if ($root->first_child('runtime')) 
		{
		my $twigRuntime = $root->first_child('runtime');
		print "Runtime:".$twigRuntime->text."\n";
		}
	#Cast
	if ($root->first_child('casting')) 
		{
		print "Cast:";
		my $text = "";
		foreach my $twigActor ($root->first_child('casting')->children) 
			{
			$text = $text.$twigActor->att('name').", ";
			} 
		chop($text); # Efface le dernier caractere
		chop($text); # Efface le dernier caractere
		print $text."\n";
		}
	#Genres
	if ($root->first_child('genres')) 
		{
		print "Genres:";
		$text = "";
		foreach my $twigGenre ($root->first_child('genres')->children) 
			{
			$text = $text.$twigGenre->text.", ";
			} 
		chop($text); # Efface le dernier caractere
		chop($text); # Efface le dernier caractere
		print $text."\n";
		}
	#Countries
	if ($root->first_child('countries')) 
		{
		print "Countries:";
		$text = "";
		foreach my $twigCountry ($root->first_child('countries')->children) 
			{
			$text = $text.$twigCountry->text.", ";
			} 
		chop($text); # Efface le dernier caractere
		chop($text); # Efface le dernier caractere
		print $text."\n";
		}
	# lance le fix 9999999
	if ((defined $opt_lock) and !($year eq ""))
		{
		if (defined $opt_d) { print("# Launch AT command\n");}
		`echo \"$Bin\/cinepassion.pl -internalfix $movieid $year\" | at now + 15 minutes 2>/dev/null >/dev/null`;
		}
}

# dump Movie Poster
sub getMoviePoster {
	my ($movieid)=@_; # grab movieid parameter
	if (defined $opt_d) { printf("# looking for movie id: '%s'\n", $movieid);}

	# recuperation du XML dans  $response
	my $request = "http://passion-xbmc.org/scraper/API/1/Movie.GetInfo/ID/fr/XML/".$Key."/".$movieid;
	if (defined $opt_d) { printf("# request: '%s'\n", $request); }

	getUrlDataXML($request);

	my $twig = new XML::Twig;
	$twig->parsefile($FichierXML);
	my $root = $twig->root;
	my @ListURL =();
	my @ListURLPreview=();
	if ($root->first_child('images'))
		{
		foreach my $twigImage ($root->first_child('images')->children) 
			{
			if (($twigImage->att('type') eq 'Poster') and ($twigImage->att('size') eq 'original'))
				{
				push(@ListURL, $twigImage->att('url')); # URL dans la liste
				if (!defined $opt_gui) { print $twigImage->att('url'),"\n";}
				if (defined $opt_d) { print '# Original image : ',$twigImage->att('url'),"\n";}
				}
			if (($twigImage->att('type') eq 'Poster') and ($twigImage->att('size') eq 'preview'))
				{
				push(@ListURLPreview, $twigImage->att('url')); # URL dans la liste preview
				if (defined $opt_d) { print '# Preview image  : ',$twigImage->att('url'),"\n";}
				if (defined $opt_gui) {DownloadImage($twigImage->att('url'));}
				}
			}
		}
	if ((defined $opt_gui) and (scalar(@ListURL) != 0))
		{FormSelection(\@ListURL,\@ListURLPreview,"Select the coverart");}
}

# dump Movie Fanart
sub getMovieFanart {
	my ($movieid)=@_; # grab movieid parameter
	if (defined $opt_d) { printf("# looking for movie id: '%s'\n", $movieid);}

	# recuperation du XML dans  $response
	my $request = "http://passion-xbmc.org/scraper/API/1/Movie.GetInfo/ID/fr/XML/".$Key."/".$movieid;
	if (defined $opt_d) { printf("# request: '%s'\n", $request); }

	getUrlDataXML($request);

	my $twig = new XML::Twig;
	$twig->parsefile($FichierXML);
	my $root = $twig->root;
	my @ListURL =();
	my @ListURLPreview=();
	if ($root->first_child('images'))
		{
		foreach my $twigImage ($root->first_child('images')->children)
			{
			if (($twigImage->att('type') eq 'Fanart') and ($twigImage->att('size') eq 'original'))
				{
				push(@ListURL, $twigImage->att('url')); # URL dans la liste
				if (!defined $opt_gui) { print $twigImage->att('url'),"\n";}
				if (defined $opt_d) { print '# Original image : ',$twigImage->att('url'),"\n";}
				}
			if (($twigImage->att('type') eq 'Fanart') and ($twigImage->att('size') eq 'preview'))
				{
				push(@ListURLPreview, $twigImage->att('url')); # URL dans la liste preview
				if (defined $opt_d) { print '# Preview image  : ',$twigImage->att('url'),"\n";}
				if (defined $opt_gui) {DownloadImage($twigImage->att('url'));}
				}
			}
		}
	if ((defined $opt_gui) and (scalar(@ListURL) != 0))
		{FormSelection(\@ListURL,\@ListURLPreview,"Select the fanart");}
}

 # get Movie Search
sub getMovieList {
	my ($search)=@_; # grab chaine de recherche
	if (defined $opt_d) { printf("# Seach for movie : '%s'\n", $search);}
	
	# recuperation du XML dans  $response
	my $uas = LWP::UserAgent->new;
	$uas->agent($UserAgent);
	my $request = "http://passion-xbmc.org/scraper/API/1/Movie.Search/Title/fr/XML/".$Key."/".$search;
	if (defined $opt_d) { printf("# request: '%s'\n", $request); }
	
	getUrlDataXML($request);

	my $twig = new XML::Twig;
	$twig->parsefile($FichierXML);
	my $root = $twig->root;

	if ($root->name eq "errors") { exit;}
	
	foreach my $twigEntity ($root->children('movie')) 
		{
		print $twigEntity->first_child('id')->text.":";
		print $twigEntity->first_child('title')->text;
		print " (". $twigEntity->first_child('year')->text.")";
		print " [". $twigEntity->first_child('originaltitle')->text."]"."\n";
		} 
}

sub parse_config_file {

    local ($config_line, $Name, $Value, $Config);

    my ($File, $Config) = @_;

    if (!open (CONFIG, "$File")) {
        print "ERROR: Config file not found : $File";
        exit(0);
    }

    while (<CONFIG>) {
        $config_line=$_;
        chop ($config_line);          # Get rid of the trailling \n
        $config_line =~ s/^\s*//;     # Remove spaces at the start of the line
        $config_line =~ s/\s*$//;     # Remove spaces at the end of the line
        if ( ($config_line !~ /^#/) && ($config_line ne "") ){    # Ignore lines starting with # and blank lines
            ($Name, $Value) = split (/=/, $config_line);          # Split each line into name value pairs
            $$Config{$Name} = $Value;                             # Create a hash of the name value pairs
        }
    }

    close(CONFIG);

}

# Fix INETREF metadonne
sub fixINETREF {
	my ($movieid, $movieyear)=@_; # grab movieid, movieyear parameter
	if (defined $opt_d) { printf("# looking for movie id: '%s'\n", $movieid);}
	if (defined $opt_d) { printf("# looking for movie year: '%s'\n", $movieyear);}
	
	#parse mysql.txt 
	my $DBHostName = "";
	my $DBName = "";
	my $DBUserName = "";
	my $DBPassword = "";
	my @MYSQLLIST=("/etc/mythtv/mysql.txt", "~mythtv/.mythtv/mysql.txt", "~/.mythtv/mysql.txt", "/.mythtv/mysql.txt", "/usr/local/share/mythtv/mysql.txt", "/usr/share/mythtv/mysql.txt", "/etc/mythtv/mysql.txt", "/usr/local/etc/mythtv/mysql.txt", "mysql.txt");
	foreach my $m (@MYSQLLIST)
		{
		if (-e $m )
			{
			if (defined $opt_d) { printf("# mysql.txt located : '%s'\n", $m); }
			&parse_config_file ($m, \%Config);
			last;
			}
		} 
	foreach $Config_key (keys %Config) {
		if ( $Config_key eq "DBHostName" ){
			$DBHostName = $Config{$Config_key};
			 if (defined $opt_d) { printf("# DBHostName : %s\n", $DBHostName); }
			 }
		elsif ( $Config_key eq "DBName" ){
			$DBName = $Config{$Config_key};
			if (defined $opt_d) { printf("# DBName : %s\n", $DBName); }
			}
		elsif ( $Config_key eq "DBUserName" ){
			$DBUserName = $Config{$Config_key};
			if (defined $opt_d) { printf("# DBUserName : %s\n", $DBUserName); }
			}
		elsif ( $Config_key eq "DBPassword" ){
			$DBPassword = $Config{$Config_key};
			if (defined $opt_d) { printf("# DBPassword : %s\n", $DBPassword); }
			}
			}
	if (!((((defined $DBHostName) && (defined $DBName)) && (defined $DBUserName)) && (defined $DBPassword)))
		{
		if (defined $opt_d) { print("# Bad mysql.txt\n"); }
		exit;
		}

	# Fix INETREF to 99999999
	my $dbh = DBI->connect('DBI:mysql:'.$DBName.":".$DBHostName.":3306", $DBUserName, $DBPassword) or die "connection impossible !";
	#~ if (defined $opt_d) { printf("# Title year: %s\n", $movieyear); }
	my $requestsql = "UPDATE `videometadata` SET `inetref`=\"99999999\" WHERE `inetref`=\"$movieid\" and `year`=\"$movieyear\"" ;
	if (defined  $opt_d) { print "# request sql: ".$requestsql."\n";}
	my $sth = $dbh->prepare($requestsql);
	$sth->execute();
	$sth->finish();
	$dbh->disconnect;

	exit;
}

#
# Main Program
#

# parse command line arguments 

	GetOptions
	( 
		"help" => \$opt_h,
		"version" => \$opt_v,
		"info" => \$opt_i,
		"Data" => \$opt_D,
		"Movie" => \$opt_M,
		"Poster" => \$opt_P,
		"Fanart" => \$opt_F,
		"gui" => \$opt_gui,
		"lock" => \$opt_lock,
		"internalfix" => \$opt_internalfix
	);

# print out info 
if (defined $opt_v) { version(); exit 1; }
if (defined $opt_i) { info(); exit 1; }

# print out usage if needed
if (defined $opt_h || $#ARGV<0) { help(); }

# option for internal usage
if (defined $opt_internalfix) {
	# take movieid and year of movie from cmdline arg
	fixINETREF($ARGV[0], $ARGV[1]);
}
elsif (defined $opt_D) {
	# take movieid from cmdline arg
	my $movieid = shift || die "Usage : $0 -D <movieid>\n";
	getMovieData($movieid);
}
elsif (defined $opt_P) {
	# take movieid from cmdline arg
	my $movieid = shift || die "Usage : $0 -P <movieid>\n";
	getMoviePoster($movieid);
}
elsif (defined $opt_F) {
	# take movieid from cmdline arg
	my $movieid = shift || die "Usage : $0 -F <movieid>\n";
	getMovieFanart($movieid);
}
elsif (defined $opt_M){
	# take query from cmdline arg
	#$options = shift || die "Usage : $0 -M <query>\n";
	my $query;
	my $options = '';
	foreach my $key (0 .. $#ARGV) {
	$query .= $ARGV[$key]. ' ';
	}
	getMovieList($query, $options);
}
# vim: set expandtab ts=3 sw=3 :
