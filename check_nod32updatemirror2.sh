#!/bin/sh
#Originale pubblicato su NagiosExchange da TV
#Modificato by NicolaBandini
#Version 1.0

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#If you need to exit with a proxy change this line and remove comments at this line and at line 63
#HTTPPROXY="proxyip:proxyport"

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1.1 $' | sed -e 's/[^0-9.]//g'`
UPDATEVERFILE="/tmp/nod32updatever.$$"

#Check parameters from Nagios definition
NOD32HOST=$1
NOD32PORT=$2

#Check critial difference from web nod definition and server ones
MINDEF=3

#TODO
#Implement the  [-d] parameters

. $PROGPATH/utils.sh

print_usage() {
        echo "Usage: $PROGNAME HOST PORT [-v][-d int]"
        echo "Parameter order must be identical!"
}

print_help() {
        print_revision $PROGNAME $REVISION
        echo ""
        print_usage
        echo ""
        echo "This plugin checks wether NOD32 Update Mirror is up to date or not."
        echo ""
        support
        exit 0
}

case "$1" in
        --help)
                print_help
                exit 0
                ;;
        -h)
                print_help
                exit 0
                ;;
        --version)
                print_revision $PROGNAME $REVISION
                exit 0
                ;;
        -V)
                print_revision $PROGNAME $REVISION
                exit 0
                ;;
        *)
 
                cd /tmp

                # obtain nod32 version from virusrarad web site
                #export http_proxy=$HTTPPROXY
                wget -q --timeout=7 http://www.virusradar.com/en/update/info -O nod32.log
                export WEBDATE=`date +%b-%d-%Y`
                export NODWEBDEF=`cat nod32.log | grep $WEBDATE -B 2 | grep "/en/update/info" | head -n 1 | awk -F ">" '{ print $2 }' | awk -F "<" '{ print $1 }'` 
                WEBOK=$?

                # Grab NOD32 update version (MIRROR)
                wget -q --timeout=7 http://$NOD32HOST:$NOD32PORT/update.ver -O $UPDATEVERFILE
                WGETSTATUS=$?

                # Figure out if we have any alarms
                export CURRENTDATE=`date +%Y%m%d`
                export ALARMVAL=`cat $UPDATEVERFILE | grep -c "$CURRENTDATE"`

                UPDATESTATUS=`cat $UPDATEVERFILE | grep "\[ENGINE2" -A 2 | grep version`

                UPDATESTATUS2=`cat $UPDATEVERFILE | grep "\[ENGINE2" -A 2 | grep version | awk -F = '{ print $2 }'`
                UPDATESTATUS2=$(echo $UPDATESTATUS2|tr -d '\r')

                # No more data needed, remove our temporary files
                rm $UPDATEVERFILE
                rm nod32.log

                if test "$3" = "-v" -o "$3" = "--verbose"; then
                        echo "SERVER NOD VERSIONID ${UPDATESTATUS2}"
                        echo "MATCH DATE INTO SERVER FILE ${ALARMVAL}"
                        echo "WEB NOD VERSIONID ${NODWEBDEF}"
                fi
                
                if test ${WGETSTATUS} -eq 1; then
                        echo "Unable to get status from http://${NOD32HOST}:${NOD32PORT}/ - check Host and Port settings in $0?"
                        exit -1
                fi

                #Check with web definition
                if [ $WEBOK -eq 0 ]; then
                        let DIFFNOD=NODWEBDEF-UPDATESTATUS2
                        #The server have the same version of web nod32
                        if [ $DIFFNOD -eq 0  ]; then
                                echo "OK: NOD32 UPDATE - LATEST VERSION $UPDATESTATUS2"
                                exit 0
                        fi
                        if [ $DIFFNOD -lt $MINDEF ]; then
                                echo "OK: NOD32 UPDATE - VERSION $UPDATESTATUS2"
                                exit 0
                        fi
                        if [ $DIFFNOD -gt $MINDEF ]; then
                                echo "CRITIAL: NOD32 UPDATE - Installed $UPDATESTATUS2 latest on Web $NODWEBDEF"
                                exit 2
                        fi
                fi

                #there is current data into server update.ver 
                if test ${ALARMVAL} -eq 0; then
                        echo "CRITICAL: NOD32 UPDATE VERSION - $UPDATESTATUS2"
                        exit 2
                else
                        echo "OK: NOD32 UPDATE VERSION - $UPDATESTATUS2"
                        exit 0
                fi
                ;;
esac
