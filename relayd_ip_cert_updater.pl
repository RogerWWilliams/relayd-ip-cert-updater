#!/usr/bin/perl
#
# Copyright (c) 2020 Roger W. Williams <roger@wilcis.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;

use Sys::Syslog qw(:DEFAULT :standard :macros);
use Try::Tiny;
use IO::Interface::Simple;
use Net::IP;

# CONSTANTS - Modify as necessary
my $RCCTL = "/usr/sbin/rcctl";
my $RELAYD_CONF = "/etc/relayd.conf.local";
my $SSL_CERT_NAME = "<CERT/DOMAIN ZONE NAME>";
my $PUB_SYMLINK_DIR = "/etc/ssl/";
my $PRIV_SYMLINK_DIR = "/etc/ssl/private/";
my $LOGGER = "local2";
my $DHCP_IF = "<DHCP INTERFACE NAME>";  # Interface for DHCP
my $KEY_EXT = ".key";
my $CRT_EXT = ".crt";
my $CHAIN_EXT = ".fullchain.pem";
my $USE_FULL_CHAIN = 1;  # Use full chain cert (1) or host cert (0)

# ================== No changes below this line ======================

# Initialize some variables
my $cert;
my $ip_cert;
my $old_cert;
my $priv_key;
my $old_priv_key;

# Logging handled
sub wlog {
    my $level = $_[0];
    my $entry = $_[1];
    my $logger = $_[2];
    try {
        openlog("", 'ndelay', $logger);
        syslog($level, $entry);
    } finally {
	    closelog();
    };
}

# Parse the local configuration file and return the IP it contains
sub obtain_cur_ip {
    my $sub_name = (caller(0))[3];
    my $ip_cur = "";
    wlog(LOG_DEBUG, "DEBUG Entering function $sub_name", $LOGGER);
    open (FH, '<', $RELAYD_CONF) or die \
        wlog(LOG_ERR, "ERROR reading file $RELAYD_CONF", $LOGGER);
    while (<FH>) {
        if (/^relayd_addr=/i) {
            my $line = $_;
            my %hash = map { split(/=/, $_, 2) } $line;
            $ip_cur = $hash{relayd_addr};
            wlog(LOG_INFO, "INFO IP $ip_cur found in $RELAYD_CONF", $LOGGER);
        }
        else {
            wlog(LOG_ERR, "ERROR Search relayd_addr fail RELAYD_CONF",
                 $LOGGER);
            exit 1;
        }
    }
    close(FH);
    # Convert the line contents to an IP address object
    my $ip_obj = new Net::IP ($ip_cur) || die \
                 wlog(LOG_ERR, "ERR converting IP $ip_cur", $LOGGER);
    wlog(LOG_DEBUG, "DEBUG Leaving function $sub_name", $LOGGER);
    return $ip_obj->ip();
}

# Get the latest set IP the OS knows about
sub obtain_if_ip {
    my $sub_name = (caller(0))[3];
    wlog(LOG_DEBUG, "DEBUG Entering function $sub_name", $LOGGER);
    my $if = IO::Interface::Simple->new($DHCP_IF);
    my $if_ip = $if->address;
    wlog(LOG_INFO, "Interface $DHCP_IF IP $if_ip detected on NIC",
        $LOGGER);
    wlog(LOG_DEBUG, "DEBUG Leaving function $sub_name", $LOGGER);
    return $if_ip;
}

# Update the relayd local config file
sub update_relayd_conf {
    my $sub_name = (caller(0))[3];
    wlog(LOG_DEBUG, "DEBUG Entering function $sub_name", $LOGGER);
    my $new_ip = $_[0];
    open (FH, '>', $RELAYD_CONF) or die \
        wlog(LOG_ERR, "ERROR opening file $RELAYD_CONF for writing", $LOGGER);
    print FH "relayd_addr=$new_ip";
    close(FH);
    wlog(LOG_INFO, "INFO Successfully updated $RELAYD_CONF with IP $new_ip",
        $LOGGER);
    wlog(LOG_DEBUG, "DEBUG Leaving function $sub_name", $LOGGER);
}

