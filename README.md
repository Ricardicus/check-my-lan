# check-my-lan
A script for my raspberry PI that lets me know who is using my WiFi.

It uses ping and arp to see if new devices pop up after a series of pings 
have been carried out. Super simple. 

# email notifications
If you want it can send you the changes in the arp using cURL. 
Make sure that your email server accepts these --insecure mails in that case!
<pre>
curl --url 'smtps://smtp.gmail.com:465' --ssl-reqd --mail-from "$RECEIVER_MAIL" --mail-rcpt "$RECEIVER_MAIL" --upload-file file.txt --user "$SENDER_MAIL:$PASSWORD" --insecure 
  </pre>
