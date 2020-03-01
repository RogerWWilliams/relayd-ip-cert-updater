# relayd-ip-cert-updater

relayd-ip-cert-updater.pl is a Perl script to automatically update the
configuration for relayd on systems that run DHCP on their gateway,
probably due to a cable modem connection or similar to their provider.
This script works to keep the SSL cert in the proper path as expected
by relayd.

[relayd](https://man.openbsd.org/relayd.8) is a daemon available on
OpenBSD that supports relaying and dynamically redirecting incoming
traffic to a target host system.

## Prequisites
Some of the Perl5 libraries used by this scirpt are not installed by
default and will require installation before the script will execute.
Confirm that the below libraries are installed and available

1.  Sys::Syslog
2.  Try::Tiny
3.  IO:Interface
4.  Net::IP

## Installation
1.  Create a file /etc/relayd.conf.local with a single line entry:
    `relayd_addr=<CURRENT_GATEWAY_IP>` 
    
    a) The IP address is that of your current gateway that will be
    receiving requests into relayd.  It will be the DHCP interface
    
    b) Set the perms and ownership on the file so that only root can
    read it
    
2.  Make a small edit in /etc/relayd.conf to have to include the the
    relayd.conf.local file when it loads its configuration.  The below
    should be the first line of the configuration file.
    `include /etc/relayd.conf.local`
    
3.  Set the $SSL_CERT_NAME to your TLD as SSL Cert providers will
    normally create a cert using <TLD>.crt. Set the my $DHCP_IF to the
    if name that will be used as the gateway.  If the private
    key/cert/and full chain cert names differ, also feel free to
    change those as necessary.  This was created using Let's Encrypt
    so those are their standard naming conventions.  The
    $USE_FULL_CHAIN value will point relayd to using the entire chain
    rather than the machine cert.  This is required for an A rating on
    Qualys so that is why it is the default.

4.  Copy the perl script into a location that is accessible only by
    root user.
    
    a) This script executes a restart on the relayd service so it must
    be ran as root

5.  Set up a cron job to execute the script at some periodic time.
    Depending upon how frequently your IP address may change, adjust
    the recurrence of the execution.  Once an hour should be
    sufficient in most home network instances. Perform this as root.

    ```
    crontab -e
    0  *  *  *  * /path/to/relayd_ip_cert_updater.pl
    ```

6.  This system will log to local2 log interface.  By default OpenBSD
    does not log anything below "NOTICE" level.  Since this script uses
    INFO and DEBUG as well as ERROR, if INFO or DEBUG level items are
    desired, add a line like the below to /etc/syslog.conf to have them
    logged into /var/log/messages. Be sure to restart the the syslog
    daemon so they can take effect.

    ```
    local2.info                 /var/log/messages
    ```

## Usage
There is nothing required beyond the configuration noted and executing
via cron.

## Contributing
Pull requests are welcome. For major changes, please open an issue
first to discuss what you would like to change.  Please make sure to
test as appropriate.

## License
[ISC](https://opensource.org/licenses/ISC)

## Contact
roger@wilcis.com

## Acknowledgements
### Larry Wall - It can be cryptic at times but is still a great language
### Theo de Raadt - For the inspiration to always code correctly
### Godzilla - For all the great late night movies when I could not sleep