# Create certificate names
sub construct_cert_names {
    my $sub_name = (caller(0))[3];
    wlog(LOG_DEBUG, "DEBUG Entering function $sub_name", $LOGGER);
    my $ip_cur = $_[0];
    my $if_ip = $_[1];
    # Create the file names by appending ".key, .crt, .fullchain.pem" to IP
    $priv_key = "$if_ip"."$KEY_EXT";
    $old_priv_key = "$ip_cur"."$KEY_EXT";
    $old_cert = "$ip_cur"."$CRT_EXT";
    $ip_cert = "$if_ip"."$CRT_EXT";

    if ($USE_FULL_CHAIN ne '' && $USE_FULL_CHAIN == 1) {
      # Using full chain we will point the <IP>.crt to new <IP>.fullchain.pem
      $cert = "$SSL_CERT_NAME"."$CHAIN_EXT";
    } else {
      # Using machine cert we will point the <IP>.crt to new <IP>.crt
      $cert = "$SSL_CERT_NAME"."$CRT_EXT";
    }

    wlog(LOG_DEBUG, "DEBUG Leaving function $sub_name", $LOGGER);
}

# Create new SSL Symlinks
sub create_new_symlinks {
    my $sub_name = (caller(0))[3];
    wlog(LOG_DEBUG, "DEBUG Entering function $sub_name", $LOGGER);
    if (defined $cert) {
        symlink ("$PUB_SYMLINK_DIR"."$cert",
                 "$PUB_SYMLINK_DIR"."$ip_cert") || die \
                   wlog(LOG_ERR, "ERROR creating symlink public", $LOGGER);
    }
    if (defined $priv_key) {
        symlink ("$PRIV_SYMLINK_DIR"."$SSL_CERT_NAME" . ".key",
                 "$PRIV_SYMLINK_DIR"."$priv_key") || die \
                   wlog(LOG_ERR, "ERROR creating symlink private", $LOGGER);
    }
    wlog(LOG_DEBUG, "DEBUG Leaving function $sub_name", $LOGGER);
}

# Delete old SSL Symlinks
sub delete_old_symlinks {
    my $sub_name = (caller(0))[3];
    wlog(LOG_DEBUG, "DEBUG Entering function $sub_name", $LOGGER);
    if (defined $old_cert) {
        # delete the old symlink to the existing file iname if it exists
        if ( -l "$PUB_SYMLINK_DIR"."$old_cert") {
            unlink("$PUB_SYMLINK_DIR"."$old_cert") || die \
              wlog(LOG_ERR, "ERROR deleting symlink public", $LOGGER);
        }
    }
    if (defined $old_priv_key) {
        if ( -l "$PRIV_SYMLINK_DIR"."$old_priv_key") {
            unlink("$PRIV_SYMLINK_DIR"."$old_priv_key") || die \
              wlog(LOG_ERR, "ERROR deleting symlink public", $LOGGER);
        }
    }
    wlog(LOG_DEBUG, "DEBUG Leaving function $sub_name", $LOGGER);
}

# Restart relayd service
sub restart_relayd {
    my $sub_name = (caller(0))[3];
    wlog(LOG_DEBUG, "DEBUG Entering function $sub_name", $LOGGER);
    my $stop_relayd = "$RCCTL stop relayd";
    my $start_relayd = "$RCCTL start relayd";
    try {
        system($stop_relayd);
        system($start_relayd);
    } catch {
        wlog(LOG_ERR, "ERROR when restarting relayd service", $LOGGER);
        exit 1;
    };

    wlog(LOG_INFO, "INFO Successfully restarted relayd service", $LOGGER);
    wlog(LOG_DEBUG, "DEBUG Leaving function $sub_name", $LOGGER);
}

# =====================   MAIN BELOW HERE   ===========================


my $ip_cur = obtain_cur_ip();
my $if_ip = obtain_if_ip();

# When IP change detected we need to update our cert symlinks for relayd
if ( $ip_cur ne $if_ip ) {
    wlog(LOG_INFO, "INFO IP addresses vary, updating $RELAYD_CONF", $LOGGER);
    # Update hash maps as needed
    construct_cert_names($ip_cur, $if_ip);
    update_relayd_conf($if_ip);
    delete_old_symlinks();
    create_new_symlinks();
    restart_relayd();
} else {
    wlog(LOG_INFO, "INFO No changes in IP.. exiting", $LOGGER);
}

exit 0;
