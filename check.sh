#!/bin/sh

local_ips=""

# Email info variables (filled in dynamically)
send_mail_function=0

# Checks timeout in minutes, sleep time in minutes
checks_timeout_minutes=1

function set_up {
	echo "===== LAN CHECKER SET UP ====="
	echo "Want to get email notifications? (y/n)"
	read answer
	if [ "$answer" == "y" ]; then
		echo "Enter mail address:"
		read mail_address
		echo "Enter mail password:"
		read -s mail_password
		echo "What is you name?"
		read sender_name
		echo "Ok $sender_name! I will need some final info about the receiver also!"
		echo "Enter receiver address:"
		read receiver_mail
		echo "What is the name of the receiver?"
		read receiver_name
		echo "Thank you for your patience! The checking with notifications will begin now!"

		send_mail_function=1
	fi

	network_info=$(ifconfig | grep "inet " |awk '{ if ( $2 != "127.0.0.1" ) { printf $2; printf " "; print $4} }')

	if [ ! -f "ipv4_locals" ]; then

		echo "Compiling the C source code module.."
		if ! make; then
			echo "Sorry, you need to compile the file ipv4_locals.c file on your own!"
			exit -1
		fi

	fi
	local_ips=$(./ipv4_locals $network_info) # A string containing ips of the local network
}

function send_mail {
	
	RECEIVER_NAME=$1
	RECEIVER_MAIL=$2
	SUBJECT_LINE=$3
	PASSWORD=$4
	FILE_NAME=$5
	NICE_NAME=$6
	SENDER_MAIL=$7

	cd etc/mail

	if [ "$#" -ne 7 ]; then
		echo "usage: receiver_name receiver_mail subject password filename nicename sendermail"
		exit 0
	fi

	echo "From: '$NICE_NAME' <$SENDER_MAIL>
	To: '$RECEIVER_NAME' <$RECEIVER_MAIL>
	Subject: $SUBJECT_LINE
	" > mailheaders_$RECEIVER_MAIL.txt

	cat mailheaders_$RECEIVER_MAIL.txt $FILE_NAME > fil.txt

	# Sending the mail using curl
	curl --url 'smtps://smtp.gmail.com:465' --ssl-reqd --mail-from "$RECEIVER_MAIL" --mail-rcpt "$RECEIVER_MAIL" --upload-file fil.txt --user "$SENDER_MAIL:$PASSWORD" --insecure > /dev/null &

	rm mailheaders_$RECEIVER_MAIL.txt

}


function perform_pinging {
	echo "Pinging everyone..."
	# The shell will spawn ping processes, these need no the exceed a certain
	# ammount or else the memory will not be sufficient
	launch_count_limit=20

	# Pinging and killing with messages to stderr temporarily removed

	exec 3>&2          # 3 is now a copy of 2
	exec 2> /dev/null  # 2 now points to /dev/null

	launch_count=0
	while read -r ipv4_address; do
		(ping "$ipv4_address" &>/dev/null) &
		launch_count=$((launch_count+1))
		if [ $launch_count -eq $launch_count_limit ]; then
			sleep 4
			# Pinging for 4 seconds, then ending those processes 
			killall ping &>/dev/null
			launch_count=0
		fi
	done <<< "$local_ips"

	sleep 10
	killall ping &>/dev/null

	sleep 1
	exec 2>&3          # restore stderr to saved
	exec 3>&-          # close saved version

	echo "done pinging"
}

function perform_check {
	connected_file="connected_locally.txt"
	info_file="arp_info.txt"

	# Call arp to see what devices are connected in the LAN
	connected=$(arp -a)

	last_time_connected=""

	if [ -f $connected_file ]; then
		last_time_connected=$(cat $connected_file)
		rm $connected_file
	fi

	# Conencted devices have a name that is not: "?"
	while read -r line; do
		echo "$line" |awk '{ if ($1 != "?"){printf $1;printf " "; printf $2; printf " "; printf $4; printf "\n"} }' >> $connected_file
	done <<<"$connected"

	# Print connected devices
	echo "======= CONNECTED TO THE NETWORK: ======="
	cat $connected_file

	this_time_connected=$(cat $connected_file)

	if [ -f $info_file ]; then
		rm $info_file
	fi

	# Comparing the old and the new arp-entries to see if anything has happened
	info_written=0
	while read line; do

		if ! echo "$this_time_connected" |grep "$line" >/dev/null; then
			echo "- old entry no longer in arp: $line" >>$info_file
			info_written=1
		fi

	done <<< "$last_time_connected"

	while read line; do
	 
		if ! echo "$last_time_connected" |grep "$line" >/dev/null; then
			echo "- new entry in arp: $line" >> $info_file
			info_written=1
		fi

	done <<< "$this_time_connected"

	if [ $info_written -eq 0 ]; then
		echo "No change detected."
	fi

	if [ -f $info_file ]; then
		# Something on the LAN has changed..
		cat $info_file

		if [ ! $send_mail_function -eq 0 ]; then
			send_mail "$receiver_name" "$receiver_mail" "Network Change" "$mail_password" "$info_file" "$sender_name" "$mail_address"
			if [ $? -neq 0 ]; then
				echo "failed to send mail.."
			fi
		fi 
	fi


}

set_up

while [ 1 ]; do

	perform_pinging 
	perform_check

	sleep $((checks_timeout_minutes*60))

done


