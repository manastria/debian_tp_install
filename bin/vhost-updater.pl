#!/usr/bin/perl -w
 
#############################################################
# The purpose of this script is to add/remove               # 
# virtual hosts easily, this script runs                    #
# on Ubuntu/Debian withouth modifications.                  #
#                                                           #	
#                                                           #	
# Author Ivan Villareal ivaano@gmail.com                    #
#                                                           #	
#############################################################
use strict;
use File::Path qw(mkpath rmtree);
use Getopt::Long;
 
 
our $ipAddress        = '127.0.0.1';
our $apacheConfigDir  = '/etc/apache2';
our $sitesAvailable   = 'sites-available';
 
our $docRootPrefix    = '/sites_web/sites';
our $docRoot          = 'public_html';
our $logsDir          = 'logs';
our $certDir          = 'ssl';
our $vhostPort        = 80;
 
 
 
my $del = '';
my $add = '';
my $ssl = '';
my $domain = '';
 
if (getpwuid( $< ) ne 'root') {
	print "Script needs root privileges \n";
	exit();
}
 
unless (GetOptions (
		'del' => \$del, 
		'add' => \$add, 
		'ssl' => \$ssl, 
		'domain=s' => \$domain) or usage()) {
    usage();
}
 
#print $paramResults;
if ($add || $del) {
    if ($domain) {
        if ($add) {
            createVhost($domain);
        } elsif ($del) {
            deleteVhost($domain);
        }
    } else {
        usage();
    }
} else {
    usage();
}
 
 
sub usage {
    print <<USAGE
This program will add or remove apache virtual hosts.
 
usage: vhost-updater.pl [--add | --del] [ --ssl] --domain newhost.tld 
USAGE
}
 
sub returnVhostPaths
{
    my $vhost = shift;
    my @dir = split(/\//, $docRootPrefix);
    my %res;
 
    if ($ssl)
    {
    	$vhost .= "-ssl"
    }

    push(@dir, $vhost);
 
    my $hostDir = join('/', @dir);
    $res{'docRoot'} = $hostDir . '/' . $docRoot;
    $res{'logsDir'} = $hostDir . '/' . $logsDir;
    $res{'certDir'} = $hostDir . '/' . $certDir;
	$res{'hostDir'} = $hostDir;
    #todo dir validation
    @dir = split(/\//, $apacheConfigDir);
    push(@dir, $sitesAvailable);
    push(@dir, "$vhost.conf");
    $res{'apacheConfig'} = join('/', @dir);
 
    return %res;   
}
 
sub createVhost {
    my $vhost = shift;
    #first create the docRoot
    my %vhostInfo = returnVhostPaths($vhost);
 
    informOut("Creating docroot dir: $vhostInfo{'docRoot'}");
    mkpath($vhostInfo{'docRoot'});
	my $user = getlogin();
	my $uid  = getpwnam($user);
	my $gid  = getgrnam($user);
	chown $uid, $gid, $vhostInfo{'hostDir'};
	chown $uid, $gid, $vhostInfo{'docRoot'};
    informOut("Creating log dir: $vhostInfo{'logsDir'}");
    mkpath($vhostInfo{'logsDir'});
	my $sslConfig = "";

	if ($ssl)
	{
	  mkpath($vhostInfo{'certDir'});
	  $vhostPort = 443;
	  $sslConfig = << "EOF"

    SSLEngine on
    SSLCertificateFile $vhostInfo{'certDir'}/site.crt
    SSLCertificateKeyFile $vhostInfo{'certDir'}/site.key
EOF
	}
 
    informOut("Site File: $vhostInfo{'apacheConfig'}");
 
    my $vhostContent = << "EOF";
# vim:syntax=apache filetype=apache expandtab ts=4 sw=4

<VirtualHost *:$vhostPort>
    ServerName $vhost
    DocumentRoot $vhostInfo{'docRoot'}
    <directory $vhostInfo{'docRoot'}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
  		<IfModule mod_authz_core.c>
    		# Apache 2.4
    		Require all granted
  		</IfModule>
  		<IfModule !mod_authz_core.c>
    		# Apache 2.2
        	Order allow,deny
        	Allow from all
  		</IfModule>
    </directory>
    ErrorLog "|/usr/bin/rotatelogs -f $vhostInfo{'logsDir'}/error-%Y-%m-%d.log 86400"
	CustomLog "|/usr/bin/rotatelogs -f $vhostInfo{'logsDir'}/access-%Y-%m-%d.log 86400" combined
    # LogLevel debug

$sslConfig
</VirtualHost> 
 
EOF
    informOut("Creating Vhost... [$vhostInfo{'apacheConfig'}]");
    open FILE, ">", $vhostInfo{'apacheConfig'} or die $!;
    print FILE $vhostContent;
    close FILE;
 
    informOut("Adding host $vhost");
    open FILE, ">>", '/etc/hosts' or die $!;
    print FILE $ipAddress ."\t". $vhost ."\n";
    close FILE;
 
#TODO    my $output = `/usr/sbin/a2ensite $vhost`;
#TODO    print $output;
 
    restartApache();
    #print $vhostConten t;
}
 
sub restartApache
{
    informOut("TODO : Restarting apache");
#TODO    my $output = `/etc/init.d/apache2 restart`;
#TODO    print $output; 
}
 
sub deleteVhost
{
    my $vhost = shift;
     my %vhostInfo = returnVhostPaths($vhost);
 
    informOut("Removing $vhost from hosts file");
    open IN, '< ', '/etc/hosts' or die $!;
    my @hostsFile = <IN>;
    close IN;
 
    my @contents = grep(!/^127.0.0.1\t$vhost/, @hostsFile);
 
    open FILE, ">", '/etc/hosts' or die $!;
    print FILE @contents;
    close FILE;
 
    my $output = `/usr/sbin/a2dissite $vhost`;
    print $output;
 
    informOut("Removing  $vhostInfo{'apacheConfig'} file");
    unlink($vhostInfo{'apacheConfig'});
 
    restartApache();
 
    print " manually remove $vhostInfo{'docRoot'}... \n";
 
}
 
sub informOut {
    my $message = shift;
    print "$message \n";
}


