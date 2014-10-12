#!/usr/bin/perl

###############################################################################
#     DESsubdb - download subtitles for your movies from the thesubdb database
#     Copyright (C) 2012  David Santiago
#  
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
##############################################################################

use warnings;
use strict;
use utf8;
use diagnostics;
use Digest::MD5 qw(md5_hex);
use LWP::UserAgent;
use URI::Escape;
use File::Basename;
use Getopt::Long;
use Data::Dumper;
use 5.014;

use constant ALLOWED_FILE_EXTENSIONS_REGEXP => "\.[^.]*";
use constant BLOCK_SIZE=>65536;# 64K
use constant SUBDB_API_URL=>'http://api.thesubdb.com/?';
use constant USER_AGENT => 'SubDB/1.0 (DESsubdb/0.1; http://sourceforge.net/projects/dessubdb)';
use constant SUBTITLES_LANGUAGE => qw(en pt);
use constant ALLOWED_VIDEO_FILE_EXTENSIONS => qw(.avi .m4v .mkv .mp4 .ogv .flv);
use constant ALLOWED_SUB_FILE_EXTENSIONS => qw(.srt .sub);

my $browser = LWP::UserAgent->new;
$browser->agent(USER_AGENT);

my @USER_LANGUAGES;
GetOptions("lang=s"=>\@USER_LANGUAGES);



for my $file (@ARGV){

  if( ! -e $file ){
    say "File not found= $file";
    next;
    }

  my @fileData = fileparse($file, ALLOWED_FILE_EXTENSIONS_REGEXP);
  
  say "File extension= ",$fileData[2];


  if(grep (/$fileData[2]/, ALLOWED_SUB_FILE_EXTENSIONS)){
    say "Subtitles File!";
    uploadSubs($file);
  }elsif(grep /$fileData[2]/, ALLOWED_VIDEO_FILE_EXTENSIONS){
    say "Video File!";
    searchAndDownloadSubs( $file);

  }
}

#upload subtitles
sub uploadSubs{
  
  my $file = shift;
  my $fileSize = -s $file;


  my @fileData = fileparse($file, ALLOWED_FILE_EXTENSIONS_REGEXP);
  
  for my $extension (ALLOWED_VIDEO_FILE_EXTENSIONS){
    if( -e $fileData[1].$fileData[0].$extension){
      
      say "Found ".$fileData[1].$fileData[0].$extension;

      my $fileHash = getFileHash($fileData[1].$fileData[0].$extension);

      my %url_parameters = ("action"=>"upload",);

      my %url_data = (
		      Content_Type => 'multipart/form-data',
		      "content"=>[
				  "hash"=> $fileHash,
				  "file"=>[$file,$fileData[0], (Content_Type => "application/octet-stream")] ,
				  ],
		     );
      
      my $response = $browser->post(SUBDB_API_URL.create_query(%url_parameters), %url_data );
      say "Subtitles Upload result= ".$response->status_line;
      

      return;

    }
      
  }

}

# search and download subtitles
sub searchAndDownloadSubs{
  
  my $file = shift;
  
  my %url_parameters = (
			"hash"=>getFileHash( $file),
			"action"=>"search",
		       );
  

  say "Querying the url: ".SUBDB_API_URL.create_query(%url_parameters);
  
  my $response = $browser->get(SUBDB_API_URL.create_query(%url_parameters));
  say "Response = ".$response->status_line;

  if ($response->is_success){
    my $availableLanguages = $response->content;
    my @languagesToDownload = ();
    
    for my $lang ($#USER_LANGUAGES==0?@USER_LANGUAGES:SUBTITLES_LANGUAGE){
      
      if( $availableLanguages =~ /$lang/ ){
	push @languagesToDownload, $lang;
      }
    }

    if(@languagesToDownload >= 1){
      $url_parameters{"action"} = "download";
      $url_parameters{"language"} = join ',', @languagesToDownload;
      
      my @fileData = fileparse($file, ALLOWED_FILE_EXTENSIONS_REGEXP);
      

      $response = $browser->get(SUBDB_API_URL.create_query(%url_parameters), ':content_file'=>$fileData[1].$fileData[0].".srt");
      
      if($response->is_success){
	say "Subtitles for $file downloaded!";
      }

    }
  }


}


# calculates the file hash, as specified in the thesubdb site 
sub getFileHash{

  my $filename = shift or die 'A filename is required!'; 

  my $filesize = -s $filename;

  die "The file is too small! Wrong file?!? " unless $filesize > BLOCK_SIZE*2;

  open (my $fh, "<", $filename) or die "Couldn't open file $filename: $!";
  
  binmode $fh;
  
  my $buffer;
  my $data;
  
  read $fh, $data, BLOCK_SIZE;

  $buffer = $data;
  
  seek $fh, -1*BLOCK_SIZE, 2;
  
  read $fh, $data, BLOCK_SIZE;
  
  $buffer .=$data;

  close $fh;

  say "Hash= ".md5_hex($buffer);
  md5_hex($buffer);

}


# i copied this from somewhere on the internet. I don't know the credits. If You do, please tell me so i can
# put them here.
# My perl kungfu is not good enough for this code (YET! :-P )
sub create_query{
    my %hash = @_;
    my @pairs;
    for my $key (keys %hash) {
        push @pairs, join "=", map { uri_escape($_) } $key, $hash{$key};
    }
    return join "&", @pairs;
}
