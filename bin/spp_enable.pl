#!/usr/bin/perl

#purpose: deploys spp 
#author: Ziru Zhou
#date: November, 2012

use strict;
use warnings;
use File::Basename;
use Time::HiRes;

#globals
#======================================================================
# file to store IP addresses of compute nodes already have macs2 
# dependencies installed
my $INSTALL_FILE = $ENV{"HOME"} . "/.install_list_spp.txt";

my $forceInstall = $ARGV[0];

# if force reinstall
if (defined $forceInstall) {
        system ("sudo rm $INSTALL_FILE");
}

my $local;
my $local1;
my $local2;

my @iplists;
my @installed;

#function declarations
#======================================================================
#gets the internal ips of the worker nodes
sub Getips()
{
        # ignore the first three lines ( they are headers )
        # we only want the IP addresses 
        system ("qhost | awk 'NR > 3' > trim_spp.txt");
        @iplists= `cut -d ' ' --fields=1 trim_spp.txt`;
}

#remove dependencies
sub Cleanup()
{
	system ("sudo rm trim_spp.txt");
}

#the usage error message printing function (unused)
sub Usage()
{
        if(@ARGV > 1)
        {
                print "\n";
                print "This script installs dependencies for MACS2.  Please send questions/comments to help\@modencode.org.";
                print "\n\nusage: perl " . basename($0) . " [ -f ]  ";
                print "\n\t-f\tforce to reinstall dependencies on all compute nodes ( OPTIONAL ). ";
                print "\n\n";
                exit 2;
        }
}

#loads data from install_list.txt
sub Loadinstallednodes()
{
	open FILE, '+>>'."$INSTALL_FILE" or die "Could not find $INSTALL_FILE\n";
	@installed = <FILE>;
	
	close FILE;
}

#saves data from install_list.txt
sub Saveinstallednodes()
{
	open FILE, '+>>'."$INSTALL_FILE" or die "Unable to create $INSTALL_FILE\n";
	print FILE @installed;
	
	close FILE;
}

#searches if node already has packages installed
sub searchinstalled
{
	my $i = shift;
	my $test = "";
	
	$test = `grep ${i} $INSTALL_FILE`;

	if($test eq "")
	{
		return 0;
	}
	else
	{
		return 1;
	}
}

#copys installer files over to the shared drive
sub Copyinstaller
{
	system ("sudo cp bin/spp_deploy.R /mnt/galaxyData/tmp");
	system ("sudo cp bin/spp_1.10.1.tar.gz /mnt/galaxyData/tmp");
}

#gets the local ip so that we dont qrsh onto the same host
sub Getlocalip
{
	#$local = `ifconfig eth0 | grep "inet addr:" | cut -d ":" --field=2 | cut -d " " --field=1`;
	$local = `hostname`;
	chomp($local);
	#$local =~s/\./\-/g;
	#$local1 = "ip-${local}.ec2.internal";
	#$local2 = "domU-${local}.compute-1.internal";
	$local1 = "${local}.ec2.internal";
	$local2 = "${local}.compute-1.internal";
}

#function calls
#======================================================================
Usage();

Getips();
Loadinstallednodes();
Copyinstaller();
Getlocalip();

foreach my $i (@iplists)
{
	#process node adress
	chomp($i);
        if($i =~/^domU/)
        {
                $i="${i}.compute-1.internal";
        }
        else
        {
                $i="${i}.ec2.internal";
        }

	#install the packages on the node 
	if(searchinstalled($i) == 0)
	{
		print "installing dependencies on $i\n";
		if(($i eq $local1) || ($i eq $local2))
		{
			system ("sudo R CMD BATCH /mnt/galaxyData/tmp/spp_deploy.R");
		}
		else
		{
			system ("qrsh -l h=${i} -b y \"sudo rm -rf /usr/local/lib/R/site-library/00LOCK ; sudo R CMD BATCH /mnt/galaxyData/tmp/spp_deploy.R\"");
		}
		push (@installed, "$i\n");
		print "Installation of spp completed\n";
	}
	else
	{
		print "$i already has spp dependencies installed\n";
	}
}

Saveinstallednodes();
Cleanup();